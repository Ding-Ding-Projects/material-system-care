using System.Text.Json;
using System.Text.Json.Nodes;
using MaterialSystemCare.Engine;

string sandbox = Path.Combine(Path.GetTempPath(), "MaterialSystemCare-storage-fixture-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(sandbox);
int passed = 0;
try
{
    string launchRoot = Path.Combine(Path.GetTempPath(), "MaterialSystemCare-cleanup-fixtures", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(Path.Combine(launchRoot, "temp"));
    Directory.CreateDirectory(Path.Combine(launchRoot, "records"));
    try {
        File.WriteAllText(Path.Combine(launchRoot, CleanupFixture.MarkerName), CleanupFixture.Marker);
        using (var launch = new CleanupFixture(launchRoot)) {
            var isolated = new EngineContext(launch.Records, launch);
            var launchModules = new IEngineModule[] { new SystemModule(), (StorageModule)Activator.CreateInstance(typeof(StorageModule), System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic, null, [launch.Temp], null)! };
            string request(string method) => JsonSerializer.Serialize(new { version = 1, id = "fixture", method, @params = new { } });
            var denied = JsonDocument.Parse(await MaterialSystemCare.Engine.Program.DispatchAsync(request("system.snapshot"), isolated, launchModules, CancellationToken.None));
            if (denied.RootElement.GetProperty("error").GetProperty("code").GetString() != "FIXTURE_METHOD_DENIED") throw new Exception("Fixture allowed host collection");
            var ping = JsonDocument.Parse(await MaterialSystemCare.Engine.Program.DispatchAsync(request("engine.ping"), isolated, launchModules, CancellationToken.None));
            if (!ping.RootElement.GetProperty("result").GetProperty("cleanupFixture").GetBoolean()) throw new Exception("Fixture identity missing");
            try { Directory.Move(launch.Temp, launch.Temp + "-moved"); throw new Exception("Fixture directory was replaceable"); } catch (IOException) { }
            try { File.WriteAllText(Path.Combine(launchRoot, CleanupFixture.MarkerName), "changed"); throw new Exception("Fixture marker was replaceable"); } catch (IOException) { }
            launch.Validate();
            Console.WriteLine("PASS fixture scope, restricted dispatch, identity and replacement locks");
        }
        File.WriteAllText(Path.Combine(launchRoot, CleanupFixture.MarkerName), "invalid");
        try { using var invalid = new CleanupFixture(launchRoot); throw new Exception("Invalid marker accepted"); } catch (EngineException e) when (e.Code == "INVALID_FIXTURE") { }
        try { using var invalid = new CleanupFixture(sandbox); throw new Exception("Outside scope accepted"); } catch (EngineException e) when (e.Code == "INVALID_FIXTURE") { }
        Console.WriteLine("PASS invalid fixture marker and parent rejected");
    } finally {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        Directory.Delete(launchRoot, true);
    }
    string selected = Path.Combine(sandbox, "selected"), temp = Path.Combine(sandbox, "temp"), data = Path.Combine(sandbox, "data");
    Directory.CreateDirectory(selected); Directory.CreateDirectory(temp); Directory.CreateDirectory(data);
    Directory.CreateDirectory(Path.Combine(selected, "empty"));
    await File.WriteAllTextAsync(Path.Combine(selected, "a.txt"), "same bytes");
    await File.WriteAllTextAsync(Path.Combine(selected, "b.txt"), "same bytes");
    await File.WriteAllTextAsync(Path.Combine(selected, "c.txt"), "other data");
    var context = new EngineContext(data);
    var module = (StorageModule)Activator.CreateInstance(typeof(StorageModule), System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic, null, [temp], null)!;
    async Task<JsonElement> Call(string method, object parameters) => JsonSerializer.SerializeToElement(await module.HandleAsync(method, JsonSerializer.SerializeToElement(parameters), context, CancellationToken.None), MaterialSystemCare.Engine.Program.JsonOptions);
    void Check(bool result, string name) { if (!result) throw new Exception(name); Console.WriteLine("PASS " + name); passed++; }
    async Task Reject(string method, object parameters, string code)
    {
        try { await Call(method, parameters); throw new Exception("Expected rejection: " + code); }
        catch (EngineException e) when (e.Code == code) { Check(true, code); }
    }
    var analyzed = await Call("storage.analyze", new { path = selected });
    Check(analyzed.GetProperty("fileCount").GetInt32() == 3 && analyzed.GetProperty("emptyFolderCount").GetInt32() == 1, "selected folder totals and empty directories");
    var duplicates = await Call("storage.duplicates", new { path = selected });
    Check(duplicates.GetProperty("groups").GetArrayLength() == 1, "exact bytes group only");
    var bounded = await Call("storage.analyze", new { path = selected, maxEntries = 1 });
    Check(bounded.GetProperty("truncated").GetBoolean(), "enumeration entry limit");
    await Reject("storage.analyze", new { path = selected, maxEntries = 0 }, "INVALID_ARGUMENT");
    await Reject("storage.analyze", new { path = selected, maxEntries = "unbounded" }, "INVALID_ARGUMENT");
    await Reject("cleanup.apply", new { planId = Guid.NewGuid().ToString("N") }, "CONFIRMATION_REQUIRED");
    await Reject("cleanup.scan", new { path = selected }, "SCOPE_NOT_ALLOWED");
    string old = Path.Combine(temp, "old.tmp"), changed = Path.Combine(temp, "changed.tmp"), recent = Path.Combine(temp, "recent.tmp");
    await File.WriteAllTextAsync(old, "recover this"); await File.WriteAllTextAsync(changed, "original"); await File.WriteAllTextAsync(recent, "recent");
    File.SetLastWriteTimeUtc(old, DateTime.UtcNow.AddDays(-10)); File.SetLastWriteTimeUtc(changed, DateTime.UtcNow.AddDays(-10));
    string unselected = Path.Combine(temp, "unselected.tmp");
    await File.WriteAllTextAsync(unselected, "leave this file alone");
    File.SetLastWriteTimeUtc(unselected, DateTime.UtcNow.AddDays(-10));
    var scanned = await Call("cleanup.scan", new { minimumAgeDays = 7 });
    Check(scanned.GetProperty("fixture").GetBoolean() && scanned.GetProperty("targets").GetArrayLength() == 3, "aged fixture files only");
    string planId = scanned.GetProperty("planId").GetString()!;
    var targetIndexes = scanned.GetProperty("targets").EnumerateArray().Select((target, index) => (target, index)).Where(pair => pair.target.GetProperty("path").GetString() != unselected).Select(pair => pair.index).ToArray();
    await Reject("cleanup.apply", new { planId, confirmed = true }, "SELECTION_REQUIRED");
    await Reject("cleanup.apply", new { planId, confirmed = true, targetIndexes = Array.Empty<int>() }, "SELECTION_REQUIRED");
    foreach (var invalid in new[] { new[] { -1 }, new[] { 3 }, new[] { 0, 0 } })
        await Reject("cleanup.apply", new { planId, confirmed = true, targetIndexes = invalid }, "INVALID_SELECTION");
    await Reject("cleanup.apply", new { planId, confirmed = true, targetIndexes = new[] { "0" } }, "INVALID_SELECTION");
    await Reject("cleanup.apply", new { planId, confirmed = true, targetIndexes = new[] { 0.5 } }, "INVALID_SELECTION");
    Check(File.Exists(old) && File.Exists(changed) && File.Exists(unselected) && !File.Exists(Path.Combine(data, "cleanup", planId + ".receipt.json")), "invalid selection creates no recovery receipt or moves");
    await File.WriteAllTextAsync(changed, "modified");
    var applied = await Call("cleanup.apply", new { planId, confirmed = true, targetIndexes });
    foreach (var item in applied.GetProperty("items").EnumerateArray()) Console.WriteLine("Fixture cleanup state: " + item.GetProperty("state").GetString() + "; reason: " + item.GetProperty("reason").ToString());
    Check(!File.Exists(old) && File.Exists(changed) && File.Exists(recent) && applied.GetProperty("partial").GetBoolean(), "changed target skipped and eligible target quarantined");
    Check(await File.ReadAllTextAsync(unselected) == "leave this file alone" && applied.GetProperty("plannedCount").GetInt32() == 2 && applied.GetProperty("totalPlanCount").GetInt32() == 3, "unselected eligible target remains untouched");
    var details = await Call("cleanup.details", new { receiptId = planId });
    Check(details.GetProperty("recordedOnly").GetBoolean() && !details.GetProperty("mutationPerformed").GetBoolean() && details.GetProperty("items").GetArrayLength() == 2 && !File.Exists(old), "recovery details read stored metadata without restoring");
    Check(details.GetProperty("items").EnumerateArray().All(item => !item.TryGetProperty("hash", out _) && !item.TryGetProperty("quarantinePath", out _)), "recovery review omits internal hashes and storage paths");
    await Reject("cleanup.details", new { receiptId = "../other" }, "INVALID_ARGUMENT");
    await Reject("cleanup.apply", new { planId, confirmed = true, targetIndexes = new[] { 0, 1, 2 } }, "SELECTION_CHANGED");
    Check(File.Exists(unselected), "replay cannot expand an applied selection");
    await File.WriteAllTextAsync(old, "new occupant");
    var conflict = await Call("cleanup.restore", new { receiptId = planId, confirmed = true });
    Check(conflict.GetProperty("partial").GetBoolean() && await File.ReadAllTextAsync(old) == "new occupant", "restore never overwrites occupant");
    File.Delete(old);
    var restored = await Call("cleanup.restore", new { receiptId = planId, confirmed = true });
    Check(await File.ReadAllTextAsync(old) == "recover this" && !restored.GetProperty("partial").GetBoolean(), "restore retained recovery data after conflict");
    await Call("cleanup.apply", new { planId, confirmed = true, targetIndexes });
    Check(File.Exists(old), "replaying an applied plan does not move files again");
    await Call("cleanup.apply", new { planId, confirmed = true, targetIndexes = targetIndexes.Reverse().ToArray() });
    Check(File.Exists(old) && File.Exists(unselected), "selection order does not change replay identity");
    var history = await Call("cleanup.history", new { });
    Check(history.GetProperty("receipts").GetArrayLength() == 1, "persisted recovery history");
    // Reproduce a successful native restore followed by interruption before its
    // restored journal update: original identity remains, quarantine is absent.
    string receiptPath = Path.Combine(data, "cleanup", planId + ".receipt.json");
    JsonNode crashReceipt = JsonNode.Parse(await File.ReadAllTextAsync(receiptPath))!;
    JsonNode restoredItem = crashReceipt["items"]!.AsArray().Single(x => x!["target"]!["path"]!.GetValue<string>() == old)!;
    restoredItem["state"] = "restoring";
    restoredItem["reason"] = null;
    await File.WriteAllTextAsync(receiptPath, crashReceipt.ToJsonString());
    var reconciled = await Call("cleanup.restore", new { receiptId = planId, confirmed = true });
    JsonElement reconciledItem = reconciled.GetProperty("items").EnumerateArray().Single(x => x.GetProperty("target").GetProperty("path").GetString() == old);
    Check(!reconciled.GetProperty("partial").GetBoolean() && reconciledItem.GetProperty("state").GetString() == "restored" && reconciledItem.GetProperty("reason").GetString() == "INTERRUPTED_RESTORE_RECONCILED", "interrupted restore reconciles exact original identity and bytes");
    JsonNode persistedReconciled = JsonNode.Parse(await File.ReadAllTextAsync(receiptPath))!;
    Check(persistedReconciled["items"]!.AsArray().Single(x => x!["target"]!["path"]!.GetValue<string>() == old)!["state"]!.GetValue<string>() == "restored", "reconciled restore state persisted");
    await File.WriteAllTextAsync(old, "foreign data");
    File.SetLastWriteTimeUtc(old, new DateTime(restoredItem["target"]!["modifiedTicks"]!.GetValue<long>(), DateTimeKind.Utc));
    await File.WriteAllTextAsync(receiptPath, crashReceipt.ToJsonString());
    var changedContent = await Call("cleanup.restore", new { receiptId = planId, confirmed = true });
    JsonElement contentItem = changedContent.GetProperty("items").EnumerateArray().Single(x => x.GetProperty("target").GetProperty("path").GetString() == old);
    Check(contentItem.GetProperty("state").GetString() == "conflict" && contentItem.GetProperty("reason").GetString() == "TARGET_CHANGED" && await File.ReadAllTextAsync(old) == "foreign data", "interrupted restore rejects changed bytes with original identity size and timestamp");
    // A new same-content file at the original path must not impersonate the
    // restored file, even when size and timestamps are copied exactly.
    File.Move(old, Path.Combine(sandbox, "held-original.tmp"));
    await File.WriteAllTextAsync(old, "recover this");
    File.SetCreationTimeUtc(old, new DateTime(restoredItem["target"]!["createdTicks"]!.GetValue<long>(), DateTimeKind.Utc));
    File.SetLastWriteTimeUtc(old, new DateTime(restoredItem["target"]!["modifiedTicks"]!.GetValue<long>(), DateTimeKind.Utc));
    await File.WriteAllTextAsync(receiptPath, crashReceipt.ToJsonString());
    var differentOccupant = await Call("cleanup.restore", new { receiptId = planId, confirmed = true });
    JsonElement occupantItem = differentOccupant.GetProperty("items").EnumerateArray().Single(x => x.GetProperty("target").GetProperty("path").GetString() == old);
    Check(differentOccupant.GetProperty("partial").GetBoolean() && occupantItem.GetProperty("state").GetString() == "conflict" && occupantItem.GetProperty("reason").GetString() == "TARGET_CHANGED" && await File.ReadAllTextAsync(old) == "recover this", "interrupted restore rejects a different same-content occupant identity");
    string link = Path.Combine(selected, "link");
    try
    {
        Directory.CreateSymbolicLink(link, temp);
        var withLink = await Call("storage.analyze", new { path = selected });
        Check(withLink.GetProperty("reparseSkipped").GetInt32() == 1, "symlink traversal refused");
        await Reject("storage.analyze", new { path = link }, "REPARSE_NOT_ALLOWED");
        Directory.Delete(link);
    }
    catch (UnauthorizedAccessException) { Console.WriteLine("UNVERIFIED symbolic-link fixture requires developer mode or privilege"); }
    catch (IOException ex) when ((ex.HResult & 0xffff) == 1314) { Console.WriteLine("SKIP symbolic-link fixture: ERROR_PRIVILEGE_NOT_HELD (1314); host privilege unchanged"); }
    using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
    try { await module.HandleAsync("storage.analyze", JsonSerializer.SerializeToElement(new { path = selected }), context, cancelled.Token); throw new Exception("Cancellation was ignored"); }
    catch (OperationCanceledException) { Check(true, "cancelled scan"); }
    Console.WriteLine($"Storage fixture checks passed: {passed}");
}
finally
{
    Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
    // This randomly named directory is created and owned exclusively by this process.
    if (Path.GetFileName(sandbox).StartsWith("MaterialSystemCare-storage-fixture-", StringComparison.Ordinal)) Directory.Delete(sandbox, true);
}
