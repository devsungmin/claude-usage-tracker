import SwiftUI

@main
struct ClaudeUsageTracker: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All UI managed by AppDelegate (NSStatusItem + NSPopover + NSWindow)
        // Empty Settings scene required to satisfy SwiftUI App protocol
        Settings {
            EmptyView()
        }
    }
}
