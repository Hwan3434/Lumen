import Foundation

/// `pmset disablesleep` — 덮개를 닫거나 Apple 메뉴에서 잠자기를 눌러도 시스템이 잠들지 않게 하는
/// **시스템 전역 설정**을 다룬다. 이 값은 root 권한이 필요하고 재부팅 뒤에도 남는다.
///
/// 매번 비밀번호를 묻지 않도록, 최초 1회만 관리자 권한으로 `/etc/sudoers.d/lumen`에
/// `pmset -a disablesleep 0` / `pmset -a disablesleep 1` **두 명령만** 비밀번호 없이 허용하는
/// 규칙을 설치한다. 이후 토글은 `sudo -n`(비대화형)으로 실행한다.
///
/// 모든 함수는 외부 프로세스를 동기로 기다린다. UI에서는 `offMain`으로 감싸 부르고,
/// 앱 종료 직전 복구처럼 반드시 끝까지 실행돼야 하는 경우에만 직접 부른다.
nonisolated enum SleepPolicyService {
    static let sudoersPath = "/private/etc/sudoers.d/lumen"
    private static let pmsetPath = "/usr/bin/pmset"
    private static let sudoPath = "/usr/bin/sudo"

    enum Failure: LocalizedError {
        case invalidUserName
        case cancelled
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidUserName:         return "사용자 이름을 sudoers 규칙에 쓸 수 없어요."
            case .cancelled:               return "취소했어요."
            case .commandFailed(let msg):  return msg.isEmpty ? "명령을 실행하지 못했어요." : msg
            }
        }
    }

    // MARK: - 상태 읽기 (root 불필요)

    /// 시스템에 `SleepDisabled = 1`이 걸려 있는지. `pmset` 실행에 실패하면 nil.
    static func isSleepDisabled() -> Bool? {
        guard let out = run(pmsetPath, ["-g"]), out.status == 0 else { return nil }
        return parseSleepDisabled(out.stdout)
    }

    /// `pmset -g` 출력에서 `SleepDisabled` 줄을 읽는다. 줄이 없으면 기본값(잠자기 허용)으로 본다.
    static func parseSleepDisabled(_ output: String) -> Bool {
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: \.isWhitespace)
            if parts.count >= 2, parts[0] == "SleepDisabled" {
                return parts[1] == "1"
            }
        }
        return false
    }

    /// 규칙 파일이 있고, sudo가 실제로 비밀번호 없이 허용하는지까지 확인한다.
    /// (`/etc/sudoers`에 `#includedir`가 빠진 환경이면 파일이 있어도 false.)
    static func isRuleInstalled() -> Bool {
        guard FileManager.default.fileExists(atPath: sudoersPath) else { return false }
        return run(sudoPath, ["-n", "-l", pmsetPath, "-a", "disablesleep", "1"])?.status == 0
    }

    // MARK: - 토글 (규칙 필요, 비밀번호 없음)

    static func setSleepDisabled(_ disabled: Bool) throws {
        let out = run(sudoPath, ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"])
        guard let out, out.status == 0 else {
            throw Failure.commandFailed(out?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        }
    }

    // MARK: - 규칙 설치·제거 (관리자 비밀번호 1회)

    /// sudoers 규칙 본문. 사용자 이름이 sudoers 문법을 깨뜨릴 수 있는 문자를 포함하면 nil.
    static func sudoersRule(for userName: String) -> [String]? {
        guard isSafeUserName(userName) else { return nil }
        return [
            // sudoers 파일이라 주석도 ASCII로만 쓴다.
            "# Added by Lumen (lid-closed awake mode). Remove from Lumen Settings > Power.",
            "\(userName) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 0, \(pmsetPath) -a disablesleep 1",
        ]
    }

    static func isSafeUserName(_ name: String) -> Bool {
        guard let first = name.first, first != "-", first != "." else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == ".") }
    }

    /// 관리자 비밀번호를 받아 규칙을 설치한다.
    ///
    /// 규칙 내용은 사용자 쓰기 가능한 임시 파일을 거치지 않고 root 셸 안에서 직접 쓴다 —
    /// 검사(visudo)와 설치 사이에 다른 프로세스가 파일을 바꿔치기할 틈을 없애기 위해서다.
    /// 임시 파일 이름이 `.`으로 시작하면 sudo의 includedir이 무시하므로, 검사 전에 반쯤 쓰인
    /// 파일이 적용될 일도 없다.
    static func installRule() throws {
        guard let lines = sudoersRule(for: NSUserName()) else { throw Failure.invalidUserName }
        let dir = (sudoersPath as NSString).deletingLastPathComponent
        let quotedLines = lines.map(shellQuoted).joined(separator: " ")
        let script = [
            "/bin/mkdir -p \(dir)",
            "T=$(/usr/bin/mktemp \(dir)/.lumen.XXXXXX)",
            "/usr/bin/printf '%s\\n' \(quotedLines) > \"$T\"",
            "/usr/sbin/visudo -cf \"$T\" >/dev/null",
            "/usr/sbin/chown root:wheel \"$T\"",
            "/bin/chmod 0440 \"$T\"",
            "/bin/mv -f \"$T\" \(sudoersPath)",
        ].joined(separator: " && ") + " || { /bin/rm -f \"$T\"; exit 1; }"

        try runAsAdministrator(script, prompt: "Lumen이 잠자기 설정 권한을 추가하려고 해요.")
        guard isRuleInstalled() else {
            throw Failure.commandFailed("규칙을 설치했지만 sudo가 인식하지 않아요. /etc/sudoers의 #includedir 설정을 확인해 주세요.")
        }
    }

    /// 관리자 비밀번호를 받아 잠자기를 원래대로 돌리고 규칙을 지운다.
    static func removeRule() throws {
        let script = "\(pmsetPath) -a disablesleep 0; /bin/rm -f \(sudoersPath)"
        try runAsAdministrator(script, prompt: "Lumen이 추가한 잠자기 설정 권한을 지우려고 해요.")
    }

    // MARK: - 실행 도우미

    /// 동기 작업을 메인 액터 밖에서 실행한다.
    static func offMain<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    private static func runAsAdministrator(_ shellScript: String, prompt: String) throws {
        let source = "do shell script \(appleScriptQuoted(shellScript)) with prompt \(appleScriptQuoted(prompt)) with administrator privileges"
        guard let out = run("/usr/bin/osascript", ["-e", source]) else {
            throw Failure.commandFailed("osascript를 실행하지 못했어요.")
        }
        guard out.status == 0 else {
            // -128: 사용자가 비밀번호 창에서 취소.
            if out.stderr.contains("-128") { throw Failure.cancelled }
            throw Failure.commandFailed(out.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private struct Output {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private static func run(_ path: String, _ arguments: [String]) -> Output? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        // 출력이 작아 파이프 버퍼가 찰 일은 없다 — 순서대로 끝까지 읽고 종료를 기다린다.
        let out = stdout.fileHandleForReading.readDataToEndOfFile()
        let err = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(
            status: process.terminationStatus,
            stdout: String(decoding: out, as: UTF8.self),
            stderr: String(decoding: err, as: UTF8.self)
        )
    }
}
