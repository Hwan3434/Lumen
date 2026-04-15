import ServiceManagement

enum LoginItemManager {
    private static let key = "launchAtLogin"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    static func enable() {
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            print("Login item register failed: \(error)")
        }
    }

    static func disable() {
        do {
            try SMAppService.mainApp.unregister()
            UserDefaults.standard.set(false, forKey: key)
        } catch {
            print("Login item unregister failed: \(error)")
        }
    }
}
