using System.Security.Principal;
using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace MaterialSystemCare.Engine;

public interface IEngineModule
{
    bool CanHandle(string method);
    Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken);
}

public sealed class EngineException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
}

public sealed class EngineContext
{
    public string DataRoot { get; }
    public bool IsElevated { get; }
    public bool IsFixture { get; }
    private readonly string connectionString;
    public EngineContext(string? dataRoot = null)
    {
        IsFixture = dataRoot != null;
        DataRoot = Path.GetFullPath(dataRoot ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MaterialSystemCare"));
        Directory.CreateDirectory(DataRoot);
        using var identity = WindowsIdentity.GetCurrent();
        IsElevated = !IsFixture && new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
        connectionString = new SqliteConnectionStringBuilder { DataSource = Path.Combine(DataRoot, "records.db"), Mode = SqliteOpenMode.ReadWriteCreate }.ToString();
        using var db = Open();
        using var migration = db.CreateCommand();
        migration.CommandText = "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL); CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, occurred_at TEXT NOT NULL, operation TEXT NOT NULL, details TEXT NOT NULL); PRAGMA user_version=1;";
        migration.ExecuteNonQuery();
    }
    private SqliteConnection Open() { var db = new SqliteConnection(connectionString); db.Open(); using var command = db.CreateCommand(); command.CommandText = "PRAGMA busy_timeout=5000; PRAGMA synchronous=FULL;"; command.ExecuteNonQuery(); return db; }
    private static bool Sensitive(string key) => new[] { "password", "secret", "token", "credential", "vocabulary", "private" }.Any(x => key.Contains(x, StringComparison.OrdinalIgnoreCase));
    public async Task RecordAsync(string operation, object details, CancellationToken ct)
    {
        if (Sensitive(operation)) return;
        var json = JsonSerializer.SerializeToElement(details, Program.JsonOptions);
        // Retain operation receipts while removing sensitive values recursively.
        object? Redact(JsonElement value) => value.ValueKind switch {
            JsonValueKind.Object => value.EnumerateObject().Where(p => !Sensitive(p.Name)).ToDictionary(p => p.Name, p => Redact(p.Value)),
            JsonValueKind.Array => value.EnumerateArray().Select(Redact).ToArray(),
            _ => value.Clone()
        };
        using var db = Open(); using var command = db.CreateCommand();
        command.CommandText = "INSERT INTO history(occurred_at,operation,details) VALUES($at,$op,$details)";
        command.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O")); command.Parameters.AddWithValue("$op", operation); command.Parameters.AddWithValue("$details", JsonSerializer.Serialize(Redact(json), Program.JsonOptions));
        await command.ExecuteNonQueryAsync(ct);
    }
    public async Task<object?> ReadSettingAsync(string key, CancellationToken ct)
    {
        using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "SELECT value FROM settings WHERE key=$key"; command.Parameters.AddWithValue("$key", key);
        var value = await command.ExecuteScalarAsync(ct) as string; return value == null ? null : JsonSerializer.Deserialize<JsonElement>(value);
    }
    public async Task SaveSettingAsync(string key, object? value, CancellationToken ct)
    {
        if (key.Length is < 1 or > 128 || Sensitive(key)) throw new EngineException("INVALID_SETTING", "This setting key is not supported by general settings storage.");
        var json = JsonSerializer.Serialize(value, Program.JsonOptions);
        if (json.Length > 262144) throw new EngineException("INVALID_SETTING", "The setting exceeds the storage limit.");
        using var document = JsonDocument.Parse(json);
        bool ContainsSensitive(JsonElement element) => element.ValueKind switch {
            JsonValueKind.Object => element.EnumerateObject().Any(p => Sensitive(p.Name) || ContainsSensitive(p.Value)),
            JsonValueKind.Array => element.EnumerateArray().Any(ContainsSensitive),
            _ => false
        };
        if (ContainsSensitive(document.RootElement)) throw new EngineException("INVALID_SETTING", "Sensitive data requires dedicated protected storage.");
        using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "INSERT INTO settings(key,value) VALUES($key,$value) ON CONFLICT(key) DO UPDATE SET value=excluded.value"; command.Parameters.AddWithValue("$key", key); command.Parameters.AddWithValue("$value", json); await command.ExecuteNonQueryAsync(ct);
        await RecordAsync("settings.save", new { key }, ct);
    }
    public async Task<object> ReadSettingsAsync(CancellationToken ct)
    {
        using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "SELECT key,value FROM settings ORDER BY key";
        using var reader = await command.ExecuteReaderAsync(ct); var settings = new Dictionary<string, JsonElement>();
        while (await reader.ReadAsync(ct)) settings[reader.GetString(0)] = JsonSerializer.Deserialize<JsonElement>(reader.GetString(1)); return settings;
    }
    public async Task<object> ReadHistoryAsync(int limit, CancellationToken ct)
    {
        using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "SELECT id,occurred_at,operation,details FROM history ORDER BY id DESC LIMIT $limit"; command.Parameters.AddWithValue("$limit", limit);
        using var reader = await command.ExecuteReaderAsync(ct); var rows = new List<object>();
        while (await reader.ReadAsync(ct)) rows.Add(new { id = reader.GetInt64(0), occurredAt = reader.GetString(1), operation = reader.GetString(2), details = JsonSerializer.Deserialize<JsonElement>(reader.GetString(3)) }); return rows;
    }
}
