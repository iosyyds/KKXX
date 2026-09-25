import Foundation
import Network

// MARK: - 网络可达性（Wi-Fi 判断）

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "kkxx.network")

    @Published var isConnected = false
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

// MARK: - 与后台 API 交互

struct ServerPayload: Codable {
    var notes: [Note] = []
    var todos: [TodoItem] = []
    var bills: [Bill] = []
    var checkins: [Checkin] = []
    var serverTime: Int64 = 0

    enum CodingKeys: String, CodingKey {
        case notes, todos, bills, checkins
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

enum SyncError: LocalizedError {
    case badURL
    case notConfigured
    case server(Int, String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "服务器地址无效"
        case .notConfigured: return "尚未配置服务器地址或管理员密钥"
        case .server(let code, let msg): return "服务器错误(\(code))：\(msg)"
        case .network(let m): return "网络错误：\(m)"
        }
    }
}

struct SyncService {
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    private func request(_ url: URL, settings: AppSettings) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(settings.adminKey, forHTTPHeaderField: "X-Admin-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    /// GET /api/pull.php —— 拉取服务器全量数据
    func pull(settings: AppSettings) async throws -> ServerPayload {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/pull.php") else {
            throw SyncError.badURL
        }
        let (data, resp) = try await session.data(for: request(url, settings: settings))
        try validate(resp)
        let envelope = try JSONDecoder().decode(ApiEnvelope.self, from: data)
        guard envelope.code == 0, let payload = envelope.data else {
            throw SyncError.server(envelope.code, envelope.msg)
        }
        return payload
    }

    /// POST /api/sync.php —— 上传本地数据并返回服务器全量数据
    func sync(upload: ServerPayload, settings: AppSettings) async throws -> ServerPayload {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/sync.php") else {
            throw SyncError.badURL
        }
        var req = request(url, settings: settings)
        req.httpMethod = "POST"
        req.httpBody = try JSONEncoder().encode(UploadRequest(upload: upload))
        let (data, resp) = try await session.data(for: req)
        try validate(resp)
        let envelope = try JSONDecoder().decode(ApiEnvelope.self, from: data)
        guard envelope.code == 0, let payload = envelope.data else {
            throw SyncError.server(envelope.code, envelope.msg)
        }
        return payload
    }

    /// POST /api/verify.php —— 校验密钥
    func verify(settings: AppSettings) async throws -> Bool {
        let base = settings.normalizedServerURL
        guard !base.isEmpty, let url = URL(string: "\(base)/api/verify.php") else {
            throw SyncError.badURL
        }
        let (data, resp) = try await session.data(for: request(url, settings: settings))
        try validate(resp)
        let envelope = try JSONDecoder().decode(ApiEnvelope.self, from: data)
        return envelope.code == 0
    }

    private func validate(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.network("HTTP \(http.statusCode)")
        }
    }
}
