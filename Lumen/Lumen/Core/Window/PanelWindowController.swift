import AppKit
import SwiftUI

/// KeyablePanel 기반 floating window controller의 공통 base class.
/// 생명주기(show/hide), 스페이스 전환 감지, 이전 앱 복귀 제어를 담당한다.
/// Subclass는 `createPanel()`을 override하고 필요 시 hook을 구현한다.
class PanelWindowController: NSObject {
    /// 모든 인스턴스가 init 시 자동 등록된다. focusTopVisible()이 이 목록을 순회한다.
    private static let registry = NSHashTable<PanelWindowController>.weakObjects()

    var panel: KeyablePanel?

    private var spaceObserver: Any?
    /// 패널이 열린 뒤 스페이스가 바뀌었으면 hide 시 이전 앱 activate 금지
    /// (그렇지 않으면 다른 스페이스에서 닫을 때 이전 스페이스로 딸려감).
    private var spaceChangedSinceShow = false

    override init() {
        super.init()
        Self.registry.add(self)
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.panel?.isVisible == true else { return }
            self.spaceChangedSinceShow = true
            self.panel?.activatePreviousAppOnClose = false
        }
    }

    deinit {
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    /// 현재 visible한 패널 중 z-order 기준 최상단으로 키보드 포커스 복귀. 없으면 no-op.
    static func focusTopVisible() {
        let controllers = registry.allObjects
        for window in NSApp.orderedWindows where window is KeyablePanel && window.isVisible {
            if let controller = controllers.first(where: { $0.panel === window }) {
                NSApp.activate()
                controller.panel?.makeKeyAndOrderFront(nil)
                return
            }
        }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        let isFirstShow = panel == nil
        if isFirstShow {
            let p = createPanel()
            self.panel = p
            didCreatePanel(p)
        }
        guard let panel else { return }

        spaceChangedSinceShow = false
        panel.activatePreviousAppOnClose = true
        panel.previousApp = NSWorkspace.shared.frontmostApplication

        configureBeforeShow(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        didShow(panel)
    }

    func hide(activatePreviousApp: Bool = true) {
        willHide()
        let shouldActivate = activatePreviousApp && !spaceChangedSinceShow
        panel?.activatePreviousAppOnClose = shouldActivate
        panel?.orderOut(nil)
        panel?.activatePreviousAppOnClose = true
    }

    // MARK: - Subclass interface

    /// 최초 show 시 1회 호출 — panel 생성 및 설정을 구현한다.
    func createPanel() -> KeyablePanel {
        fatalError("Subclass must override createPanel()")
    }

    /// panel 생성 직후 1회 호출 — 초기 위치 지정 등 1회성 설정.
    func didCreatePanel(_ panel: KeyablePanel) {}

    /// 매 show마다 makeKeyAndOrderFront 직전에 호출 — 매번 재설정이 필요한 상태.
    func configureBeforeShow(_ panel: KeyablePanel) {}

    /// 매 show마다 activate 직후에 호출 — event monitor 등록 등.
    func didShow(_ panel: KeyablePanel) {}

    /// 매 hide마다 orderOut 직전에 호출 — event monitor 해제 등.
    func willHide() {}
}
