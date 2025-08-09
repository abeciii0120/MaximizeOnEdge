import AppKit
import ApplicationServices

enum ScreenEdge: String {
    case top = "top"
    case bottom = "bottom"
    case left = "left"
    case right = "right"
}

final class PreviewView: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        dirtyRect.fill()
        let borderRect = bounds.insetBy(dx: 1.0, dy: 1.0)
        let path = NSBezierPath(rect: borderRect)
        path.lineWidth = 2.0
        NSColor.systemBlue.setStroke()
        path.stroke()
    }
}

final class SettingsWindowController: NSWindowController {
    private let thresholdSlider = NSSlider(value: 12, minValue: 4, maxValue: 48, target: nil, action: nil)
    private let thresholdValueLabel = NSTextField(labelWithString: "12")
    private let topCheckbox = NSButton(checkboxWithTitle: "上端で最大化", target: nil, action: nil)
    private let leftCheckbox = NSButton(checkboxWithTitle: "左端で左半分にスナップ", target: nil, action: nil)
    private let rightCheckbox = NSButton(checkboxWithTitle: "右端で右半分にスナップ", target: nil, action: nil)
    private let bottomCheckbox = NSButton(checkboxWithTitle: "下端で最大化", target: nil, action: nil)
    private let previewCheckbox = NSButton(checkboxWithTitle: "プレビューを表示", target: nil, action: nil)

    private weak var delegate: AppDelegate?

    init(owner: AppDelegate) {
        self.delegate = owner
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "設定"
        super.init(window: window)
        setupUI()
        loadFromDefaults()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false

        let thresholdRow = NSStackView(views: [NSTextField(labelWithString: "端のしきい値 (px)"), thresholdSlider, thresholdValueLabel])
        thresholdRow.orientation = .horizontal
        thresholdRow.alignment = .firstBaseline
        thresholdRow.spacing = 8

        thresholdSlider.target = self
        thresholdSlider.action = #selector(thresholdChanged)
        thresholdValueLabel.alignment = .right
        thresholdValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        thresholdValueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        for cb in [topCheckbox, leftCheckbox, rightCheckbox, bottomCheckbox, previewCheckbox] {
            cb.target = self
            cb.action = #selector(checkboxChanged(_:))
        }

        root.addArrangedSubview(thresholdRow)
        root.addArrangedSubview(topCheckbox)
        root.addArrangedSubview(leftCheckbox)
        root.addArrangedSubview(rightCheckbox)
        root.addArrangedSubview(bottomCheckbox)
        root.addArrangedSubview(previewCheckbox)
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    private func loadFromDefaults() {
        let d = UserDefaults.standard
        let threshold = d.object(forKey: "edgeThreshold") as? Double ?? 12.0
        thresholdSlider.doubleValue = threshold
        thresholdValueLabel.stringValue = String(format: "%.0f", threshold)
        topCheckbox.state = (d.object(forKey: "enableTop") as? Bool ?? true) ? .on : .off
        leftCheckbox.state = (d.object(forKey: "enableLeft") as? Bool ?? true) ? .on : .off
        rightCheckbox.state = (d.object(forKey: "enableRight") as? Bool ?? true) ? .on : .off
        bottomCheckbox.state = (d.object(forKey: "enableBottom") as? Bool ?? true) ? .on : .off
        previewCheckbox.state = (d.object(forKey: "showPreview") as? Bool ?? true) ? .on : .off
    }

    @objc private func thresholdChanged() {
        thresholdValueLabel.stringValue = String(format: "%.0f", thresholdSlider.doubleValue)
        UserDefaults.standard.set(thresholdSlider.doubleValue, forKey: "edgeThreshold")
        delegate?.preferencesUpdated()
    }

    @objc private func checkboxChanged(_ sender: NSButton) {
        let d = UserDefaults.standard
        d.set(topCheckbox.state == .on, forKey: "enableTop")
        d.set(leftCheckbox.state == .on, forKey: "enableLeft")
        d.set(rightCheckbox.state == .on, forKey: "enableRight")
        d.set(bottomCheckbox.state == .on, forKey: "enableBottom")
        d.set(previewCheckbox.state == .on, forKey: "showPreview")
        delegate?.preferencesUpdated()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Snap behavior state
    private var dragSessionActive = false
    private var observedWindow: AXUIElement?
    private var observedWindowInitialPosition: CGPoint?
    private var didMoveObservedWindow = false

    private var previewWindow: NSWindow?
    private var isInSnapZone = false

    private var settingsWC: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaultPreferences()
        setupMenuBar()
        ensureAccessibilityPermission()
        NSLog("[MaximizeOnEdge] AX trusted: \(AXIsProcessTrusted())")
        startGlobalMouseMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopGlobalMouseMonitor()
        hidePreview()
    }

    private func registerDefaultPreferences() {
        UserDefaults.standard.register(defaults: [
            "edgeThreshold": 12.0,
            "enableTop": true,
            "enableLeft": true,
            "enableRight": true,
            "enableBottom": true,
            "showPreview": true
        ])
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let img = NSImage(contentsOfFile: iconPath) {
                img.size = NSSize(width: 18, height: 18)
                button.image = img
            } else {
                button.title = "⬜︎"
            }
            button.toolTip = "Maximize on Edge"
        }
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let toggle = NSMenuItem(title: "ログイン時に自動起動", action: #selector(toggleLoginItem), keyEquivalent: "")
        toggle.target = self
        loginItemMenuItem = toggle
        updateLoginItemMenuState()
        menu.addItem(toggle)
        menu.addItem(NSMenuItem(title: "アクセシビリティ設定を開く", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWC == nil { settingsWC = SettingsWindowController(owner: self) }
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func preferencesUpdated() {
        // 反映は動的。必要に応じてプレビューを再判定
        hidePreview()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func ensureAccessibilityPermission() {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options: [String: Any] = [checkOptPrompt: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("[MaximizeOnEdge] Requested AX trust prompt. Current trusted=\(trusted)")
    }

    private func startGlobalMouseMonitor() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue |
                               1 << CGEventType.leftMouseDragged.rawValue |
                               1 << CGEventType.leftMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
            switch type {
            case .leftMouseDown:
                NSLog("[MaximizeOnEdge] leftMouseDown (Cocoa)=\(NSEvent.mouseLocation)")
                DispatchQueue.main.async { delegate.handleMouseDown() }
            case .leftMouseDragged:
                if Int.random(in: 0..<30) == 0 { NSLog("[MaximizeOnEdge] leftMouseDragged (Cocoa)=\(NSEvent.mouseLocation)") }
                DispatchQueue.main.async { delegate.handleMouseDragged() }
            case .leftMouseUp:
                NSLog("[MaximizeOnEdge] leftMouseUp (Cocoa)=\(NSEvent.mouseLocation)")
                DispatchQueue.main.async { delegate.handleMouseUp() }
            default: break
            }
            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap else {
            NSLog("[MaximizeOnEdge] Failed to create event tap")
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        NSLog("[MaximizeOnEdge] Event tap started")
    }

    private func stopGlobalMouseMonitor() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes) }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        runLoopSource = nil
        eventTap = nil
        NSLog("[MaximizeOnEdge] Event tap stopped")
    }

    // MARK: - Drag flow

    private func handleMouseDown() {
        dragSessionActive = true
        didMoveObservedWindow = false
        observedWindowInitialPosition = nil
        observedWindow = focusedWindow()
        if let window = observedWindow { observedWindowInitialPosition = windowPosition(window: window) }
        hidePreview()
        isInSnapZone = false
        NSLog("[MaximizeOnEdge] Drag start. hasWindow=\(observedWindow != nil)")
    }

    private func handleMouseDragged() {
        guard dragSessionActive else { return }

        if let window = observedWindow, let initialPos = observedWindowInitialPosition, let currentPos = windowPosition(window: window) {
            let dx = abs(currentPos.x - initialPos.x)
            let dy = abs(currentPos.y - initialPos.y)
            if dx >= 1.0 || dy >= 1.0 { didMoveObservedWindow = true }
        }

        let point = NSEvent.mouseLocation
        guard let screen = screenForPoint(point) else { return }
        let nearAny = isNearAnyEnabledEdge(point: point, in: screen.frame)
        if nearAny {
            if !isInSnapZone { showPreview(on: screen) }
            isInSnapZone = true
        } else {
            if isInSnapZone { hidePreview() }
            isInSnapZone = false
        }
    }

    private func handleMouseUp() {
        defer { hidePreview(); resetDragSession() }
        guard dragSessionActive else { return }
        NSLog("[MaximizeOnEdge] Drag end. moved=\(didMoveObservedWindow)")
        guard didMoveObservedWindow else { return }

        let point = NSEvent.mouseLocation
        guard let screen = screenForPoint(point) else { return }
        
        let edge = isInSnapZone ? detectTriggeredEdge(point: point, in: screen.frame) : detectTriggeredEdge(point: point, in: screen.frame)
        NSLog("[MaximizeOnEdge] triggeredEdge=\(edge?.rawValue ?? "none")")
        guard let triggeredEdge = edge else { return }

        if let window = observedWindow {
            snapWindow(window: window, toEdge: triggeredEdge, screen: screen)
        } else if let focusedWindow = focusedWindow() {
            snapWindow(window: focusedWindow, toEdge: triggeredEdge, screen: screen)
        }
    }

    private func resetDragSession() {
        dragSessionActive = false
        observedWindow = nil
        observedWindowInitialPosition = nil
        didMoveObservedWindow = false
        isInSnapZone = false
    }

    // MARK: - Helpers

    private func screenForPoint(_ point: CGPoint) -> NSScreen? {
        if let s = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) { return s }
        return NSScreen.main
    }

    private func currentThreshold() -> CGFloat {
        let v = UserDefaults.standard.double(forKey: "edgeThreshold")
        return v > 0 ? CGFloat(v) : 12.0
    }

    private func isEnabled(_ key: String, default value: Bool) -> Bool {
        if let obj = UserDefaults.standard.object(forKey: key) as? Bool { return obj }
        return value
    }

    private func isNearAnyEnabledEdge(point: NSPoint, in frame: NSRect) -> Bool {
        let t = currentThreshold()
        let nearLeft = abs(point.x - frame.minX) <= t
        let nearRight = abs(point.x - frame.maxX) <= t
        let nearTop = abs(point.y - frame.maxY) <= t
        let nearBottom = abs(point.y - frame.minY) <= t
        let eTop = isEnabled("enableTop", default: true)
        let eLeft = isEnabled("enableLeft", default: true)
        let eRight = isEnabled("enableRight", default: true)
        let eBottom = isEnabled("enableBottom", default: true)
        return (eLeft && nearLeft) || (eRight && nearRight) || (eTop && nearTop) || (eBottom && nearBottom)
    }
    
    private func detectTriggeredEdge(point: NSPoint, in frame: NSRect) -> ScreenEdge? {
        let t = currentThreshold()
        let nearLeft = abs(point.x - frame.minX) <= t
        let nearRight = abs(point.x - frame.maxX) <= t
        let nearTop = abs(point.y - frame.maxY) <= t
        let nearBottom = abs(point.y - frame.minY) <= t
        
        if isEnabled("enableLeft", default: true) && nearLeft {
            return .left
        } else if isEnabled("enableRight", default: true) && nearRight {
            return .right
        } else if isEnabled("enableTop", default: true) && nearTop {
            return .top
        } else if isEnabled("enableBottom", default: true) && nearBottom {
            return .bottom
        }
        return nil
    }

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard result == .success, let windowRef = focusedWindow else { return nil }
        return (windowRef as! AXUIElement)
    }

    private func windowPosition(window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        guard result == .success, let cfValue = value else { return nil }
        guard CFGetTypeID(cfValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        let success = withUnsafeMutablePointer(to: &point) { ptr -> Bool in
            return AXValueGetValue((cfValue as! AXValue), .cgPoint, ptr)
        }
        return success ? point : nil
    }

    private func maximizeFocusedWindow(toVisibleFrame visibleFrame: NSRect) {
        guard let window = focusedWindow() else { return }
        maximizeWindow(window: window, toVisibleFrame: visibleFrame)
    }

    private func snapWindow(window: AXUIElement, toEdge edge: ScreenEdge, screen: NSScreen) {
        var positionEnabled: DarwinBoolean = true
        var sizeEnabled: DarwinBoolean = true
        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionEnabled)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeEnabled)
        NSLog("[MaximizeOnEdge] canSet pos=\(positionEnabled.boolValue) size=\(sizeEnabled.boolValue)")
        guard positionEnabled.boolValue && sizeEnabled.boolValue else { return }

        let visibleFrame = screen.visibleFrame
        let maxGlobalY = NSScreen.screens.map { $0.frame.maxY }.max() ?? visibleFrame.maxY
        
        var targetPosition: CGPoint
        var targetSize: CGSize
        
        switch edge {
        case .top, .bottom:
            // Full maximize for top and bottom edges
            targetPosition = CGPoint(x: visibleFrame.minX, y: maxGlobalY - visibleFrame.maxY)
            targetSize = CGSize(width: visibleFrame.width, height: visibleFrame.height)
            
        case .left:
            // Left half of screen
            targetPosition = CGPoint(x: visibleFrame.minX, y: maxGlobalY - visibleFrame.maxY)
            targetSize = CGSize(width: visibleFrame.width / 2, height: visibleFrame.height)
            
        case .right:
            // Right half of screen
            targetPosition = CGPoint(x: visibleFrame.midX, y: maxGlobalY - visibleFrame.maxY)
            targetSize = CGSize(width: visibleFrame.width / 2, height: visibleFrame.height)
        }
        
        if let positionValue = AXValueCreate(.cgPoint, &targetPosition), 
           let sizeValue = AXValueCreate(.cgSize, &targetSize) {
            let r1 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            let r2 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            NSLog("[MaximizeOnEdge] edge=\(edge.rawValue) set pos=\(r1 == .success) size=\(r2 == .success) position=\(targetPosition) size=\(targetSize)")
        }
    }
    
    private func maximizeWindow(window: AXUIElement, toVisibleFrame visibleFrame: NSRect) {
        var positionEnabled: DarwinBoolean = true
        var sizeEnabled: DarwinBoolean = true
        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &positionEnabled)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeEnabled)
        NSLog("[MaximizeOnEdge] canSet pos=\(positionEnabled.boolValue) size=\(sizeEnabled.boolValue)")
        guard positionEnabled.boolValue && sizeEnabled.boolValue else { return }

        // Convert Cocoa visibleFrame to AX/Quartz top-left coordinates
        let maxGlobalY = NSScreen.screens.map { $0.frame.maxY }.max() ?? (visibleFrame.maxY)
        let topLeftQuartz = CGPoint(x: visibleFrame.minX, y: maxGlobalY - visibleFrame.maxY)

        var pos = topLeftQuartz
        var size = CGSize(width: visibleFrame.size.width, height: visibleFrame.size.height)
        if let positionValue = AXValueCreate(.cgPoint, &pos), let sizeValue = AXValueCreate(.cgSize, &size) {
            let r1 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            let r2 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            NSLog("[MaximizeOnEdge] set pos=\(r1 == .success) size=\(r2 == .success) topLeftQuartz=\(topLeftQuartz) size=\(size)")
        }
    }

    // MARK: - LaunchAgent helpers

    private let launchAgentLabel = "dev.tabe.maximizeonedge"
    private var loginItemMenuItem: NSMenuItem?

    private func launchAgentPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist").path
    }

    private func currentExecutablePath() -> String {
        let path = (Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first) ?? "/usr/bin/true"
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    @objc private func toggleLoginItem() {
        if isLaunchAgentLoaded() { _ = uninstallLaunchAgent() } else { _ = installLaunchAgent() }
        updateLoginItemMenuState()
    }

    private func updateLoginItemMenuState() {
        let enabled = isLaunchAgentLoaded()
        loginItemMenuItem?.state = enabled ? .on : .off
        loginItemMenuItem?.title = "ログイン時に自動起動" + (enabled ? "（有効）" : "（無効）")
    }

    private func installLaunchAgent() -> Bool {
        let plistPath = launchAgentPath()
        let label = launchAgentLabel
        let execPath = currentExecutablePath()
        let dict: [String: Any] = ["Label": label, "ProgramArguments": [execPath], "RunAtLoad": true, "KeepAlive": false]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            let url = URL(fileURLWithPath: plistPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            let uid = getuid()
            _ = runLaunchctl(arguments: ["bootstrap", "gui/\(uid)", plistPath])
            _ = runLaunchctl(arguments: ["enable", "gui/\(uid)/\(label)"])
            NSLog("[MaximizeOnEdge] Installed LaunchAgent at \(plistPath)")
            return true
        } catch {
            NSLog("[MaximizeOnEdge] Failed to install LaunchAgent: \(error)")
            return false
        }
    }

    private func uninstallLaunchAgent() -> Bool {
        let plistPath = launchAgentPath()
        let label = launchAgentLabel
        let uid = getuid()
        _ = runLaunchctl(arguments: ["bootout", "gui/\(uid)/\(label)"])
        do { try FileManager.default.removeItem(atPath: plistPath) } catch { }
        NSLog("[MaximizeOnEdge] Uninstalled LaunchAgent: \(label)")
        return true
    }

    private func isLaunchAgentLoaded() -> Bool {
        let uid = getuid()
        let result = runLaunchctl(arguments: ["print", "gui/\(uid)/\(launchAgentLabel)"])
        return result.exitCode == 0
    }

    @discardableResult
    private func runLaunchctl(arguments: [String]) -> (exitCode: Int32, stdout: String, stderr: String) {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = arguments
        let outPipe = Pipe(); let errPipe = Pipe()
        task.standardOutput = outPipe; task.standardError = errPipe
        do { try task.run() } catch { return (-1, "", "run error: \(error)") }
        task.waitUntilExit()
        let outStr = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (task.terminationStatus, outStr, errStr)
    }

    private func showPreview(on screen: NSScreen) {
        guard isEnabled("showPreview", default: true) else { return }
        
        let point = NSEvent.mouseLocation
        let edge = detectTriggeredEdge(point: point, in: screen.frame)
        
        var frame = screen.visibleFrame
        
        // Adjust preview frame based on edge
        if let edge = edge {
            switch edge {
            case .left:
                frame.size.width = screen.visibleFrame.width / 2
            case .right:
                frame.origin.x = screen.visibleFrame.midX
                frame.size.width = screen.visibleFrame.width / 2
            case .top, .bottom:
                // Full screen for top and bottom
                break
            }
        }
        
        if previewWindow == nil {
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .statusBar
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
            let view = PreviewView(frame: frame)
            window.contentView = view
            previewWindow = window
        }
        previewWindow?.setFrame(frame, display: true)
        previewWindow?.orderFrontRegardless()
    }

    private func hidePreview() { previewWindow?.orderOut(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
