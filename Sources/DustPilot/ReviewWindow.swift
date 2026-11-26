#if canImport(SwiftUI) && os(macOS)
import SwiftUI
import DustPilotCore

struct ReviewWindow: View {
    @EnvironmentObject private var store: CleanerStore
    @State private var askToTrash = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
            Divider()
            footer
        }
        .confirmationDialog("Move \(store.targets.count) item(s) to the Trash?",
                            isPresented: $askToTrash, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) { store.moveSelectedToTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Total \(byteString(store.targetBytes)). You can restore them with Put Back in the Trash.")
        }
        .alert("Some items could not be moved", isPresented: $store.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DustPilot").font(.title2.bold())
                Text(store.root?.path ?? "Pick a folder to look for clutter. Nothing is selected until you choose it.")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if store.isScanning { ProgressView().controlSize(.small) }
            Button(store.root == nil ? "Choose Folder…" : "Scan Another Folder…") { store.chooseFolder() }
                .keyboardShortcut("o")
                .disabled(store.isScanning || store.isCleaning)
        }
        .padding(16)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            TextField("Search name or path", text: $store.search).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
            Picker("Category", selection: $store.filter) {
                ForEach(CategoryFilter.allChoices, id: \.self) { Text($0.title).tag($0) }
            }.frame(width: 190)
            Picker("Sort", selection: $store.sortOrder) {
                ForEach(Review.SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.frame(width: 190)
            Spacer()
            Button("Select Visible") { store.selectAllVisible(true) }.disabled(store.visibleItems.isEmpty)
            Button("Clear Selection") { store.selectedIDs = [] }.disabled(store.selectedIDs.isEmpty)
            Button("Export CSV…") { store.exportCSV() }.disabled(store.visibleItems.isEmpty)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        if store.items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Text(store.isScanning ? "Scanning…" : "No candidates yet").font(.headline)
                Text(store.isScanning ? "Large folders can take a moment." : "Choose a folder to start.")
                    .foregroundStyle(.secondary)
                Spacer()
            }.frame(maxWidth: .infinity)
        } else {
            List(store.visibleItems.prefix(500)) { item in
                row(item)
            }
        }
    }

    private func row(_ item: ScanItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { store.selectedIDs.contains(item.id) },
                                     set: { _ in store.toggle(item) }))
                .labelsHidden()
            Image(systemName: item.icon).frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                Text("\(item.reason) · \(item.path)").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.category.rawValue).font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            Text(item.sizeText).monospacedDigit().frame(width: 80, alignment: .trailing)
            Button { store.reveal(item) } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderless).help("Show in Finder")
        }
    }

    private var footer: some View {
        HStack {
            if store.isCleaning { ProgressView().controlSize(.small) }
            Text(store.status).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            if store.visibleItems.count > 500 {
                Text("Showing first 500 of \(store.visibleItems.count). Narrow with search or filter.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("\(store.targets.count) selected · \(byteString(store.targetBytes))").monospacedDigit()
            Button("Move to Trash…") { askToTrash = true }
                .disabled(store.targets.isEmpty || store.isScanning || store.isCleaning)
        }
        .padding(12)
    }

    private func byteString(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
}
#endif
