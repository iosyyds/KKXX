import Foundation
import Combine

/// 全局设置：服务器、账号、同步策略、外观、安全（UserDefaults 持久化）
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var serverURL: String {
        didSet { defaults.set(serverURL, forKey: "kkxx.serverURL") }
    }
    @Published var authToken: String {
        didSet { defaults.set(authToken, forKey: "kkxx.authToken") }
    }
    @Published var userEmail: String {
        didSet { defaults.set(userEmail, forKey: "kkxx.userEmail") }
    }
    @Published var skipLogin: Bool {
        didSet { defaults.set(skipLogin, forKey: "kkxx.skipLogin") }
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
        serverURL = defaults.string(forKey: "kkxx.serverURL") ?? "http://app.puaaa.cn"
        authToken = defaults.string(forKey: "kkxx.authToken") ?? ""
        userEmail = defaults.string(forKey: "kkxx.userEmail") ?? ""
        skipLogin = defaults.object(forKey: "kkxx.skipLogin") as? Bool ?? false
        autoSyncOnWifi = defaults.object(forKey: "kkxx.autoSyncOnWifi") as? Bool ?? false
        syncOnLaunch = defaults.object(forKey: "kkxx.syncOnLaunch") as? Bool ?? true
        fingerprintLock = defaults.object(forKey: "kkxx.fingerprintLock") as? Bool ?? false
        theme = defaults.string(forKey: "kkxx.theme") ?? "system"
    }

    var normalizedServerURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                 .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    /// 已登录（持有有效令牌）
    var isLoggedIn: Bool {
        !authToken.isEmpty
    }

    /// 可进入主界面：已登录，或用户选择仅本地使用
    var canEnter: Bool {
        isLoggedIn || skipLogin
    }

    /// 已配置服务器且已登录（可同步）
    var isReady: Bool {
        isLoggedIn && !normalizedServerURL.isEmpty
    }

    /// 退出登录：清除令牌与账号信息（本地数据由 LocalStore 一并清空）
    func clearAccount() {
        authToken = ""
        userEmail = ""
        skipLogin = false
    }
}
