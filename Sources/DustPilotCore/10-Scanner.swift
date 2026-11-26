import Foundation

public struct ScanOptions: Sendable {
    public var largeFileThreshold: Int64 = 250 * 1_024 * 1_024
    public var maxEntries = 100_000
    /// Files not modified for this many days (and at least `staleMinBytes`) are listed as "Old files". 0 disables.
    public var staleDays = 365
    public var staleMinBytes: Int64 = 50 * 1_024 * 1_024
    /// Identical files of at least this size are listed as "Duplicates". 0 disables.
    public var duplicateMinBytes: Int64 = 1_024 * 1_024
    public var now = Date()
    public init() {}
    public init(largeFileThreshold: Int64, maxEntries: Int, staleDays: Int = 0, staleMinBytes: Int64 = 0, duplicateMinBytes: Int64 = 0, now: Date = Date()) {
        self.largeFileThreshold = largeFileThreshold; self.maxEntries = maxEntries
        self.staleDays = staleDays; self.staleMinBytes = staleMinBytes; self.duplicateMinBytes = duplicateMinBytes; self.now = now
    }
}

public enum FolderScanner {
    static let cacheNames: Set<String> = ["caches", "cache", "code cache", "gpucache", "deriveddata"]
    static let tempExtensions: Set<String> = ["tmp", "temp", "bak", "old", "swp"]

    /// Walks `folder` and returns review candidates (never deletes anything).
    /// `isCancelled` is polled so a newer scan can stop an older one.
    public static func scan(_ folder: URL, options: ScanOptions = ScanOptions(), isCancelled: () -> Bool = { false }) -> ScanResult {
        var result = ScanResult()
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { return result }
        let rootCount = folder.standardizedFileURL.pathComponents.count
        var entries = 0
        var uncategorised: [Int64: [(URL, Date?)]] = [:]
        while let url = enumerator.nextObject() as? URL {
            if isCancelled() { result.cancelled = true; return result }
            entries += 1
            if entries > options.maxEntries { result.truncated = true; break }
            guard let v = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if v.isDirectory == true { continue }
            let bytes = Int64(v.fileSize ?? 0)
            result.filesChecked += 1
            result.bytesChecked += bytes
            guard let (category, reason) = classify(url: url, bytes: bytes, modified: v.contentModificationDate, rootComponentCount: rootCount, options: options) else {
                if options.duplicateMinBytes > 0, bytes >= options.duplicateMinBytes { uncategorised[bytes, default: []].append((url, v.contentModificationDate)) }
                continue
            }
            result.items.append(ScanItem(url: url, category: category, bytes: bytes, modified: v.contentModificationDate, reason: reason))
        }
        if options.duplicateMinBytes > 0 {
            result.items += findDuplicates(uncategorised, isCancelled: isCancelled, cancelled: &result.cancelled)
            if result.cancelled { return result }
        }
        result.items.sort { $0.bytes > $1.bytes }
        return result
    }

    /// Same size, then same full content (hash bucket confirmed by a byte comparison).
    /// The oldest copy is treated as the original and is not listed; the others are.
    static func findDuplicates(_ bySize: [Int64: [(URL, Date?)]], isCancelled: () -> Bool, cancelled: inout Bool) -> [ScanItem] {
        var out: [ScanItem] = []
        for (size, files) in bySize where files.count > 1 {
            if isCancelled() { cancelled = true; return out }
            var buckets: [UInt64: [(URL, Date?)]] = [:]
            for f in files { if let h = fnv(f.0) { buckets[h, default: []].append(f) } }
            for (_, group) in buckets where group.count > 1 {
                let ordered = group.sorted { ($0.1 ?? .distantFuture, $0.0.path) < ($1.1 ?? .distantFuture, $1.0.path) }
                let original = ordered[0]
                for dup in ordered.dropFirst() where sameContent(original.0, dup.0) {
                    out.append(ScanItem(url: dup.0, category: .duplicates, bytes: size, modified: dup.1,
                                        reason: "Identical to \(original.0.lastPathComponent) (kept: \(original.0.deletingLastPathComponent().path))"))
                }
            }
        }
        return out
    }

    static func fnv(_ url: URL) -> UInt64? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hash: UInt64 = 0xcbf29ce484222325
        while let chunk = try? h.read(upToCount: 1 << 20), !chunk.isEmpty {
            for b in chunk { hash = (hash ^ UInt64(b)) &* 0x100000001b3 }
        }
        return hash
    }

    static func sameContent(_ a: URL, _ b: URL) -> Bool {
        guard let ha = try? FileHandle(forReadingFrom: a), let hb = try? FileHandle(forReadingFrom: b) else { return false }
        defer { try? ha.close(); try? hb.close() }
        while true {
            let ca = (try? ha.read(upToCount: 1 << 20)) ?? Data()
            let cb = (try? hb.read(upToCount: 1 << 20)) ?? Data()
            if ca != cb { return false }
            if ca.isEmpty { return true }
        }
    }

    static func classify(url: URL, bytes: Int64, modified: Date? = nil, rootComponentCount: Int, options: ScanOptions) -> (ItemCategory, String)? {
        let comps = url.standardizedFileURL.pathComponents
        // Any folder between the chosen root and the file counts, not just the direct parent.
        let folders = comps.dropFirst(rootComponentCount).dropLast()
        let ext = url.pathExtension.lowercased()
        if folders.contains(where: { cacheNames.contains($0.lowercased()) }) { return (.caches, "Stored inside a cache-named folder") }
        if ext == "log" { return (.logs, "Log file; check whether it is still needed") }
        if tempExtensions.contains(ext) { return (.temporary, "Temporary or backup-style extension; may hold data you want") }
        if bytes >= options.largeFileThreshold { return (.largeFiles, "Large file; size alone does not mean it is safe to remove") }
        if options.staleDays > 0, bytes >= options.staleMinBytes, let m = modified,
           let cutoff = Calendar.current.date(byAdding: .day, value: -options.staleDays, to: options.now), m < cutoff {
            return (.stale, "Not modified for over \(options.staleDays) days; review before removing")
        }
        return nil
    }
}
