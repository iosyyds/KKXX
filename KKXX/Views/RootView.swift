import SwiftUI

/// 主界面：底部悬浮毛玻璃 Tab 导航（微信式）
struct MainTabView: View {
    enum Tab: Int, CaseIterable {
        case home, notes, todos, bills, me
    }

    @EnvironmentObject var settings: AppSettings
    @State private var unlocked = false
    @State private var tab: Tab = .home

    var body: some View {
        Group {
            if settings.fingerprintLock && !unlocked {
                LockView(unlocked: $unlocked)
            } else if settings.canEnter {
                tabBody
            } else {
                AuthView()
            }
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
            withAnimation(.easeInOut(duration: 0.18)) { tab = t }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
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
