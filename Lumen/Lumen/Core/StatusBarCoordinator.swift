import AppKit

/// Feature가 자기 NSStatusItem을 직접 만들지 않고 coordinator에게 등록을 요청한다.
/// coordinator는 NSStatusItem 라이프사이클(생성·아이콘·메뉴·해제)을 책임지며,
/// 앱 종료 시 한 번에 정리한다.
@MainActor
final class StatusBarCoordinator {
    private var items: [StatusBarItemHandle] = []

    /// 새 status item을 등록. visible=false면 등록만 하고 메뉴바엔 안 띄운다 — feature가
    /// 나중에 handle.show()로 띄움. onClick 또는 menu 중 하나를 줄 수 있다.
    func addItem(
        initialIcon symbolName: String,
        accessibility: String? = nil,
        visible: Bool = true,
        menu: NSMenu? = nil,
        onClick: (() -> Void)? = nil
    ) -> StatusBarItemHandle {
        let handle = StatusBarItemHandle(
            symbolName: symbolName,
            accessibility: accessibility,
            menu: menu,
            onClick: onClick
        )
        if visible { handle.show() }
        items.append(handle)
        return handle
    }

    /// 앱 종료 직전 호출. 모든 status item을 제거.
    func teardownAll() {
        for h in items { h.remove() }
        items.removeAll()
    }
}

/// Coordinator가 등록한 NSStatusItem 한 개에 대한 인터페이스.
/// feature가 이 핸들로 아이콘/visible을 갱신.
@MainActor
final class StatusBarItemHandle: NSObject {
    private var statusItem: NSStatusItem?
    private var symbolName: String
    private let accessibility: String?
    private let menu: NSMenu?
    private let onClick: (() -> Void)?

    fileprivate init(symbolName: String, accessibility: String?, menu: NSMenu?, onClick: (() -> Void)?) {
        self.symbolName = symbolName
        self.accessibility = accessibility
        self.menu = menu
        self.onClick = onClick
        super.init()
    }

    var isVisible: Bool { statusItem != nil }

    func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        applyIcon(to: item)
        if let menu {
            item.menu = menu
        } else if onClick != nil {
            item.button?.action = #selector(handleClick(_:))
            item.button?.target = self
        }
        statusItem = item
    }

    func updateIcon(_ symbolName: String) {
        self.symbolName = symbolName
        if let item = statusItem { applyIcon(to: item) }
    }

    func hide() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    fileprivate func remove() {
        hide()
    }

    private func applyIcon(to item: NSStatusItem) {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibility)
        image?.isTemplate = true
        item.button?.image = image
    }

    @objc private func handleClick(_ sender: Any?) {
        onClick?()
    }
}
