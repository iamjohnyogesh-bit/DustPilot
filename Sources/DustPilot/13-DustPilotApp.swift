#if canImport(SwiftUI) && os(macOS)
import SwiftUI

@main
struct DustPilotApp: App {
    @StateObject private var store = CleanerStore()

    var body: some Scene {
        WindowGroup("DustPilot") {
            ReviewWindow()
                .environmentObject(store)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1000, height: 700)
    }
}
#else
@main enum DustPilotUnsupported {
    static func main() { print("DustPilot runs on macOS 14+ only.") }
}
#endif
