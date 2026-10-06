import SwiftUI
import UserNotifications

extension Notification.Name {
    /// 双击底部 Tab 时发送，各列表页监听并滚动到顶部
    static let scrollToTop = Notification.Name("KKXXScrollToTop")
}

/// 主界面：液态玻璃悬浮 Tab 栏（爱奇艺式）
struct MainTabView: View {
    enum Tab: Int, CaseIterable {
        case home, notes, todos, bills, me

        var title: String {
            switch self {
            case .home: return "首页"
            case .notes: return "笔记"
            case .todos: return "待办"
            case .bills: return "账单"
            case .me: return "我的"
            }
        }
        var outline: String {
            switch self {
            case .home: return "house"
            case .notes: return "note.text"
            case .todos: return "checklist"
            case .bills: return "creditcard"
            case .me: return "person"
            }
        }
        var filled: String {
            switch self {
            case .home: return "house.fill"
            case .notes: return "note.text"
            case .todos: return "checklist"
            case .bills: return "creditcard.fill"
            case .me: return "person.fill"
            }
        }
    }

    @EnvironmentObject var settings: AppSettings
    @State private var tab: Tab = .home
    @State private var lastTap: (Tab, Date) = (.home, .distantPast)
    private let feedback = UISelectionFeedbackGenerator()

    var body: some View {
        Group {
            if settings.isLoggedIn {
                tabBody
            } else {
                AuthView()
            }
        }
        .task {
            // 启动即发起一次网络请求，触发系统「允许使用无线数据」弹窗
            _ = try? await SyncService().verify(settings: settings)
            // 请求本地通知权限
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
            // 轮询好友消息
            await pollMessages()
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            Task { await pollMessages() }
        }
    }

    private func pollMessages() async {
        guard settings.isLoggedIn else { return }
        do {
            let list = try await SyncService().friendList(settings: settings)
            for f in list {
                let unread = (f["unread"] as? Int) ?? 0
                if unread > 0, let kx = f["kx_number"] as? String {
                    let nick = (f["nickname"] as? String).flatMap { $0.isEmpty ? kx : $0 } ?? kx
                    let content = try? await SyncService().pullMessages(withKx: kx, afterTs: 0, settings: settings)
                    let lastText = (content?.last?["content"] as? String) ?? "新消息"
                    notify(title: nick, body: lastText)
                }
            }
        } catch { }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private var tabBody: some View {
        ZStack(alignment: .bottom) {
            // 常驻所有 Tab，切换保留页面状态
            ZStack {
                tabContent(.home)
                tabContent(.notes)
                tabContent(.todos)
                tabContent(.bills)
                tabContent(.me)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 120) }

            if !settings.tabBarHidden {
                floatingTabBar
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ t: Tab) -> some View {
        Group {
            switch t {
            case .home: HomeView(currentTab: $tab)
            case .notes: NavigationStack { NotesView() }
            case .todos: NavigationStack { TodosView() }
            case .bills: NavigationStack { BillsView() }
            case .me: NavigationStack { MeView() }
            }
        }
        .opacity(tab == t ? 1 : 0)
        .allowsHitTesting(tab == t)
    }

    /// 液态玻璃悬浮胶囊 Tab 栏
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { t in
                tabButton(t)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 62)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }

    private func tabButton(_ t: Tab) -> some View {
        let selected = tab == t
        return Button {
            feedback.selectionChanged()
            // 双击当前 Tab：回顶部
            if tab == t, Date().timeIntervalSince(lastTap.1) < 0.35 {
                NotificationCenter.default.post(name: .scrollToTop, object: nil, userInfo: ["tab": t.rawValue])
                lastTap = (t, .distantPast)
                return
            }
            lastTap = (t, Date())
            if tab != t {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { tab = t }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selected ? t.filled : t.outline)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                Text(t.title)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
            }
            .foregroundColor(selected ? brandGreen : Color(.tertiaryLabel))
            .scaleEffect(selected ? 1.0 : 0.94)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 启动分流（主界面 / 登录）
struct RootView: View {
    var body: some View {
        MainTabView()
    }
}
