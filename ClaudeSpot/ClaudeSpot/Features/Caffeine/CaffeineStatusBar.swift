import AppKit

final class CaffeineStatusBar {
    private var statusItem: NSStatusItem?

    var onClick: (() -> Void)?

    func show(isActive: Bool) {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem?.button?.action = #selector(handleClick)
            statusItem?.button?.target = self
        }
        updateIcon(isActive: isActive)
    }

    func updateIcon(isActive: Bool) {
        let symbolName = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "카페인")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    func remove() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    @objc private func handleClick() {
        onClick?()
    }
}
