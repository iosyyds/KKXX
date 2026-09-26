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
