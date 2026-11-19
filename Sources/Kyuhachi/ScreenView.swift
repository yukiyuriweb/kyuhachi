import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The PC-98 screen. Takes keyboard focus and sends keys to the emulator;
/// ⌘ shortcuts still reach the app's menus. Clicking captures the mouse for
/// the PC-98; pressing ⌘ releases it.
struct ScreenView: NSViewRepresentable {
    let emulator: Emulator
    let mouseCaptured: Bool
    let aspect: ScreenAspect

    func makeNSView(context: Context) -> ScreenNSView {
        ScreenNSView(emulator: emulator)
    }

    func updateNSView(_ view: ScreenNSView, context: Context) {
        view.setMouseCaptured(mouseCaptured)
        view.aspect = aspect
    }
}

final class ScreenNSView: NSView {
    private let emulator: Emulator
    /// PC-98 keys currently held down, so they can be released on focus loss.
    private var heldKeys: Set<UInt8> = []
    /// Mac keys currently down, with the PC-98 key each one pressed. Several
    /// Mac keys can press the same PC-98 key (`-` and `=` on a US keyboard).
    private var hostKeys: [UInt16: UInt8] = [:]
    /// Mac keys typed as a translated stroke. While any is down, the PC-98
    /// SHIFT follows the stroke, not the Mac's Shift key.
    private var strokes: Set<UInt16> = []
    /// Whether the Mac's Shift key is down.
    private var shiftDown = false
    /// Movement not yet sent because it was less than one PC-98 pixel.
    private var pendingMouse = CGPoint.zero
    /// Whether this view currently holds the cursor (hidden and fixed).
    private var holdsCursor = false

    var aspect: ScreenAspect = .square {
        didSet { if aspect != oldValue { needsLayout = true } }
    }

    /// Where the PC-98 screen is drawn: the largest rectangle of the chosen
    /// shape that fits, centred.
    private var screenRect: CGRect {
        let ratio = aspect.ratio
        var size = bounds.size
        if size.width / max(size.height, 1) > ratio {
            size.width = size.height * ratio
        } else {
            size.height = size.width / ratio
        }
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    init(emulator: Emulator) {
        self.emulator = emulator
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = CGColor.black
        layer?.addSublayer(emulator.screenLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        emulator.screenLayer.frame = screenRect
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
        NotificationCenter.default.removeObserver(self)
        if let window {
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            emulator.mouseCaptured = false
            setMouseCaptured(false)
        }
    }

    override func resignFirstResponder() -> Bool {
        releaseAllKeys()
        emulator.mouseCaptured = false
        return super.resignFirstResponder()
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        releaseAllKeys()
        emulator.mouseCaptured = false
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }
        guard !event.isARepeat else { return }
        let code: UInt8
        if KeyMap.isANSI,
           let stroke = KeyMap.usStroke(for: event.keyCode, shifted: event.modifierFlags.contains(.shift)) {
            press(KeyMap.shift, down: stroke.shift)
            strokes.insert(event.keyCode)
            code = stroke.code
        } else if let plain = KeyMap.pc98Code(for: event.keyCode) {
            // Undo the SHIFT of a translated stroke still held down.
            press(KeyMap.shift, down: shiftDown)
            code = plain
        } else {
            return
        }
        hostKeys[event.keyCode] = code
        if heldKeys.contains(code) {
            // Another Mac key holds this PC-98 key: press it again.
            emulator.key(code, down: false)
            emulator.key(code, down: true)
        } else {
            press(code, down: true)
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let code = hostKeys.removeValue(forKey: event.keyCode) else { return }
        if !hostKeys.values.contains(code) {
            press(code, down: false)
        }
        if strokes.remove(event.keyCode) != nil, strokes.isEmpty {
            press(KeyMap.shift, down: shiftDown)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags
        if flags.contains(.command) {
            emulator.mouseCaptured = false
        }
        switch Int(event.keyCode) {
        case kVK_Shift, kVK_RightShift:
            shiftDown = flags.contains(.shift)
            if strokes.isEmpty {
                press(KeyMap.shift, down: shiftDown)
            }
        case kVK_Control, kVK_RightControl:
            press(KeyMap.ctrl, down: flags.contains(.control))
        case kVK_Option, kVK_RightOption:
            press(KeyMap.grph, down: flags.contains(.option))
        case kVK_CapsLock:
            // CAPS is a locking key on the PC-98 too: held down while on.
            press(KeyMap.caps, down: flags.contains(.capsLock))
        default:
            break
        }
    }

    private func press(_ code: UInt8, down: Bool) {
        if down {
            guard heldKeys.insert(code).inserted else { return }
        } else {
            guard heldKeys.remove(code) != nil else { return }
        }
        emulator.key(code, down: down)
    }

    private func releaseAllKeys() {
        for code in heldKeys where code != KeyMap.caps {
            emulator.key(code, down: false)
        }
        heldKeys = heldKeys.intersection([KeyMap.caps])
        hostKeys = [:]
        strokes = []
        shiftDown = false
    }

    // MARK: Mouse

    func setMouseCaptured(_ captured: Bool) {
        guard captured != holdsCursor else { return }
        holdsCursor = captured
        if captured {
            window?.makeFirstResponder(self)
            // Park the cursor in the middle of the screen so clicks land here.
            if let window, let screen = window.screen {
                let inWindow = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
                let onScreen = window.convertPoint(toScreen: inWindow)
                CGWarpMouseCursorPosition(CGPoint(x: onScreen.x, y: screen.frame.maxY - onScreen.y))
            }
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
            pendingMouse = .zero
        } else {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            emulator.setMouseButton(left: false, right: false)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if emulator.mouseCaptured {
            emulator.setMouseButton(left: true)
        } else {
            emulator.mouseCaptured = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        if emulator.mouseCaptured {
            emulator.setMouseButton(left: false)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if emulator.mouseCaptured {
            emulator.setMouseButton(right: true)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        if emulator.mouseCaptured {
            emulator.setMouseButton(right: false)
        }
    }

    override func mouseMoved(with event: NSEvent) { move(event) }
    override func mouseDragged(with event: NSEvent) { move(event) }
    override func rightMouseDragged(with event: NSEvent) { move(event) }

    /// Converts movement in view points to PC-98 screen pixels (640 wide).
    private func move(_ event: NSEvent) {
        guard emulator.mouseCaptured else { return }
        let shown = screenRect.size
        guard shown.width > 0, shown.height > 0 else { return }
        pendingMouse.x += event.deltaX * 640 / shown.width
        pendingMouse.y += event.deltaY * 400 / shown.height
        let dx = Int(pendingMouse.x), dy = Int(pendingMouse.y)
        guard dx != 0 || dy != 0 else { return }
        pendingMouse.x -= CGFloat(dx)
        pendingMouse.y -= CGFloat(dy)
        emulator.moveMouse(dx: dx, dy: dy)
    }
}
