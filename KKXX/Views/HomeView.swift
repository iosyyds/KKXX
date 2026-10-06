import SwiftUI

enum Module: String, Hashable, CaseIterable {
    case notes, todos, bills, checkin, medbox, tools, stats

    var title: String {
        switch self {
        case .notes: return "笔记"
        case .todos: return "待办"
        case .bills: return "记账"
        case .checkin: return "习惯打卡"
        case .medbox: return "药盒"
        case .tools: return "小工具"
        case .stats: return "数据总览"
        }
    }

    var symbol: String {
        switch self {
        case .notes: return "note.text"
        case .todos: return "checklist"
        case .bills: return "yensign.circle"
        case .checkin: return "calendar"
        case .medbox: return "pills"
        case .tools: return "wrench.and.screwdriver"
        case .stats: return "chart.pie"
        }
    }

    var color: Color {
        switch self {
        case .notes: return Color(red: 0.29, green: 0.57, blue: 0.98)
        case .todos: return Color(red: 0.95, green: 0.60, blue: 0.16)
        case .bills: return Color(red: 0.07, green: 0.76, blue: 0.40)
        case .checkin: return Color(red: 0.62, green: 0.36, blue: 0.95)
        case .medbox: return Color(red: 0.95, green: 0.30, blue: 0.40)
        case .tools: return Color(red: 0.05, green: 0.68, blue: 0.68)
        case .stats: return Color(red: 0.95, green: 0.35, blue: 0.55)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings
    var currentTab: Binding<MainTabView.Tab>?

    @State private var search = ""
    @State private var path = NavigationPath()

    @State private var announcement: AppAnnouncement?
    @State private var remoteVersion: String?
    @State private var updateNote = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if search.trimmingCharacters(in: .whitespaces).isEmpty {
                    content
                } else {
                    searchResults
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索笔记、待办、账单…"
            )
            .navigationDestination(for: Module.self) { m in
                destination(m)
            }
            .alert(
                announcement?.title ?? "公告",
                isPresented: Binding(
                    get: { announcement != nil },
                    set: { if !$0 { announcement = nil } }
                )
            ) {
                Button("知道了", role: .cancel) { announcement = nil }
            } message: {
                Text(announcement?.content ?? "")
            }
            .alert(
                "发现新版本 v\(remoteVersion ?? "")",
                isPresented: Binding(
                    get: { remoteVersion != nil },
                    set: { if !$0 { remoteVersion = nil } }
                )
            ) {
                Button("立即更新") {
                    if let url = URL(string: "https://gh-proxy.com/https://github.com/iosyyds/KKXX/releases/latest/download/KKXX.ipa") {
                        UIApplication.shared.open(url)
                    }
                    remoteVersion = nil
                }
                Button("以后再说", role: .cancel) { remoteVersion = nil }
            } message: {
                Text(updateNote.isEmpty ? "点击立即更新，将在 Safari 中安装新版，原有数据不会丢失。" : updateNote)
            }
            .task {
                store.syncOnLaunchIfNeeded()
                // 启动时拉取云端头像/昵称（多设备同步）
                if settings.isLoggedIn {
                    if let p = try? await SyncService().fetchProfile(settings: settings) {
                        settings.nickname = p.nickname
                        if !p.avatar.isEmpty, let d = Data(base64Encoded: p.avatar) {
                            settings.avatarData = d
                        }
                    }
                    if let me = try? await SyncService().myKx(settings: settings) {
                        settings.myKxNumber = (me["kx"] as? String) ?? ""
                    }
                }
                await checkAppInfo()
            }
        }
    }

    private func checkAppInfo() async {
        guard settings.isReady else { return }
        do {
            guard let info = try await SyncService().appInfo(settings: settings) else { return }
            if info.announcement.enabled && !info.announcement.title.isEmpty {
                announcement = info.announcement
            }
            if info.appVersion != "1.1.0" {
                remoteVersion = info.appVersion
                updateNote = info.updateNote
            }
        } catch {
            // 静默
        }
    }

    /// 首页主体：今日概览 + 次要功能宫格
    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                overviewCards
                quickGrid
            }
            .padding(.bottom, 8)
        }
    }

    /// 今日概览：4 个数据卡片
    private var overviewCards: some View {
        HStack(spacing: 10) {
            statCard(title: "今日待办", value: "\(todayTodos)", icon: "checklist", color: .orange)
            statCard(title: "今日支出", value: yuan(todayExpense), icon: "creditcard", color: .blue)
            statCard(title: "连续打卡", value: "\(streakDays)天", icon: "flame", color: .purple)
            statCard(title: "常备药品", value: "\(medCount)", icon: "pills", color: .red)
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// 快捷入口宫格：只放次要模块（笔记/待办/账单已在底部 Tab）
    private var quickGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("更多功能")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal)
            LazyVGrid(columns: columns, spacing: 14) {
                quickItem(.checkin)
                quickItem(.medbox)
                quickItem(.tools)
                quickItem(.stats)
            }
            .padding(.horizontal)
        }
    }

    private func quickItem(_ m: Module) -> some View {
        NavigationLink(value: m) {
            VStack(alignment: .leading, spacing: 9) {
                IconBadge(symbol: m.symbol, color: m.color, size: 38, corner: 12)
                Spacer(minLength: 0)
                Text(m.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 今日数据

    private var todayTodos: Int {
        let cal = Calendar.current
        return store.todos.filter { !$0.deleted && !$0.done && $0.dueDate > 0 &&
            cal.isDate(Date(timeIntervalSince1970: TimeInterval($0.dueDate) / 1000), inSameDayAs: Date()) }.count
    }

    private var todayExpense: Double {
        let cal = Calendar.current
        return store.bills.filter { !$0.deleted && $0.type == "expense" &&
            cal.isDate(Date(timeIntervalSince1970: TimeInterval($0.billDate) / 1000), inSameDayAs: Date()) }
            .reduce(0) { $0 + $1.amount }
    }

    /// 连续打卡天数（从今天往前数，今天未打卡不断档）
    private var streakDays: Int {
        let cal = Calendar.current
        let set = Set(store.checkins.filter { !$0.deleted }.map { $0.date })
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        var days = 0
        var cursor = Date()
        if !set.contains(f.string(from: cursor)) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while set.contains(f.string(from: cursor)) {
            days += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return days
    }

    private var medCount: Int {
        store.medboxes.filter { !$0.deleted }.count
    }

    private var searchResults: some View {
        let keyword = search.trimmingCharacters(in: .whitespaces)
        return List {
            let matchNotes = store.notes.filter { !$0.deleted && ($0.title.localizedCaseInsensitiveContains(keyword) || $0.content.localizedCaseInsensitiveContains(keyword) || $0.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }) }
            if !matchNotes.isEmpty {
                Section("笔记") {
                    ForEach(matchNotes) { n in
                        NavigationLink(value: Module.notes) {
                            Label(n.title.isEmpty ? "（无标题）" : n.title, systemImage: "note.text")
                        }
                    }
                }
            }
            let matchTodos = store.todos.filter { !$0.deleted && $0.title.localizedCaseInsensitiveContains(keyword) }
            if !matchTodos.isEmpty {
                Section("待办") {
                    ForEach(matchTodos) { t in
                        NavigationLink(value: Module.todos) {
                            Label(t.title, systemImage: "checklist")
                        }
                    }
                }
            }
            let matchBills = store.bills.filter { !$0.deleted && ($0.remark.localizedCaseInsensitiveContains(keyword) || $0.category.localizedCaseInsensitiveContains(keyword)) }
            if !matchBills.isEmpty {
                Section("账单") {
                    ForEach(matchBills) { b in
                        NavigationLink(value: Module.bills) {
                            HStack {
                                Label(b.remark.isEmpty ? b.category : b.remark, systemImage: b.type == "income" ? "arrow.down.circle" : "arrow.up.circle")
                                Spacer()
                                Text(yuan(b.type == "income" ? b.amount : -b.amount))
                            }
                        }
                    }
                }
            }
            let matchMedboxes = store.medboxes.filter { !$0.deleted && ($0.name.localizedCaseInsensitiveContains(keyword) || $0.purpose.localizedCaseInsensitiveContains(keyword) || $0.usage.localizedCaseInsensitiveContains(keyword) || $0.manufacturer.localizedCaseInsensitiveContains(keyword)) }
            if !matchMedboxes.isEmpty {
                Section("药盒") {
                    ForEach(matchMedboxes) { m in
                        NavigationLink(value: Module.medbox) {
                            Label(m.name.isEmpty ? "（未命名药品）" : m.name, systemImage: "pills")
                        }
                    }
                }
            }
            if matchNotes.isEmpty && matchTodos.isEmpty && matchBills.isEmpty && matchMedboxes.isEmpty {
                Text("没有匹配结果")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func destination(_ m: Module) -> some View {
        switch m {
        case .notes: NotesView()
        case .todos: TodosView()
        case .bills: BillsView()
        case .checkin: CheckinView()
        case .medbox: MedBoxView()
        case .tools: ToolsView()
        case .stats: StatsView()
        }
    }
}

#Preview { HomeView(currentTab: .constant(.home)) }
