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
        variableLength: Bool = false,
        menu: NSMenu? = nil,
        onClick: (() -> Void)? = nil
    ) -> StatusBarItemHandle {
        let handle = StatusBarItemHandle(
            symbolName: symbolName,
            accessibility: accessibility,
            variableLength: variableLength,
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
    private let variableLength: Bool
    private var titleText: String = ""
    private let menu: NSMenu?
    private var onClick: (() -> Void)?

    fileprivate init(symbolName: String, accessibility: String?, variableLength: Bool, menu: NSMenu?, onClick: (() -> Void)?) {
        self.symbolName = symbolName
        self.accessibility = accessibility
        self.variableLength = variableLength
        self.menu = menu
        self.onClick = onClick
        super.init()
    }

    var isVisible: Bool { statusItem != nil }

    /// status item의 button view에 직접 접근할 때 — popover anchor 등으로 쓰임.
    var buttonView: NSView? { statusItem?.button }

    func show() {
        guard statusItem == nil else { return }
        let length = variableLength ? NSStatusItem.variableLength : NSStatusItem.squareLength
        let item = NSStatusBar.system.statusItem(withLength: length)
        applyIcon(to: item)
        applyTitle(to: item)
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

    func updateTitle(_ title: String) {
        self.titleText = title
        if let item = statusItem { applyTitle(to: item) }
    }

    /// init 시점엔 self 미완성이라 onClick 안에서 self.handle을 못 잡으므로,
    /// init 후 setOnClick으로 교체할 수 있게 한다.
    func setOnClick(_ handler: @escaping () -> Void) {
        self.onClick = handler
        guard let item = statusItem, item.menu == nil else { return }
        item.button?.action = #selector(handleClick(_:))
        item.button?.target = self
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
        item.button?.imagePosition = titleText.isEmpty ? .imageOnly : .imageLeft
    }

    private func applyTitle(to item: NSStatusItem) {
        // NSStatusBarButton은 image와 title 사이 spacing을 제공하지 않아
        // 라벨 앞에 공백을 두 칸 추가해 시각적 간격을 만든다.
        item.button?.title = titleText.isEmpty ? "" : "  \(titleText)"
        item.button?.imagePosition = titleText.isEmpty ? .imageOnly : .imageLeft
    }

    @objc private func handleClick(_ sender: Any?) {
        onClick?()
    }
}
