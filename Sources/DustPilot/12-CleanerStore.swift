#if canImport(SwiftUI) && os(macOS)
import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers
import DustPilotCore

@MainActor final class CleanerStore: ObservableObject {
    @Published var root: URL?
    @Published var items: [ScanItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var status = "Choose a folder to begin"
    @Published var search = ""
    @Published var filter: CategoryFilter = .all
    @Published var sortOrder: Review.SortOrder = .size
    @Published var selectedIDs = Set<UUID>()
    @Published var scannedCount = 0
    @Published var truncated = false
    @Published var errorMessage: String?
    @Published var showError = false
    private var scanTask: Task<Void, Never>?
    private var generation = 0

    var visibleItems: [ScanItem] { Review.sorted(Review.visible(items, filter: filter, search: search), by: sortOrder) }
    /// What "Move to Trash" will actually act on (selected and visible).
    var targets: [ScanItem] { Review.trashTargets(items, selected: selectedIDs, filter: filter, search: search) }
    var targetBytes: Int64 { targets.reduce(0) { $0 + $1.bytes } }
    var reclaimableBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to analyse"
        panel.prompt = "Analyse Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { scan(url) }
    }

    func scan(_ folder: URL) {
        scanTask?.cancel()
        generation += 1
        let mine = generation
        root = folder
        isScanning = true
        truncated = false
        status = "Analysing folder…"
        items = []; selectedIDs = []; scannedCount = 0
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = FolderScanner.scan(folder, isCancelled: { Task.isCancelled })
            await MainActor.run {
                guard let self, self.generation == mine, !result.cancelled else { return }
                self.items = result.items
                self.scannedCount = result.filesChecked
                self.truncated = result.truncated
                // Nothing is pre-selected: the user opts in to each removal.
                self.selectedIDs = []
                self.isScanning = false
                self.status = "Analysis complete · \(result.items.count) review candidates"
                    + (result.truncated ? " · stopped at the entry limit, results are partial" : "")
            }
        }
    }

    func toggle(_ item: ScanItem) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
    }
    func selectAllVisible(_ value: Bool) {
        for item in visibleItems { if value { selectedIDs.insert(item.id) } else { selectedIDs.remove(item.id) } }
    }

    func moveSelectedToTrash() {
        let chosen = targets
        guard !chosen.isEmpty, !isCleaning else { return }
        isCleaning = true; status = "Moving \(chosen.count) item(s) to Trash…"
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { Cleaner.trash(chosen, using: SystemTrash()) }.value
            items.removeAll { outcome.movedIDs.contains($0.id) }
            selectedIDs.subtract(outcome.movedIDs)
            isCleaning = false
            status = "Moved \(outcome.movedIDs.count) item(s) to Trash · \(outcome.failures.count) failed · Use Put Back in Trash to restore"
            if !outcome.failures.isEmpty { errorMessage = outcome.failures.prefix(5).joined(separator: "\n"); showError = true }
        }
    }
    func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "DustPilot-report.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Review.csv(visibleItems).write(to: url, atomically: true, encoding: .utf8); status = "Report saved: \(url.lastPathComponent)" }
        catch { errorMessage = error.localizedDescription; showError = true }
    }
    func reveal(_ item: ScanItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
}
#endif
