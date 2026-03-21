import AppKit
import SwiftUI
import Combine

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = AppViewModel()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeStatusBarText()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )
    }

    @objc private func handleOpenSettings() {
        openSettingsWindow()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Claude Usage Tracker")
            button.imagePosition = .imageLeading
            button.title = viewModel.statusBarText
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView().environmentObject(viewModel)
        )
    }

    private func observeStatusBarText() {
        viewModel.$statusBarText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.statusItem.button?.title = text
            }
            .store(in: &cancellables)
    }

    @objc private func handleClick() {
        guard let button = statusItem.button,
              let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(from: button)
        } else {
            togglePopover(from: button)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(withTitle: "새로고침", action: #selector(refreshAction), keyEquivalent: "r").target = self
        menu.addItem(.separator())

        let settingsItem = menu.addItem(withTitle: "설정...", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self

        menu.addItem(.separator())

        if viewModel.authState == .loggedIn {
            menu.addItem(withTitle: "로그아웃", action: #selector(logoutAction), keyEquivalent: "").target = self
        }

        menu.addItem(withTitle: "종료", action: #selector(quitAction), keyEquivalent: "q").target = self

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshAction() {
        Task { await viewModel.refreshUsage() }
    }

    @objc private func settingsAction() {
        openSettingsWindow()
    }

    @objc private func logoutAction() {
        viewModel.logout()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    func openSettingsWindow() {
        popover.performClose(nil)

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView().environmentObject(viewModel)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "설정"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}
