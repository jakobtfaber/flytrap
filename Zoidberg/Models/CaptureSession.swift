import Foundation

struct CaptureSession: Codable {
    private(set) var items: [CaptureItem] = []
    let createdAt: Date

    var isEmpty: Bool { items.isEmpty }

    init() {
        self.createdAt = Date()
    }

    mutating func addItem(_ item: CaptureItem) {
        items.append(item)
    }

    mutating func removeItem(_ item: CaptureItem) {
        items.removeAll { $0 == item }
    }

    mutating func clear() {
        items.removeAll()
    }

    var allMediaFiles: [(filename: String, sourcePath: String)] {
        items.compactMap { $0.mediaFiles }.flatMap { $0 }
    }

    /// Markdown for a single capture entry (## time heading + content).
    func toMarkdown(title: String?) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        let timeString = timeFmt.string(from: createdAt)

        var lines: [String] = []
        lines.append("## \(title ?? timeString)")
        lines.append("")

        for item in items {
            lines.append(item.toMarkdown())
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// Top-level date heading for the daily file.
    func dailyHeading() -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        return "# \(dateFmt.string(from: createdAt))"
    }

    /// One file per day: YYYY-MM-DD.md
    func fallbackFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: createdAt)).md"
    }
}
