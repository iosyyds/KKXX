import Foundation

func nowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}

/// 可同步数据模型的公共协议：所有实体都带时间戳与软删除标记
protocol Syncable: Identifiable, Codable, Hashable {
    var updatedAt: Int64 { get set }
    var deleted: Bool { get set }
}

struct Note: Syncable {
    var id: String
    var title: String
    var content: String
    var images: [String]   // base64 data URI 列表
    var tags: [String]
    var createdAt: Int64
    var updatedAt: Int64
    var deleted: Bool

    init(id: String = UUID().uuidString,
         title: String = "",
         content: String = "",
         images: [String] = [],
         tags: [String] = [],
         createdAt: Int64 = nowMs(),
         updatedAt: Int64 = nowMs(),
         deleted: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.images = images
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deleted = deleted
    }
}

struct TodoItem: Syncable {
    var id: String
    var title: String
    var done: Bool
    var dueDate: Int64      // 截止时间戳（毫秒），0 表示无截止
    var tags: [String]
    var createdAt: Int64
    var updatedAt: Int64
    var deleted: Bool

    init(id: String = UUID().uuidString,
         title: String = "",
         done: Bool = false,
         dueDate: Int64 = 0,
         tags: [String] = [],
         createdAt: Int64 = nowMs(),
         updatedAt: Int64 = nowMs(),
         deleted: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
        self.dueDate = dueDate
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deleted = deleted
    }
}

struct Bill: Syncable {
    var id: String
    var type: String        // "income" / "expense"
    var amount: Double
    var category: String
    var remark: String
    var billDate: Int64
    var createdAt: Int64
    var updatedAt: Int64
    var deleted: Bool

    init(id: String = UUID().uuidString,
         type: String = "expense",
         amount: Double = 0,
         category: String = "",
         remark: String = "",
         billDate: Int64 = nowMs(),
         createdAt: Int64 = nowMs(),
         updatedAt: Int64 = nowMs(),
         deleted: Bool = false) {
        self.id = id
        self.type = type
        self.amount = amount
        self.category = category
        self.remark = remark
        self.billDate = billDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deleted = deleted
    }
}

struct Checkin: Syncable {
    var id: String
    var date: String        // yyyy-MM-dd
    var note: String
    var createdAt: Int64
    var updatedAt: Int64
    var deleted: Bool

    init(id: String = UUID().uuidString,
         date: String,
         note: String = "",
         createdAt: Int64 = nowMs(),
         updatedAt: Int64 = nowMs(),
         deleted: Bool = false) {
        self.id = id
        self.date = date
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deleted = deleted
    }
}

// MARK: - 展示辅助

extension Note {
    var snippet: String {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "（无内容）" : String(t.prefix(60))
    }
}

func shortDate(_ ms: Int64) -> String {
    guard ms > 0 else { return "" }
    let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    return d.formatted(.dateTime.year().month().day())
}

func shortTime(_ ms: Int64) -> String {
    guard ms > 0 else { return "从未" }
    let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    return d.formatted(.dateTime.month().day().hour().minute())
}
