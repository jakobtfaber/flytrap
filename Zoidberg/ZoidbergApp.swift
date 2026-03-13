import SwiftUI

@main
struct ZoidbergApp: App {
    var body: some Scene {
        MenuBarExtra("Zoidberg", systemImage: "desktopcomputer.and.arrow.down") {
            Text("Zoidberg")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
