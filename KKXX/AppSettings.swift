import Foundation
import Combine

/// 全局设置：服务器、密钥、同步策略、外观、安全（UserDefaults 持久化）
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var serverURL: String {
        didSet { defaults.set(serverURL, forKey: "kkxx.serverURL") }
    }
    @Published var adminKey: String {
        didSet { defaults.set(adminKey, forKey: "kkxx.adminKey") }
    }
    @Published var autoSyncOnWifi: Bool {
        didSet { defaults.set(autoSyncOnWifi, forKey: "kkxx.autoSyncOnWifi") }
    }
    @Published var syncOnLaunch: Bool {
        didSet { defaults.set(syncOnLaunch, forKey: "kkxx.syncOnLaunch") }
    }
    @Published var fingerprintLock: Bool {
        didSet { defaults.set(fingerprintLock, forKey: "kkxx.fingerprintLock") }
    }
    @Published var theme: String {          // system / light / dark
        didSet { defaults.set(theme, forKey: "kkxx.theme") }
    }

    private init() {
        serverURL = defaults.string(forKey: "kkxx.serverURL") ?? "https://app.puaaa.cn"
        adminKey = defaults.string(forKey: "kkxx.adminKey") ?? ""
        autoSyncOnWifi = defaults.object(forKey: "kkxx.autoSyncOnWifi") as? Bool ?? true
        syncOnLaunch = defaults.object(forKey: "kkxx.syncOnLaunch") as? Bool ?? true
        fingerprintLock = defaults.object(forKey: "kkxx.fingerprintLock") as? Bool ?? false
        theme = defaults.string(forKey: "kkxx.theme") ?? "system"
    }

    var normalizedServerURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                 .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    var isConfigured: Bool {
        !normalizedServerURL.isEmpty && !adminKey.isEmpty
    }
}
