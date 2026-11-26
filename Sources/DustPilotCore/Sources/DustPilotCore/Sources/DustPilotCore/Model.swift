import Foundation

public enum ItemCategory: String, CaseIterable, Sendable {
    case caches = "Caches"
    case logs = "Logs"
    case temporary = "Temporary"
    case largeFiles = "Large files"
    case stale = "Old files"
    case duplicates = "Duplicates"

    public var icon: String {
        switch self {
        case .caches: return "shippingbox"
        case .logs: return "doc.text"
        case .temporary: return "clock.arrow.circlepath"
        case .largeFiles: return "externaldrive"
        case .stale: return "calendar.badge.clock"
        case .duplicates: return "doc.on.doc"
        }
    }
}

/// Filter choices shown in the UI. `nil` category means "All items".
public enum CategoryFilter: Hashable, Sendable {
    case all
    case category(ItemCategory)

    public static var allChoices: [CategoryFilter] { [.all] + ItemCategory.allCases.map { .category($0) } }
    public var title: String {
        switch self {
        case .all: return "All items"
        case .category(let c): return c.rawValue
        }
    }
}

public struct ScanItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let path: String
    public let category: ItemCategory
    public let bytes: Int64
    public let modified: Date?
    public let reason: String

    public init(id: UUID = UUID(), url: URL, category: ItemCategory, bytes: Int64, modified: Date?, reason: String) {
        self.id = id; self.url = url; self.name = url.lastPathComponent; self.path = url.path
        self.category = category; self.bytes = bytes; self.modified = modified; self.reason = reason
    }
    public var sizeText: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    public var icon: String { category.icon }
}

public struct ScanResult: Sendable {
    public var items: [ScanItem] = []
    /// Regular files examined (folders are not counted).
    public var filesChecked = 0
    public var bytesChecked: Int64 = 0
    /// True when the entry cap stopped the walk early, so the results are partial.
    public var truncated = false
    public var cancelled = false
    public init() {}
}
