using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace MaterialSystemCare.Engine;

internal static class StorageSafeFile
{
    public static void ValidateAncestors(string path)
    {
        string? current = Path.GetFullPath(path);
        while (current != null)
        {
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new EngineException("REPARSE_NOT_ALLOWED", "Symbolic links and reparse points are not accepted.");
            current = Path.GetDirectoryName(current);
        }
    }
    public static FileStream OpenRead(string path) => Open(path, false);
    public static FileStream OpenForMove(string path)
    {
        if (!OperatingSystem.IsWindows()) throw new EngineException("PLATFORM_UNSUPPORTED", "Handle-bound recovery requires Windows.");
        return Open(path, true);
    }
    private static FileStream Open(string path, bool move)
    {
        ValidateAncestors(path);
        if (!OperatingSystem.IsWindows()) return new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 65536, FileOptions.Asynchronous);
        var handle = CreateFileW(path, 0x80000000u | (move ? 0x00010000u : 0u), 1, IntPtr.Zero, 3, 0x00200000, IntPtr.Zero);
        if (handle.IsInvalid) { handle.Dispose(); throw new IOException("Unable to lock the file.", new Win32Exception(Marshal.GetLastWin32Error())); }
        try
        {
            if (!GetFileInformationByHandle(handle, out var info) || (info.Attributes & 0x410) != 0)
                throw new EngineException("REPARSE_NOT_ALLOWED", "Only regular files are accepted.");
            var name = new StringBuilder(32768);
            uint count = GetFinalPathNameByHandleW(handle, name, (uint)name.Capacity, 0);
            if (count == 0 || count >= name.Capacity) throw new IOException("Unable to resolve the opened file.");
            string final = name.ToString();
            if (final.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) final = @"\\" + final[8..];
            else if (final.StartsWith(@"\\?\", StringComparison.Ordinal)) final = final[4..];
            if (!string.Equals(Path.GetFullPath(path), final, StringComparison.OrdinalIgnoreCase))
                throw new EngineException("TARGET_CHANGED", "The opened file does not match the selected path.");
            ValidateAncestors(path);
            return new FileStream(handle, FileAccess.Read, 65536, false);
        }
        catch { handle.Dispose(); throw; }
    }
    public static string Identity(FileStream stream)
    {
        if (!OperatingSystem.IsWindows()) return $"portable:{stream.Length}";
        if (!GetFileInformationByHandle(stream.SafeFileHandle, out var info)) throw new IOException("Unable to read file identity.");
        // Hard links share identity. Cleanup must never move a multiply linked file.
        if (info.Links != 1) throw new EngineException("HARDLINK_NOT_ALLOWED", "Files with multiple hard links are excluded.");
        return $"{info.Volume:X8}:{info.IndexHigh:X8}{info.IndexLow:X8}";
    }
    public static void Move(FileStream source, string destination)
    {
        string parent = Path.GetDirectoryName(Path.GetFullPath(destination))!;
        ValidateAncestors(parent);
        // A directory handle prevents its replacement between validation and rename.
        using var directory = CreateFileW(parent, 0x80, 3, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
        if (directory.IsInvalid) throw new IOException("Unable to lock recovery destination.");
        if (!GetFileInformationByHandle(directory, out var info) || (info.Attributes & 0x400) != 0) throw new EngineException("REPARSE_NOT_ALLOWED", "The destination is a reparse point.");
        var resolved = new StringBuilder(32768);
        uint resolvedLength = GetFinalPathNameByHandleW(directory, resolved, (uint)resolved.Capacity, 0);
        string resolvedParent = resolved.ToString();
        if (resolvedParent.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase)) resolvedParent = @"\\" + resolvedParent[8..];
        else if (resolvedParent.StartsWith(@"\\?\", StringComparison.Ordinal)) resolvedParent = resolvedParent[4..];
        if (resolvedLength == 0 || resolvedLength >= resolved.Capacity || !string.Equals(parent, resolvedParent, StringComparison.OrdinalIgnoreCase))
            throw new EngineException("TARGET_CHANGED", "The recovery destination changed.");
        byte[] filename = Encoding.Unicode.GetBytes(Path.GetFileName(destination));
        int rootOffset = IntPtr.Size == 8 ? 8 : 4;
        int lengthOffset = rootOffset + IntPtr.Size;
        int nameOffset = lengthOffset + 4;
        IntPtr buffer = Marshal.AllocHGlobal(nameOffset + filename.Length);
        try
        {
            for (int i = 0; i < nameOffset; i++) Marshal.WriteByte(buffer, i, 0);
            Marshal.WriteIntPtr(buffer, rootOffset, directory.DangerousGetHandle());
            Marshal.WriteInt32(buffer, lengthOffset, filename.Length);
            Marshal.Copy(filename, 0, buffer + nameOffset, filename.Length);
            if (!SetFileInformationByHandle(source.SafeFileHandle, 3, buffer, (uint)(nameOffset + filename.Length)))
                throw new IOException("The same-volume recovery move failed; the original file is retained.", new Win32Exception(Marshal.GetLastWin32Error()));
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct FileInformation
    {
        public uint Attributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME Created, Accessed, Written;
        public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string path, uint access, uint sharing, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInformation information);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandleW(SafeFileHandle handle, StringBuilder path, uint size, uint flags);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetFileInformationByHandle(SafeFileHandle handle, int informationClass, IntPtr information, uint size);
}
