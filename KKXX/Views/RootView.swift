import SwiftUI

/// 主界面：底部悬浮毛玻璃 Tab 导航（微信式）
struct MainTabView: View {
    enum Tab: Int, CaseIterable {
        case home, notes, todos, bills, me
    }

    @EnvironmentObject var settings: AppSettings
    @State private var unlocked = false
    @State private var tab: Tab = .home
    private let feedback = UISelectionFeedbackGenerator()

    var body: some View {
        Group {
            if settings.fingerprintLock && !unlocked {
                LockView(unlocked: $unlocked)
            } else if settings.isLoggedIn {
                tabBody
            } else {
                AuthView()
            }
        }
        .task {
            // 启动即发起一次网络请求，触发系统「允许使用无线数据」弹窗
            _ = try? await SyncService().verify(settings: settings)
        }
    }

    private var tabBody: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: HomeView(currentTab: $tab)
                case .notes: NotesView()
                case .todos: TodosView()
                case .bills: BillsView()
                case .me: MeView()
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 84) }

            floatingTabBar
        }
    }

    /// 悬浮毛玻璃胶囊 Tab 栏
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, symbol: "house", title: "首页")
            tabButton(.notes, symbol: "note.text", title: "笔记")
            tabButton(.todos, symbol: "checklist", title: "待办")
            tabButton(.bills, symbol: "creditcard", title: "账单")
            tabButton(.me, symbol: "person", title: "我的")
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

    private func tabButton(_ t: Tab, symbol: String, title: String) -> some View {
        let selected = tab == t
        return Button {
            feedback.selectionChanged()
            if tab != t {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { tab = t }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                    .scaleEffect(selected ? 1.0 : 0.92)
                Text(title)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
            }
            .foregroundColor(selected ? brandGreen : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 启动分流（锁 / 主界面 / 登录）
struct RootView: View {
    var body: some View {
        MainTabView()
    }
}
