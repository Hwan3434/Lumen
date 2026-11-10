/// `Constants`는 namespace 역할만 한다. 실제 값은 도메인별 파일에서
/// `extension Constants`로 채운다:
///   - Core/Hotkeys/HotkeyDefinitions.swift  (KeyCode + 핫키 코드/모디파이어)
///   - Helpers/WindowMetrics.swift            (각 패널의 기본 사이즈)
///   - Features/WindowMagnet/MagnetConfig.swift (스냅 단계)
///   - Search/AppAliasMap.swift                 (앱 검색 alias 사전)
enum Constants {}
