import AppKit

extension NSPasteboard {
    /// 지금 내용을 지우고 문자열 하나만 올린다.
    func copy(_ string: String) {
        clearContents()
        setString(string, forType: .string)
    }
}
