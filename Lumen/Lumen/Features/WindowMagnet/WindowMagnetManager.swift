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
        let screenFrame = screen.visibleFrame

        guard let window = getFocusedWindow() else { return }

        let steps = Constants.magnetSteps

        var nextIndex: Int

        if let lastDir = lastDirection, let lastIdx = lastStepIndex,
           lastDir == direction {
            nextIndex = (lastIdx + 1) % steps.count
        } else {
            nextIndex = 0
        }

        let ratio = steps[nextIndex]
        let newWidth = screenFrame.width * ratio
        let newHeight = screenFrame.height

        // AX 좌표계: 좌상단 원점
        let screenTop = screen.frame.height - screenFrame.maxY
        let newX: CGFloat
        switch direction {
        case .left:
            newX = screenFrame.origin.x
        case .right:
            newX = screenFrame.origin.x + screenFrame.width - newWidth
        }

        setWindowPosition(window, point: CGPoint(x: newX, y: screenTop))
        setWindowSize(window, size: CGSize(width: newWidth, height: newHeight))

        lastDirection = direction
        lastStepIndex = nextIndex
    }

    func snapWindowTo(direction: Direction, ratio: CGFloat, targetApp: NSRunningApplication? = nil) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // 지정된 앱 또는 현재 포커스 윈도우
        let window: AXUIElement?
        if let app = targetApp {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            // focusedWindow 먼저 시도, 실패하면 windows 배열의 첫 번째
            var windowRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success {
                // swiftlint:disable:next force_cast
                window = (windowRef as! AXUIElement)
            } else {
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

        let newWidth = screenFrame.width * ratio
        let newHeight = screenFrame.height
        let screenTop = screen.frame.height - screenFrame.maxY
        let newX: CGFloat
        switch direction {
        case .left:
            newX = screenFrame.origin.x
        case .right:
            newX = screenFrame.origin.x + screenFrame.width - newWidth
        }

        let offscreen = CGPoint(x: -10000, y: -10000)
        setWindowPosition(window, point: offscreen)
        setWindowSize(window, size: CGSize(width: newWidth, height: newHeight))
        setWindowPosition(window, point: CGPoint(x: newX, y: screenTop))
    }

    // MARK: - AXUIElement

    private func getFocusedWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success else {
            return nil
        }
        // swiftlint:disable:next force_cast
        return (windowRef as! AXUIElement)
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

