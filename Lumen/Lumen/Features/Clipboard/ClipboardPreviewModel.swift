import AppKit

/// 미리보기 칸에 그릴 내용. 뷰는 이 값을 그리기만 한다.
/// 파일 크기 읽기나 이미지 열기 같은 디스크 접근을 뷰의 body 밖으로 빼려고 만든 값이라,
/// `ClipboardViewModel`이 선택한 항목마다 한 번만 만든다.
struct ClipboardPreviewModel {
    struct MetaRow {
        let key: String
        let value: String
        let mono: Bool
    }

    /// 본문은 이 글자 수까지만 보여 준다.
    static let textLimit = 500

    let id: UUID
    let title: String
    let subtitle: String
    let sourceAppIcon: NSImage?
    let image: NSImage?
    let fileURLs: [URL]
    let text: String?
    let metaRows: [MetaRow]

    init(item: ClipboardItem) {
        id = item.id
        title = item.displayText.split(separator: "\n").first.map(String.init) ?? item.displayText
        subtitle = "\(item.sourceApp ?? "알 수 없는 앱") · \(LumenDateFormat.time.string(from: item.date))"
        sourceAppIcon = item.sourceAppIcon
        fileURLs = item.fileURLs ?? []

        let copiedImage = item.resolvedImage
        image = copiedImage ?? Self.fileImage(fileURLs.first)

        let textCount = item.text?.count ?? 0
        if let text = item.text, !text.isEmpty {
            self.text = textCount > Self.textLimit ? String(text.prefix(Self.textLimit)) + "…" : text
        } else {
            self.text = nil
        }

        var rows: [MetaRow] = []
        if let app = item.sourceApp {
            rows.append(.init(key: "복사한 앱", value: app, mono: false))
        }
        rows.append(.init(key: "복사 시간", value: Self.fullTime(item.date), mono: true))

        if item.text != nil {
            let limitNote = textCount > Self.textLimit ? " (\(Self.textLimit)자만 표시)" : ""
            rows.append(.init(key: "글자 수", value: "\(textCount.formatted())자\(limitNote)", mono: true))
            rows.append(.init(key: "종류", value: "텍스트", mono: false))
        }

        if fileURLs.count == 1, let url = fileURLs.first {
            rows.append(.init(key: "경로", value: Self.shortPath(url), mono: true))
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                if let size = attrs[.size] as? Int64 {
                    rows.append(.init(key: "크기", value: Self.byteCount(size), mono: true))
                }
                if let date = attrs[.modificationDate] as? Date {
                    rows.append(.init(key: "수정 시각", value: Self.fullTime(date), mono: true))
                }
            }
        } else if fileURLs.count > 1 {
            rows.append(.init(key: "항목 수", value: "\(fileURLs.count)개", mono: false))
            let total = fileURLs.compactMap { url -> Int64? in
                try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
            }.reduce(Int64(0), +)
            if total > 0 {
                rows.append(.init(key: "총 크기", value: Self.byteCount(total), mono: true))
            }
        }

        if let copiedImage {
            rows.append(.init(key: "이미지 크기",
                              value: "\(Int(copiedImage.size.width)) × \(Int(copiedImage.size.height))",
                              mono: true))
        }
        metaRows = rows
    }

    /// 복사한 파일이 이미지면 그 그림을 보여 준다.
    private static func fileImage(_ url: URL?) -> NSImage? {
        guard let url else { return nil }
        let exts = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
        guard exts.contains(url.pathExtension.lowercased()) else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func fullTime(_ date: Date) -> String {
        LumenTime.relative(date, granularity: .calendar)
    }

    private static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func shortPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
