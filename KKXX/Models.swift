import Foundation

func nowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}

/// 可同步数据模型的公共协议：所有实体都带时间戳与软删除标记
protocol Syncable: Identifiable, Codable, Hashable {
    var updatedAt: Int64 { get set }
    var deleted: Bool { get set }
}

/// 兼容服务器返回的 deleted 字段：可能是 true/false，也可能是 0/1 整数
private func decodeDeletedFlag<C: KeyedDecodingContainerProtocol>(_ c: C, key: C.Key) -> Bool {
    if let b = try? c.decode(Bool.self, forKey: key) { return b }
    if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
    return false
}

struct Note: Syncable {
    var id: String
    var title: String
    var content: String
    var images: [String]   // base64 data URI 列表
    var tags: [String]
    var createdAt: Int64
    var updatedAt: Int64
    var deleted: Bool {
        get { deletedFlag != 0 }
        set { deletedFlag = newValue ? 1 : 0 }
    }

    /// 以 0/1 存储 deleted，同时兼容 Int 与 Bool 解码
    private var deletedFlag: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, title, content, images, tags, createdAt, updatedAt, deletedFlag = "deleted"
    }

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? nowMs()
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? createdAt
        deletedFlag = decodeDeletedFlag(c, key: .deletedFlag) ? 1 : 0
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
    var deleted: Bool {
        get { deletedFlag != 0 }
        set { deletedFlag = newValue ? 1 : 0 }
    }

    private var deletedFlag: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, title, done, dueDate, tags, createdAt, updatedAt, deletedFlag = "deleted"
    }

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        dueDate = try c.decodeIfPresent(Int64.self, forKey: .dueDate) ?? 0
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? nowMs()
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? createdAt
        deletedFlag = decodeDeletedFlag(c, key: .deletedFlag) ? 1 : 0
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
    var deleted: Bool {
        get { deletedFlag != 0 }
        set { deletedFlag = newValue ? 1 : 0 }
    }

    private var deletedFlag: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, type, amount, category, remark, billDate, createdAt, updatedAt, deletedFlag = "deleted"
    }

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "expense"
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        remark = try c.decodeIfPresent(String.self, forKey: .remark) ?? ""
        billDate = try c.decodeIfPresent(Int64.self, forKey: .billDate) ?? nowMs()
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? nowMs()
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? createdAt
        deletedFlag = decodeDeletedFlag(c, key: .deletedFlag) ? 1 : 0
    }
}

struct Checkin: Syncable {
    var id: String
    var date: String        // yyyy-MM-dd
    var note: String
    var createdAt: Int64
    var updatedAt: Int64
    var deleted: Bool {
        get { deletedFlag != 0 }
        set { deletedFlag = newValue ? 1 : 0 }
    }

    private var deletedFlag: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, date, note, createdAt, updatedAt, deletedFlag = "deleted"
    }

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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? nowMs()
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? createdAt
        deletedFlag = decodeDeletedFlag(c, key: .deletedFlag) ? 1 : 0
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
