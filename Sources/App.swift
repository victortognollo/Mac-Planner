import AppKit
import ServiceManagement
import SwiftUI

enum WindowPlacement: String, CaseIterable, Identifiable {
    case desktop, normal, floating
    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktop: return tr("On the desktop, behind windows")
        case .normal: return tr("Normal window")
        case .floating: return tr("Always on top")
        }
    }
}

enum PlannerLayout: String, CaseIterable, Identifiable {
    case horizontal, vertical
    var id: String { rawValue }

    var title: String {
        switch self {
        case .horizontal: return tr("Horizontal (days in columns)")
        case .vertical: return tr("Vertical (days in rows)")
        }
    }

    /// Size where everything fits at 100%. Below it the whole planner scales down to fit.
    var comfortableSize: NSSize {
        switch self {
        case .horizontal: return NSSize(width: 1260, height: 380)
        case .vertical: return NSSize(width: 440, height: 560)
        }
    }

    /// Text never shrinks below this fraction of its normal size.
    static let smallestScale: CGFloat = 0.6

    var minimumSize: NSSize {
        NSSize(width: (comfortableSize.width * Self.smallestScale).rounded(),
               height: (comfortableSize.height * Self.smallestScale).rounded())
    }

    /// Each layout remembers its own size and position.
    var frameName: String {
        switch self {
        case .horizontal: return "PlannerWindow"
        case .vertical: return "PlannerWindowVertical"
        }
    }

    /// First use: a strip along the bottom, or a tall panel on the right edge.
    func defaultFrame(in vf: NSRect) -> NSRect {
        switch self {
        case .horizontal:
            let width = min(vf.width - 48, 1680)
            return NSRect(x: vf.midX - width / 2, y: vf.minY + 16, width: width, height: 480)
        case .vertical:
            let width: CGFloat = 440
            let height = min(vf.height - 32, 1000)
            return NSRect(x: vf.maxX - width - 16, y: vf.maxY - height - 16, width: width, height: height)
        }
    }
}

enum TextSize: String, CaseIterable, Identifiable {
    case small, regular, large, larger
    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return tr("Small")
        case .regular: return tr("Default")
        case .large: return tr("Large")
        case .larger: return tr("Larger")
        }
    }

    /// Point size of item titles inside the days.
    var points: CGFloat {
        switch self {
        case .small: return 12
        case .regular: return 13
        case .large: return 15
        case .larger: return 17
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var textSize: TextSize {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: "textSize") }
    }
    @Published var placement: WindowPlacement {
        didSet {
            UserDefaults.standard.set(placement.rawValue, forKey: "placement")
            apply()
        }
    }
    @Published private(set) var launchAtLogin: Bool
    weak var window: NSWindow?

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "language")
            onLanguageChange?()
        }
    }
    var onLanguageChange: (() -> Void)?

    @Published var layout: PlannerLayout {
        didSet {
            guard layout != oldValue else { return }
            UserDefaults.standard.set(layout.rawValue, forKey: "layout")
            window?.saveFrame(usingName: oldValue.frameName)
            // Resize after SwiftUI finishes the current update (the change comes from a menu).
            DispatchQueue.main.async { self.restoreFrame() }
        }
    }

    /// Applies the current layout's minimum size and its remembered (or default) frame.
    func restoreFrame() {
        guard let w = window else { return }
        let minimum = layout.minimumSize
        w.contentMinSize = minimum
        // Detach the old autosave name first, or restoring the new frame would overwrite the old layout's.
        w.setFrameAutosaveName("")
        if !w.setFrameUsingName(layout.frameName), let vf = (w.screen ?? NSScreen.main)?.visibleFrame {
            w.setFrame(layout.defaultFrame(in: vf), display: true)
        }
        w.setFrameAutosaveName(layout.frameName)
        // A saved frame may be smaller than the minimum; grow it and keep it on screen.
        if w.frame.width < minimum.width || w.frame.height < minimum.height {
            var f = w.frame
            f.size.width = max(f.width, minimum.width)
            f.size.height = max(f.height, minimum.height)
            if let vf = w.screen?.visibleFrame {
                f.origin.x = min(max(f.minX, vf.minX), vf.maxX - f.width)
                f.origin.y = min(max(f.minY, vf.minY), vf.maxY - f.height)
            }
            w.setFrame(f, display: true)
        }
    }

    init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
        layout = PlannerLayout(rawValue: UserDefaults.standard.string(forKey: "layout") ?? "") ?? .horizontal
        textSize = TextSize(rawValue: UserDefaults.standard.string(forKey: "textSize") ?? "") ?? .regular
        placement = WindowPlacement(rawValue: UserDefaults.standard.string(forKey: "placement") ?? "") ?? .desktop
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func apply() {
        guard let w = window else { return }
        switch placement {
        case .desktop:
            // Above the desktop icons, below every app window: behaves like a widget.
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        case .normal:
            w.level = .normal
            w.collectionBehavior = [.canJoinAllSpaces]
        case .floating:
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        w.orderFrontRegardless()
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Planner: could not change launch at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// A titled window that still takes keyboard focus when it sits at desktop level.
final class PlannerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !NSApp.isActive {
            NSApp.activate()
            makeKey()
        }
        super.sendEvent(event)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = PlannerStore()
    let timer = FocusTimer()
    let settings = AppSettings()
    let calendar = CalendarService()
    private var window: PlannerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeMainMenu()

        Notifier.shared.setup()
        Notifier.shared.reschedule(store.data.items)
        timer.onFinish = { [weak self] minutes in
            self?.store.addFocus(minutes: minutes, day: Day.todayKey)
        }

        // Menus, alerts and synced events carry text, so refresh them in the new language.
        settings.onLanguageChange = { [weak self] in
            guard let self else { return }
            NSApp.mainMenu = self.makeMainMenu()
            Notifier.shared.updateCategories()
            Notifier.shared.reschedule(self.store.data.items)
            self.calendar.reload()
        }

        makeWindow()

        if !UserDefaults.standard.bool(forKey: "didEnableLaunchAtLogin") {
            settings.setLaunchAtLogin(true)
            UserDefaults.standard.set(true, forKey: "didEnableLaunchAtLogin")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.orderFrontRegardless()
        return true
    }

    private func makeWindow() {
        let w = PlannerWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 480),
                              styleMask: [.titled, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        w.title = "Planner"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach { w.standardWindowButton($0)?.isHidden = true }
        w.isMovableByWindowBackground = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.isReleasedWhenClosed = false

        let glass = NSVisualEffectView()
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active

        let root = RootView()
            .environmentObject(store)
            .environmentObject(timer)
            .environmentObject(settings)
            .environmentObject(calendar)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            host.topAnchor.constraint(equalTo: glass.topAnchor),
            host.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        w.contentView = glass

        window = w
        settings.window = w
        settings.restoreFrame()
        settings.apply()
        w.makeKeyAndOrderFront(nil)
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("Quit Planner"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // Lets ⌘C, ⌘V, ⌘Z and ⌘A work inside the text fields.
        let editItem = NSMenuItem()
        let edit = NSMenu(title: tr("Edit"))
        edit.addItem(withTitle: tr("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: tr("Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        return main
    }
}

@main
enum PlannerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
