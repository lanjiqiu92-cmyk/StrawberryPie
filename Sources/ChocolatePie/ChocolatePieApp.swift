import SwiftUI
import AppKit
import Carbon

@main
struct ChocolatePieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PieStore.shared

    var body: some Scene {
        MenuBarExtra {
            Button("打开草莓派") {
                PanelController.shared.show()
            }
            .keyboardShortcut("o")

            Button("记下新想法") {
                PanelController.shared.showAndFocusComposer()
            }
            .keyboardShortcut("n")

            Divider()

            Text("⌥ Space 随时唤起")
                .foregroundStyle(.secondary)

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Text(menuBarCat)
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarCat: String {
        let openTasks = store.items.filter { $0.kind.supportsCompletion && !$0.isCompleted }.count
        let allTasks = store.items.filter { $0.kind.supportsCompletion }
        let trashCount = store.count(for: .trash)
        if trashCount >= 3 { return "🙀" }
        if openTasks > 0 { return "😼" }
        if !allTasks.isEmpty { return "😎" }
        if store.count(for: .idea) > 0 { return "🐱" }
        return "🐾"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hotKeyManager = HotKeyManager {
            PanelController.shared.toggle()
        }
        WellnessReminderScheduler.shared.start()
        PanelController.shared.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelController.shared.showAndFocusComposer()
        return true
    }
}

final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 748),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ChocolatePieView())
        return panel
    }()

    func show() {
        positionIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func showAndFocusComposer() {
        show()
        NotificationCenter.default.post(name: .focusChocolatePieComposer, object: nil)
    }

    func toggle() {
        if panel.isVisible && panel.isKeyWindow {
            panel.orderOut(nil)
        } else {
            showAndFocusComposer()
        }
    }

    private func positionIfNeeded() {
        guard !panel.isVisible, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - panel.frame.width - 28,
            y: visible.maxY - panel.frame.height - 28
        ))
    }
}

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.action() }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x43504945), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

extension Notification.Name {
    static let focusChocolatePieComposer = Notification.Name("focusChocolatePieComposer")
    static let previewCatOutfit = Notification.Name("previewCatOutfit")
}
