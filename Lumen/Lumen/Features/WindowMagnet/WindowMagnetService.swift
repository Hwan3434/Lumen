import AppKit
import ApplicationServices

final class WindowMagnetService {
    enum Direction {
        case left
        case right
    }

    private var lastDirection: Direction?
    private var lastStepIndex: Int?
    /// 너비 단계는 같은 창에서만 이어 간다. 다른 창으로 옮기면 첫 단계부터.
    private var lastWindow: AXUIElement?

    func snapWindow(direction: Direction) {
        guard let window = getFocusedWindow(), let screen = screen(of: window) else { return }

        let steps = Constants.magnetSteps

        var nextIndex: Int

        if let lastDir = lastDirection, let lastIdx = lastStepIndex, let lastWindow,
           lastDir == direction, CFEqual(lastWindow, window) {
            nextIndex = (lastIdx + 1) % steps.count
        } else {
            nextIndex = 0
        }

        let frame = Self.snapFrame(direction: direction, ratio: steps[nextIndex], on: screen)
        setWindowPosition(window, point: frame.origin)
        setWindowSize(window, size: frame.size)

        lastDirection = direction
        lastStepIndex = nextIndex
        lastWindow = window
    }

    func snapWindowTo(direction: Direction, ratio: CGFloat, targetApp: NSRunningApplication? = nil) {
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
        guard let window, let screen = screen(of: window) else { return }

        let frame = Self.snapFrame(direction: direction, ratio: ratio, on: screen)
        let offscreen = CGPoint(x: -10000, y: -10000)
        setWindowPosition(window, point: offscreen)
        setWindowSize(window, size: frame.size)
        setWindowPosition(window, point: frame.origin)
    }

    private static func snapFrame(direction: Direction, ratio: CGFloat, on screen: NSScreen) -> CGRect {
        snapFrame(direction: direction, ratio: ratio, visibleFrame: screen.visibleFrame,
                  primaryScreenHeight: NSScreen.screens.first?.frame.height ?? screen.frame.height)
    }

    /// 화면 왼쪽이나 오른쪽에 붙인, 너비가 화면의 `ratio`인 창 틀. AX 좌표계(좌상단 원점)다.
    /// AX 좌표의 원점은 주 모니터의 왼쪽 위라서, 세로 뒤집기는 창이 있는 화면이 아니라 주 모니터 높이로 한다.
    static func snapFrame(direction: Direction, ratio: CGFloat, visibleFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let width = visibleFrame.width * ratio
        let x: CGFloat
        switch direction {
        case .left:
            x = visibleFrame.origin.x
        case .right:
            x = visibleFrame.origin.x + visibleFrame.width - width
        }
        return CGRect(x: x, y: primaryScreenHeight - visibleFrame.maxY, width: width, height: visibleFrame.height)
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

    /// 창과 가장 많이 겹치는 화면. `NSScreen.main`은 키 창 기준이라, 모니터가 여럿이면 대상 창과 다른 화면일 수 있다.
    private func screen(of window: AXUIElement) -> NSScreen? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef,
              AXValueGetValue(posRef as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return NSScreen.main }
        // AX 좌표(주 모니터 좌상단 원점)를 AppKit 좌표(좌하단 원점)로 뒤집는다.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let rect = CGRect(x: origin.x, y: primaryHeight - origin.y - size.height, width: size.width, height: size.height)
        let area: (NSScreen) -> CGFloat = { let r = $0.frame.intersection(rect); return r.isNull ? 0 : r.width * r.height }
        return NSScreen.screens.max { area($0) < area($1) } ?? NSScreen.main
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

