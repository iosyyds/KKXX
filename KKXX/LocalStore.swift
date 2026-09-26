import Foundation
import Combine

/// 本地离线存储 + 待同步队列 + 双向同步引擎
final class LocalStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var todos: [TodoItem] = []
    @Published var bills: [Bill] = []
    @Published var checkins: [Checkin] = []
    @Published var medboxes: [MedBoxItem] = []

    @Published var lastSyncTime: Int64 = 0
    @Published var syncStatus = "未同步"
    @Published var isSyncing = false

    private let settings = AppSettings.shared
    private let sync = SyncService()

    /// 待同步队列：记录每个实体的 id（含软删除墓碑）
    private var dirtyNotes = Set<String>()
    private var dirtyTodos = Set<String>()
    private var dirtyBills = Set<String>()
    private var dirtyCheckins = Set<String>()
    private var dirtyMedboxes = Set<String>()

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("kkxx_local.json")
    }

    init() {
        load()
    }

    // MARK: - 持久化

    private struct Snapshot: Codable {
        var notes: [Note]
        var todos: [TodoItem]
        var bills: [Bill]
        var checkins: [Checkin]
        var medboxes: [MedBoxItem]?
        var lastSyncTime: Int64
        var dirtyNotes: [String]
        var dirtyTodos: [String]
        var dirtyBills: [String]
        var dirtyCheckins: [String]
        var dirtyMedboxes: [String]?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        notes = snap.notes
        todos = snap.todos
        bills = snap.bills
        checkins = snap.checkins
        medboxes = snap.medboxes ?? []
        lastSyncTime = snap.lastSyncTime
        dirtyNotes = Set(snap.dirtyNotes)
        dirtyTodos = Set(snap.dirtyTodos)
        dirtyBills = Set(snap.dirtyBills)
        dirtyCheckins = Set(snap.dirtyCheckins)
        dirtyMedboxes = Set(snap.dirtyMedboxes ?? [])
    }

    private func save() {
        let snap = Snapshot(notes: notes, todos: todos, bills: bills, checkins: checkins, medboxes: medboxes,
                            lastSyncTime: lastSyncTime,
                            dirtyNotes: Array(dirtyNotes), dirtyTodos: Array(dirtyTodos),
                            dirtyBills: Array(dirtyBills), dirtyCheckins: Array(dirtyCheckins),
                            dirtyMedboxes: Array(dirtyMedboxes))
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - 通用工具

    var pendingCount: Int {
        dirtyNotes.count + dirtyTodos.count + dirtyBills.count + dirtyCheckins.count + dirtyMedboxes.count
    }

    func upsert(_ note: Note) {
        var n = note
        n.updatedAt = nowMs()
        if let i = notes.firstIndex(where: { $0.id == n.id }) { notes[i] = n } else { notes.append(n) }
        dirtyNotes.insert(n.id)
        save(); autoSyncIfPossible()
    }

    func softDeleteNote(id: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].deleted = true
        notes[i].updatedAt = nowMs()
        dirtyNotes.insert(id)
        save(); autoSyncIfPossible()
    }

    func upsert(_ todo: TodoItem) {
        var t = todo; t.updatedAt = nowMs()
        if let i = todos.firstIndex(where: { $0.id == t.id }) { todos[i] = t } else { todos.append(t) }
        dirtyTodos.insert(t.id)
        save(); autoSyncIfPossible()
    }

    func softDeleteTodo(id: String) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].deleted = true
        todos[i].updatedAt = nowMs()
        dirtyTodos.insert(id)
        save(); autoSyncIfPossible()
    }

    func upsert(_ bill: Bill) {
        var b = bill; b.updatedAt = nowMs()
        if let i = bills.firstIndex(where: { $0.id == b.id }) { bills[i] = b } else { bills.append(b) }
        dirtyBills.insert(b.id)
        save(); autoSyncIfPossible()
    }

    func softDeleteBill(id: String) {
        guard let i = bills.firstIndex(where: { $0.id == id }) else { return }
        bills[i].deleted = true
        bills[i].updatedAt = nowMs()
        dirtyBills.insert(id)
        save(); autoSyncIfPossible()
    }

    func upsert(_ checkin: Checkin) {
        var c = checkin; c.updatedAt = nowMs()
        if let i = checkins.firstIndex(where: { $0.id == c.id }) { checkins[i] = c } else { checkins.append(c) }
        dirtyCheckins.insert(c.id)
        save(); autoSyncIfPossible()
    }

    func softDeleteCheckin(id: String) {
        guard let i = checkins.firstIndex(where: { $0.id == id }) else { return }
        checkins[i].deleted = true
        checkins[i].updatedAt = nowMs()
        dirtyCheckins.insert(id)
        save(); autoSyncIfPossible()
    }

    func upsert(_ medbox: MedBoxItem) {
        var m = medbox; m.updatedAt = nowMs()
        if let i = medboxes.firstIndex(where: { $0.id == m.id }) { medboxes[i] = m } else { medboxes.append(m) }
        dirtyMedboxes.insert(m.id)
        save(); autoSyncIfPossible()
    }

    func softDeleteMedBox(id: String) {
        guard let i = medboxes.firstIndex(where: { $0.id == id }) else { return }
        medboxes[i].deleted = true
        medboxes[i].updatedAt = nowMs()
        dirtyMedboxes.insert(id)
        save(); autoSyncIfPossible()
    }

    // MARK: - 待同步上传载荷

    private func uploadPayload(full: Bool) -> ServerPayload {
        func pick<T: Syncable>(_ rows: [T], dirty: Set<String>) -> [T] where T: Identifiable, T.ID == String {
            full ? rows : rows.filter { dirty.contains($0.id) }
        }
        return ServerPayload(notes: pick(notes, dirty: dirtyNotes),
                             todos: pick(todos, dirty: dirtyTodos),
                             bills: pick(bills, dirty: dirtyBills),
                             checkins: pick(checkins, dirty: dirtyCheckins),
                             medboxes: pick(medboxes, dirty: dirtyMedboxes))
    }

    private func clearDirty(for payload: ServerPayload) {
        func remove<T: Syncable>(_ rows: [T]) -> Set<String> where T: Identifiable, T.ID == String {
            Set(rows.map(\.id))
        }
        dirtyNotes.subtract(remove(payload.notes))
        dirtyTodos.subtract(remove(payload.todos))
        dirtyBills.subtract(remove(payload.bills))
        dirtyCheckins.subtract(remove(payload.checkins))
        dirtyMedboxes.subtract(remove(payload.medboxes))
    }

    // MARK: - 合并服务器数据（LWW：时间戳新者胜）

    private func mergeRows<T: Syncable>(_ local: [T], _ server: [T], dirty: Set<String>) -> [T]
        where T: Identifiable, T.ID == String {
        var map: [String: T] = [:]
        for r in local { map[r.id] = r }
        for s in server {
            if let l = map[s.id] {
                if s.updatedAt >= l.updatedAt {
                    map[s.id] = s
                }
            } else {
                map[s.id] = s
            }
        }
        // 删除服务器已确认的墓碑；本地仍有待推送的删除保留
        let kept = map.values.filter { !$0.deleted || dirty.contains($0.id) }
        return Array(kept).sorted { $0.updatedAt > $1.updatedAt }
    }

    private func applyServer(_ payload: ServerPayload) {
        notes = mergeRows(notes, payload.notes, dirty: dirtyNotes)
        todos = mergeRows(todos, payload.todos, dirty: dirtyTodos)
        bills = mergeRows(bills, payload.bills, dirty: dirtyBills)
        checkins = mergeRows(checkins, payload.checkins, dirty: dirtyCheckins)
        medboxes = mergeRows(medboxes, payload.medboxes, dirty: dirtyMedboxes)
    }

    private func purgeSyncedTombstones() {
        notes.removeAll { $0.deleted && !dirtyNotes.contains($0.id) }
        todos.removeAll { $0.deleted && !dirtyTodos.contains($0.id) }
        bills.removeAll { $0.deleted && !dirtyBills.contains($0.id) }
        checkins.removeAll { $0.deleted && !dirtyCheckins.contains($0.id) }
        medboxes.removeAll { $0.deleted && !dirtyMedboxes.contains($0.id) }
    }

    // MARK: - 同步入口

    enum SyncMode {
        case normal          // 先上传本地变更，再拉取合并
        case pullOnly        // 以云端覆盖本地
        case pushOnly        // 以本地覆盖云端
    }

    func syncNow(mode: SyncMode = .normal) async {
        guard settings.isReady else {
            syncStatus = settings.isLoggedIn ? "未配置服务器" : "未登录，请先登录"
            return
        }
        isSyncing = true
        syncStatus = "同步中…"
        defer { isSyncing = false }

        do {
            let payload: ServerPayload
            switch mode {
            case .normal:
                let upload = uploadPayload(full: false)
                payload = try await sync.sync(upload: upload, settings: settings)
                clearDirty(for: upload)
            case .pullOnly:
                payload = try await sync.pull(settings: settings)
            case .pushOnly:
                let upload = uploadPayload(full: true)
                payload = try await sync.sync(upload: upload, settings: settings)
                clearDirty(for: upload)
            }

            applyServer(payload)
            lastSyncTime = payload.serverTime > 0 ? payload.serverTime : nowMs()
            save()
            purgeSyncedTombstones()
            save()
            syncStatus = "同步成功 · \(shortTime(lastSyncTime))"
        } catch {
            // 网络/链接类失败：再检测一次服务器可达性，明确提示「链接失败」
            if SyncService.isConnectionError(error) {
                let reachable = (try? await sync.verify(settings: settings)) ?? false
                syncStatus = reachable
                    ? "同步失败：" + error.localizedDescription
                    : "同步失败：无法连接服务器（链接失败），请检查网络后重试"
            } else {
                syncStatus = "同步失败：" + error.localizedDescription
            }
        }
    }

    /// 变更后自动同步：只要网络可用就上传（数据跟随账号，不设 Wi-Fi 限制）
    private func autoSyncIfPossible() {
        guard settings.isReady else { return }
        guard NetworkMonitor.shared.isConnected else { return }
        Task { await syncNow(mode: .normal) }
    }

    /// 启动时自动拉取
    func syncOnLaunchIfNeeded() {
        guard settings.syncOnLaunch, settings.isReady else { return }
        guard NetworkMonitor.shared.isConnected else { return }
        Task { await syncNow(mode: .normal) }
    }

    /// 退出登录前补传：把本地待同步数据尽量传上云端（联网时）
    func syncBeforeLogout() async {
        guard settings.isReady, pendingCount > 0 else { return }
        await syncNow(mode: .normal)
    }

    /// 退出登录：清除账号、本地缓存与待同步队列
    func logout() {
        settings.clearAccount()
        notes.removeAll()
        todos.removeAll()
        bills.removeAll()
        checkins.removeAll()
        medboxes.removeAll()
        dirtyNotes.removeAll()
        dirtyTodos.removeAll()
        dirtyBills.removeAll()
        dirtyCheckins.removeAll()
        dirtyMedboxes.removeAll()
        lastSyncTime = 0
        syncStatus = "未登录"
        save()
    }
}
