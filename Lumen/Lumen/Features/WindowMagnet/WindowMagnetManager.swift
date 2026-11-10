import AppKit
import ApplicationServices

final class WindowMagnetManager {
    enum Direction {
        case left
        case right
    }

    private var lastDirection: Direction?
    private var lastStepIndex: Int?

    func snapWindow(direction: Direction) {
        guard let screen = NSScreen.main else { return }
        guard let window = getFocusedWindow() else { return }

        let steps = Constants.magnetSteps

        var nextIndex: Int

        if let lastDir = lastDirection, let lastIdx = lastStepIndex,
           lastDir == direction {
            nextIndex = (lastIdx + 1) % steps.count
        } else {
            nextIndex = 0
        }

        let frame = snapFrame(direction: direction, ratio: steps[nextIndex], on: screen)
        setWindowPosition(window, point: frame.origin)
        setWindowSize(window, size: frame.size)

        lastDirection = direction
        lastStepIndex = nextIndex
    }

    func snapWindowTo(direction: Direction, ratio: CGFloat, targetApp: NSRunningApplication? = nil) {
        guard let screen = NSScreen.main else { return }

        // 지정된 앱 또는 현재 포커스 윈도우
        let window: AXUIElement?
        if let app = targetApp {
            // focusedWindow 먼저 시도, 실패하면 windows 배열의 첫 번째
            if let focused = focusedWindow(of: app) {
                window = focused
            } else {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                var windowsRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                      let windows = windowsRef as? [AXUIElement],
                      let first = windows.first else { return }
                window = first
            }
        } else {
            window = getFocusedWindow()
        }
        guard let window = window else { return }

        let frame = snapFrame(direction: direction, ratio: ratio, on: screen)
        let offscreen = CGPoint(x: -10000, y: -10000)
        setWindowPosition(window, point: offscreen)
        setWindowSize(window, size: frame.size)
        setWindowPosition(window, point: frame.origin)
    }

    /// 화면 왼쪽이나 오른쪽에 붙인, 너비가 화면의 `ratio`인 창 틀. AX 좌표계(좌상단 원점)다.
    private func snapFrame(direction: Direction, ratio: CGFloat, on screen: NSScreen) -> CGRect {
        let screenFrame = screen.visibleFrame
        let width = screenFrame.width * ratio
        let x: CGFloat
        switch direction {
        case .left:
            x = screenFrame.origin.x
        case .right:
            x = screenFrame.origin.x + screenFrame.width - width
        }
        return CGRect(x: x, y: screen.frame.height - screenFrame.maxY, width: width, height: screenFrame.height)
    }

    // MARK: - AXUIElement

    private func getFocusedWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        return focusedWindow(of: frontApp)
    }

    private func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let ref = windowRef,
              CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            return nil
        }
        return (ref as! AXUIElement)
    }

    private func setWindowPosition(_ window: AXUIElement, point: CGPoint) {
        var p = point
        guard let axValue = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue)
    }

    private func setWindowSize(_ window: AXUIElement, size: CGSize) {
        var s = size
        guard let axValue = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue)
    }
}

