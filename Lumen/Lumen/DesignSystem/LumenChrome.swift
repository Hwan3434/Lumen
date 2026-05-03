import SwiftUI
import AppKit

// MARK: - Window drag handle
//
// `.nonactivatingPanel` 스타일의 NSPanel은 `isMovableByWindowBackground = true`로도 안 움직여
// (`kCGSPreventsActivationTagBit` 이슈), `mouseDown(with:)`이 자기에게 직접 와서 `performDrag`를
// 불러야 AppKit drag tracking이 시작된다. 헤더 같은 특정 영역에만 깔아 그 영역에서만 윈도우 이동.
// SwiftUI `.overlay`로 깔고, 자식 hit-test가 우선해야 하는 인터랙티브 요소(버튼 등)는 ZStack 위에 둔다.

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override var mouseDownCanMoveWindow: Bool { true }
    }
}

// MARK: - Relative time formatting (한국어 단축 표기)

enum LumenTime {
    enum Granularity {
        /// "방금" / "N분 전" / "N시간 전" — 시간 단위에서 멈춤. Jira 헤더 톤.
        case minutesAndHours
        /// "방금" / "N분" / "N시간" / "어제" / "N일" — 접미사 "전" 없음. 클립보드/번역 히스토리 톤.
        case shortNoSuffix
        /// "오늘 HH:mm" / "어제 HH:mm" / "M월 d일 HH:mm" — 절대 시간을 한국어 prefix로 감쌈. 클립보드 메타 톤.
        case calendar
    }

    static func relative(_ date: Date, granularity: Granularity = .minutesAndHours) -> String {
        switch granularity {
        case .minutesAndHours:   return minutesAndHours(date)
        case .shortNoSuffix:     return shortNoSuffix(date)
        case .calendar:          return calendar(date)
        }
    }

    private static func minutesAndHours(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "방금" }
        if mins < 60 { return "\(mins)분 전" }
        return "\(mins / 60)시간 전"
    }

    private static func shortNoSuffix(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "방금" }
        if interval < 3600 { return "\(Int(interval / 60))분" }
        if interval < 86400 { return "\(Int(interval / 3600))시간" }
        let days = Int(interval / 86400)
        if days == 1 { return "어제" }
        return "\(days)일"
    }

    private static let calendarFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    private static func calendar(_ date: Date) -> String {
        let cal = Calendar.current
        let f = calendarFormatter
        if cal.isDateInToday(date)         { f.dateFormat = "오늘 HH:mm" }
        else if cal.isDateInYesterday(date){ f.dateFormat = "어제 HH:mm" }
        else                               { f.dateFormat = "M월 d일 HH:mm" }
        return f.string(from: date)
    }
}

// MARK: - Shared date formatters (per-render allocation 회피)

enum LumenDateFormat {
    /// "MM/dd" — 짧은 날짜. due-date / sprint range / chart x-tick.
    static let monthDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd"; return f
    }()
    /// "dd" — 같은 달 내 끝일만 표기.
    static let dayOnly: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd"; return f
    }()
}

// MARK: - LumenFooterBar
//
// 검색·번역·메모·클립보드 패널이 공유하는 32pt 하단 chrome.
// 좌측: 보라→앰버 그라데이션 브랜드 마크 + "Lumen". 우측: 액션 + kbd 힌트.

struct LumenFooterAction: Identifiable {
    let id = UUID()
    let label: String
    let kbd: String
    var primary: Bool = false
}

struct LumenFooterBar: View {
    let actions: [LumenFooterAction]

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                LinearGradient(
                    colors: [LumenTokens.Accent.violetSoft, LumenTokens.Accent.amber],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Lumen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LumenTokens.TextColor.muted)
            }
            Spacer()
            HStack(spacing: 14) {
                ForEach(actions) { action in
                    HStack(spacing: 5) {
                        Text(action.label)
                            .font(.system(size: 11, weight: action.primary ? .medium : .regular))
                            .foregroundStyle(action.primary ? LumenTokens.TextColor.primary
                                                            : LumenTokens.TextColor.muted)
                        LumenKbd(label: action.kbd, primary: action.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(LumenTokens.BG.footer)
        .overlay(alignment: .top) {
            Rectangle().fill(LumenTokens.divider).frame(height: 0.5)
        }
    }
}
