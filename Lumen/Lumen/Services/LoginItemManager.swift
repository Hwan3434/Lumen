import ServiceManagement

enum LoginItemManager {
    /// 시스템 설정 > 로그인 항목에서 끈 경우도 따라가도록 시스템 상태를 그대로 읽는다.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
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
            if SMAppService.mainApp.status == .requiresApproval {
                LumenToast.show(text: "시스템 설정 > 로그인 항목에서 Lumen을 허용해 주세요", duration: 4)
            }
        } catch {
            LumenToast.show(text: "로그인 시 시작을 켜지 못했어요: \(error.localizedDescription)", duration: 4)
        }
    }

    static func disable() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            LumenToast.show(text: "로그인 시 시작을 끄지 못했어요: \(error.localizedDescription)", duration: 4)
        }
    }
}
