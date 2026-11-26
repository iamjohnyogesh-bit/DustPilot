import Foundation

/// Filtering and selection rules for the review queue.
public enum Review {
    public static func visible(_ items: [ScanItem], filter: CategoryFilter, search: String) -> [ScanItem] {
        items.filter { item in
            let categoryOK: Bool
            switch filter {
            case .all: categoryOK = true
            case .category(let c): categoryOK = item.category == c
            }
            guard categoryOK else { return false }
            return search.isEmpty || item.name.localizedCaseInsensitiveContains(search) || item.path.localizedCaseInsensitiveContains(search)
        }
    }

    public enum SortOrder: String, CaseIterable, Sendable { case size = "Size", name = "Name", date = "Date modified" }

    public static func sorted(_ items: [ScanItem], by order: SortOrder) -> [ScanItem] {
        switch order {
        case .size: return items.sorted { $0.bytes > $1.bytes }
        case .name: return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date: return items.sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
        }
    }

    /// CSV report of items (for keeping a record before cleaning). Fields are quoted and escaped.
    public static func csv(_ items: [ScanItem]) -> String {
        func q(_ s: String) -> String {
            var v = s.replacingOccurrences(of: "\"", with: "\"\"")
            // Stop spreadsheet apps from running a file name that starts with a formula character.
            if let f = v.first, "=+-@".contains(f) { v = "'" + v }
            return "\"" + v + "\""
        }
        let iso = ISO8601DateFormatter()
        var lines = ["Name,Category,Bytes,Modified,Path,Reason"]
        for i in items {
            lines.append([q(i.name), q(i.category.rawValue), String(i.bytes), q(i.modified.map { iso.string(from: $0) } ?? ""), q(i.path), q(i.reason)].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Items that would be trashed: selected AND currently visible, so a filter can never
    /// hide something that still gets moved.
    public static func trashTargets(_ items: [ScanItem], selected: Set<UUID>, filter: CategoryFilter, search: String) -> [ScanItem] {
        visible(items, filter: filter, search: search).filter { selected.contains($0.id) }
    }
}

public protocol TrashService {
    func trash(_ url: URL) throws
}

#if os(macOS)
public struct SystemTrash: TrashService {
    public init() {}
    public func trash(_ url: URL) throws {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
    }
}
#endif

public struct TrashOutcome: Sendable {
    public var movedIDs = Set<UUID>()
    public var failures: [String] = []
    public init() {}
}

public enum Cleaner {
    /// Moves each item with the given service. One failure does not stop the rest.
    public static func trash(_ items: [ScanItem], using service: TrashService) -> TrashOutcome {
        var out = TrashOutcome()
        for item in items {
            do { try service.trash(item.url); out.movedIDs.insert(item.id) }
            catch { out.failures.append("\(item.name): \(error.localizedDescription)") }
        }
        return out
    }
}
