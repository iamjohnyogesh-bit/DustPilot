import XCTest
@testable import DustPilotCore

final class CoreTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("dp-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    @discardableResult func make(_ rel: String, bytes: Int = 10, fill: UInt8 = 1, age days: Int? = nil) throws -> URL {
        let u = root.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: fill, count: bytes).write(to: u)
        if let d = days { try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-Double(d) * 86400)], ofItemAtPath: u.path) }
        return u
    }
    func opts(large: Int64 = 1_000_000, max: Int = 100_000, stale: Int = 0, dup: Int64 = 0) -> ScanOptions {
        ScanOptions(largeFileThreshold: large, maxEntries: max, staleDays: stale, staleMinBytes: 0, duplicateMinBytes: dup)
    }
    func names(_ r: ScanResult, _ c: ItemCategory) -> Set<String> { Set(r.items.filter { $0.category == c }.map(\.name)) }

    func testCategories() throws {
        try make("Caches/a.dat"); try make("app.log"); try make("x.tmp"); try make("n.BAK"); try make("keep.txt")
        try make("big.bin", bytes: 2_000_000)
        let r = FolderScanner.scan(root, options: opts())
        XCTAssertEqual(names(r, .caches), ["a.dat"]); XCTAssertEqual(names(r, .logs), ["app.log"])
        XCTAssertEqual(names(r, .temporary), ["x.tmp", "n.BAK"]); XCTAssertEqual(names(r, .largeFiles), ["big.bin"])
        XCTAssertEqual(r.items.count, 5); XCTAssertEqual(r.filesChecked, 6)
    }
    func testNestedCacheFolderDetected() throws {
        try make("Caches/sub/deeper/f.dat")
        XCTAssertEqual(names(FolderScanner.scan(root, options: opts()), .caches), ["f.dat"])
    }
    func testChosenRootNamedCacheDoesNotFlagEverything() throws {
        let cacheRoot = root.appendingPathComponent("Caches"); try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        try Data([1]).write(to: cacheRoot.appendingPathComponent("plain.txt"))
        XCTAssertTrue(FolderScanner.scan(cacheRoot, options: opts()).items.isEmpty)
    }
    func testSymlinksSkippedAndHiddenSkipped() throws {
        let real = try make("real.log")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.log"), withDestinationURL: real)
        try make(".hidden.log")
        XCTAssertEqual(names(FolderScanner.scan(root, options: opts()), .logs), ["real.log"])
    }
    func testEntryCapReportsTruncation() throws {
        for i in 0..<20 { try make("f\(i).log") }
        let r = FolderScanner.scan(root, options: opts(max: 5))
        XCTAssertTrue(r.truncated); XCTAssertLessThanOrEqual(r.items.count, 5)
    }
    func testCancellation() throws {
        for i in 0..<10 { try make("f\(i).log") }
        let r = FolderScanner.scan(root, options: opts(), isCancelled: { true })
        XCTAssertTrue(r.cancelled)
    }
    func testStaleFiles() throws {
        try make("old.dat", age: 400); try make("new.dat", age: 5)
        let r = FolderScanner.scan(root, options: opts(stale: 365))
        XCTAssertEqual(names(r, .stale), ["old.dat"])
    }
    func testDuplicates() throws {
        try make("a/orig.bin", bytes: 2048, fill: 7, age: 30); try make("b/copy.bin", bytes: 2048, fill: 7, age: 1)
        try make("c/diff.bin", bytes: 2048, fill: 8); try make("d/small.bin", bytes: 10, fill: 7)
        let r = FolderScanner.scan(root, options: opts(dup: 1024))
        XCTAssertEqual(names(r, .duplicates), ["copy.bin"], "oldest copy is kept, newer copy listed")
    }
    func testSameSizeDifferentContentNotDuplicate() throws {
        try make("a.bin", bytes: 4096, fill: 1); try make("b.bin", bytes: 4096, fill: 2)
        XCTAssertTrue(names(FolderScanner.scan(root, options: opts(dup: 1024)), .duplicates).isEmpty)
    }

    func item(_ n: String, _ c: ItemCategory, _ b: Int64 = 1) -> ScanItem { ScanItem(url: URL(fileURLWithPath: "/tmp/\(n)"), category: c, bytes: b, modified: nil, reason: "") }
    func testFilterAndSearch() {
        let items = [item("a.log", .logs), item("b.tmp", .temporary), item("Report.log", .logs)]
        XCTAssertEqual(Review.visible(items, filter: .category(.logs), search: "").count, 2)
        XCTAssertEqual(Review.visible(items, filter: .all, search: "report").count, 1)
    }
    func testTrashTargetsOnlySelectedAndVisible() {
        let items = [item("a.log", .logs), item("b.tmp", .temporary)]
        let sel = Set(items.map(\.id))
        let t = Review.trashTargets(items, selected: sel, filter: .category(.logs), search: "")
        XCTAssertEqual(t.map(\.name), ["a.log"], "a filtered-out item must never be trashed")
        XCTAssertTrue(Review.trashTargets(items, selected: [], filter: .all, search: "").isEmpty)
    }
    func testSorting() {
        let items = [item("b", .logs, 5), item("a", .logs, 50)]
        XCTAssertEqual(Review.sorted(items, by: .size).map(\.name), ["a", "b"])
        XCTAssertEqual(Review.sorted(items, by: .name).map(\.name), ["a", "b"])
    }
    func testCSVEscapingAndFormulaGuard() {
        let i = ScanItem(url: URL(fileURLWithPath: "/tmp/=evil \"x\".log"), category: .logs, bytes: 3, modified: nil, reason: "a, b")
        let csv = Review.csv([i])
        XCTAssertTrue(csv.hasPrefix("Name,Category,Bytes,Modified,Path,Reason\n"))
        XCTAssertTrue(csv.contains("\"'=evil \"\"x\"\".log\""))
        XCTAssertTrue(csv.contains("\"a, b\""))
    }

    struct Mock: TrashService {
        var failing: Set<String>
        struct E: LocalizedError { var errorDescription: String? { "denied" } }
        func trash(_ url: URL) throws { if failing.contains(url.lastPathComponent) { throw E() } }
    }
    func testCleanerContinuesAfterFailure() {
        let items = [item("a", .logs), item("bad", .logs), item("c", .logs)]
        let o = Cleaner.trash(items, using: Mock(failing: ["bad"]))
        XCTAssertEqual(o.movedIDs.count, 2); XCTAssertEqual(o.failures, ["bad: denied"])
    }
    func testScannerNeverModifiesFiles() throws {
        let u = try make("x.log"); let before = try Data(contentsOf: u)
        _ = FolderScanner.scan(root, options: opts(dup: 1))
        XCTAssertEqual(try Data(contentsOf: u), before)
    }
}
