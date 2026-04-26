import Foundation

extension Constants {
    /// bundleID → 검색 키워드. "Code"가 실제 이름인 VSCode를 "vscode"로 검색 가능하게 하는 등의 용도.
    static let appAliases: [String: [String]] = [
        "com.microsoft.VSCode":         ["vscode", "vs code"],
        "com.microsoft.VSCodeInsiders": ["vscode insiders", "vs code insiders"],
        "com.apple.finder":             ["finder", "파인더"],
        "com.apple.Terminal":           ["terminal", "터미널"],
        "com.googlecode.iterm2":        ["iterm"],
        "com.apple.dt.Xcode":           ["xcode"],
        "com.tinyspeck.slackmacgap":    ["slack", "슬랙"],
        "com.apple.Safari":             ["safari", "사파리"],
        "com.google.Chrome":            ["chrome", "크롬"],
        "company.thebrowser.Browser":   ["arc", "아크"],
        "com.apple.Notes":              ["notes", "메모"],
        "notion.id":                    ["notion", "노션"],
    ]
}
