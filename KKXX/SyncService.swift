import Foundation
import Network

// MARK: - 网络可达性（Wi-Fi 判断）

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "kkxx.network")

    @Published var isConnected = true   // 乐观初始：状态未知时先尝试上传，由请求结果真实判定
    @Published var isWifi = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                self?.isWifi = path.usesInterfaceType(.wifi)
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - 与后台 API 交互（多账号版：注册/登录拿令牌，同步接口带 X-Token）

struct ServerPayload: Codable {
    var notes: [Note] = []
    var todos: [TodoItem] = []
    var bills: [Bill] = []
    var checkins: [Checkin] = []
    var medboxes: [MedBoxItem] = []
    var serverTime: Int64 = 0

    enum CodingKeys: String, CodingKey {
        case notes, todos, bills, checkins, medboxes = "medbox"
        case serverTime = "server_time"
    }
}

struct UploadRequest: Codable {
    var upload: ServerPayload
}

struct ApiEnvelope: Codable {
    var code: Int
    var msg: String
    var data: ServerPayload?
}

// MARK: - 账号 / 应用信息响应

struct AuthData: Codable {
    var token: String
    var email: String
    var userId: Int?
    var serverTime: Int64?

    enum CodingKeys: String, CodingKey {
        case token, email
        case userId = "user_id"
        case serverTime = "server_time"
    }
}

struct AuthEnvelope: Codable {
    var code: Int
    var msg: String
    var data: AuthData?
}

struct AppInfoData: Codable {
    var appVersion: String
    var updateNote: String
    var announcement: AppAnnouncement
    var syncEnabled: Bool
    var serverTime: Int64?

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case updateNote = "update_note"
        case announcement, syncEnabled = "sync_enabled"
        case serverTime = "server_time"
    }
}

struct AppAnnouncement: Codable {
    var enabled: Bool
    var title: String
    var content: String
}

struct AppInfoEnvelope: Codable {
    var code: Int
    var msg: String
    var data: AppInfoData?
}

/// /api/verify.php 专用响应结构（data 结构不同于同步接口）
struct VerifyData: Codable {
    var verified: Bool
    var serverTime: Int64?
    var syncEnabled: Bool?
    var appVersion: String?

    enum CodingKeys: String, CodingKey {
        case verified
        case serverTime = "server_time"
        case syncEnabled = "sync_enabled"
        case appVersion = "app_version"
    }
}

struct VerifyEnvelope: Codable {
    var code: Int
    var msg: String
    var data: VerifyData?
}

enum SyncError: LocalizedError {
    case badURL
    case notConfigured
    case notLoggedIn
    case authFailed(String)
    case server(Int, String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "服务器地址无效"
        case .notConfigured: return "尚未配置服务器地址"
        case .notLoggedIn: return "请先登录"
        case .authFailed(let m): return m
        case .server(let code, let msg): return "服务器错误(\(code))：\(msg)"
        case .network(let m): return "网络错误：\(m)"
        }
    }
}

extension SyncService {
    /// 判断错误是否属于「网络/链接失败」类（区别于服务器返回的业务错误）
    static func isConnectionError(_ error: Error) -> Bool {
        if let e = error as? SyncError {
            if case .network = e { return true }
            return false
        }
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .timedOut, .cannotConnectToHost,
                 .cannotFindHost, .networkConnectionLost, .dnsLookupFailed,
                 .internationalRoamingOff, .dataNotAllowed, .resourceUnavailable:
                return true
            default:
                return false
            }
        }
        return false
    }
}

struct SyncService {
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    /// 通用 JSON 请求；token 非空时携带 X-Token 请求头
    private func request(_ url: URL, token: String? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token, !t.isEmpty {
            req.setValue(t, forHTTPHeaderField: "X-Token")
        }
        return req
    }

    private func postJSON<T: Encodable>(_ url: URL, body: T, token: String? = nil) async throws -> Data {
        var req = request(url, token: token)
        req.httpMethod = "POST"
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        try validate(resp)
        return data
    }

    // MARK: - 账号

    /// POST /api/register.php —— 注册并返回令牌
    func register(email: String, password: String, settings: AppSettings) async throws -> String {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/register.php") else {
            throw SyncError.badURL
        }
        struct AuthBody: Encodable { var email: String; var password: String }
        let data = try await postJSON(url, body: AuthBody(email: email, password: password))
        let envelope = try JSONDecoder().decode(AuthEnvelope.self, from: data)
        guard envelope.code == 0, let auth = envelope.data else {
            throw SyncError.authFailed(envelope.msg)
        }
        return auth.token
    }

    /// POST /api/login.php —— 登录并返回令牌
    func login(email: String, password: String, settings: AppSettings) async throws -> String {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/login.php") else {
            throw SyncError.badURL
        }
        struct AuthBody: Encodable { var email: String; var password: String }
        let data = try await postJSON(url, body: AuthBody(email: email, password: password))
        let envelope = try JSONDecoder().decode(AuthEnvelope.self, from: data)
        guard envelope.code == 0, let auth = envelope.data else {
            throw SyncError.authFailed(envelope.msg)
        }
        return auth.token
    }

    // MARK: - 同步

    /// GET /api/pull.php —— 拉取服务器全量数据（需登录）
    func pull(settings: AppSettings) async throws -> ServerPayload {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/pull.php") else {
            throw SyncError.badURL
        }
        guard settings.isLoggedIn else { throw SyncError.notLoggedIn }
        let (data, resp) = try await session.data(for: request(url, token: settings.authToken))
        try validate(resp)
        let envelope = try JSONDecoder().decode(ApiEnvelope.self, from: data)
        guard envelope.code == 0, let payload = envelope.data else {
            throw SyncError.server(envelope.code, envelope.msg)
        }
        return payload
    }

    /// POST /api/sync.php —— 上传本地数据并返回服务器全量数据（需登录）
    func sync(upload: ServerPayload, settings: AppSettings) async throws -> ServerPayload {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/sync.php") else {
            throw SyncError.badURL
        }
        guard settings.isLoggedIn else { throw SyncError.notLoggedIn }
        let data = try await postJSON(url, body: UploadRequest(upload: upload), token: settings.authToken)
        let envelope = try JSONDecoder().decode(ApiEnvelope.self, from: data)
        guard envelope.code == 0, let payload = envelope.data else {
            throw SyncError.server(envelope.code, envelope.msg)
        }
        return payload
    }

    // MARK: - 应用信息

    /// GET /api/appinfo.php —— 启动时拉取版本 / 公告 / 同步开关（无需登录）
    func appInfo(settings: AppSettings) async throws -> AppInfoData? {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/appinfo.php") else {
            throw SyncError.badURL
        }
        let (data, resp) = try await session.data(for: request(url))
        try validate(resp)
        let envelope = try JSONDecoder().decode(AppInfoEnvelope.self, from: data)
        guard envelope.code == 0 else { return nil }
        return envelope.data
    }

    /// GET /api/verify.php —— 检测服务器是否可连接
    func verify(settings: AppSettings) async throws -> Bool {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/verify.php") else {
            throw SyncError.badURL
        }
        let (data, resp) = try await session.data(for: request(url))
        try validate(resp)
        let envelope = try JSONDecoder().decode(VerifyEnvelope.self, from: data)
        return envelope.code == 0 && (envelope.data?.verified ?? false)
    }

    private func validate(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.network("HTTP \(http.statusCode)")
        }
    }
}
