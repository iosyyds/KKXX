import SwiftUI

enum Module: String, Hashable, CaseIterable {
    case notes, todos, bills, checkin, tools, stats

    var title: String {
        switch self {
        case .notes: return "笔记"
        case .todos: return "待办"
        case .bills: return "记账"
        case .checkin: return "习惯打卡"
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
        case .tools: return "wrench.and.screwdriver"
        case .stats: return "chart.pie"
        }
    }

    var color: Color {
        switch self {
        case .notes: return Color(red: 0.29, green: 0.57, blue: 0.98)   // 蓝
        case .todos: return Color(red: 0.95, green: 0.60, blue: 0.16)   // 橙
        case .bills: return Color(red: 0.07, green: 0.76, blue: 0.40)   // 绿
        case .checkin: return Color(red: 0.62, green: 0.36, blue: 0.95) // 紫
        case .tools: return Color(red: 0.05, green: 0.68, blue: 0.68)   // 青
        case .stats: return Color(red: 0.95, green: 0.35, blue: 0.55)   // 粉
        }
    }
}

enum NewItemType: String, Identifiable {
    case note, todo, bill
    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings

    @State private var search = ""
    @State private var showSettings = false
    @State private var path = NavigationPath()
    @State private var showNewMenu = false
    @State private var newItem: NewItemType?

    @State private var announcement: AppAnnouncement?
    @State private var remoteVersion: String?
    @State private var updateNote = ""

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if search.trimmingCharacters(in: .whitespaces).isEmpty {
                    moduleGrid
                } else {
                    searchResults
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("KKXX")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索笔记、待办、账单…"
            )
            .navigationDestination(for: Module.self) { m in
                destination(m)
            }
            .toolbar { avatarButton }
            .sheet(isPresented: $showSettings) { SettingsSheet() }
            .sheet(isPresented: $showNewMenu) {
                NewMenuSheet { item in newItem = item }
            }
            .sheet(item: $newItem) { item in
                switch item {
                case .note: NoteEditorView(note: Note())
                case .todo: TodoEditorView(todo: TodoItem())
                case .bill: BillEditorView(bill: Bill())
                }
            }
            .overlay(alignment: .bottomTrailing) { fab }
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
                Button("知道了") { remoteVersion = nil }
            } message: {
                Text(updateNote.isEmpty ? "新版本已发布，请前往官方渠道下载更新。" : updateNote)
            }
            .task {
                store.syncOnLaunchIfNeeded()
                await checkAppInfo()
            }
        }
    }

    /// 启动时拉取应用信息：公告弹窗 + 版本更新提示（静默，失败不打扰）
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

    /// 首页宫格：苹果原生卡片风格
    private var moduleGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Module.allCases, id: \.self) { m in
                    NavigationLink(value: m) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(m.color.opacity(0.14))
                                Image(systemName: m.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(m.color)
                            }
                            .frame(width: 38, height: 38)

                            Spacer(minLength: 0)

                            Text(m.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(subtitle(m))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }

    private func subtitle(_ m: Module) -> String {
        switch m {
        case .notes:
            return "\(store.notes.filter { !$0.deleted }.count) 篇笔记"
        case .todos:
            return "\(store.todos.filter { !$0.deleted && !$0.done }.count) 项待完成"
        case .bills:
            return "\(store.bills.filter { !$0.deleted }.count) 笔记录"
        case .checkin:
            return "累计打卡 \(store.checkins.filter { !$0.deleted }.count) 次"
        case .tools:
            return "计算与换算"
        case .stats:
            return "数据看板"
        }
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
            if matchNotes.isEmpty && matchTodos.isEmpty && matchBills.isEmpty {
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
        case .tools: ToolsView()
        case .stats: StatsView()
        }
    }

    private var avatarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundColor(Color(red: 0.07, green: 0.76, blue: 0.40))
            }
        }
    }

    private var fab: some View {
        Button { showNewMenu = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.85, blue: 0.48), Color(red: 0.03, green: 0.65, blue: 0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .shadow(color: Color(red: 0.03, green: 0.65, blue: 0.35).opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .padding(20)
    }
}

/// 底部新建菜单：从底部滑出的原生样式操作列表
struct NewMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (NewItemType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("新建")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 4)
            menuRow("note.text", "新建笔记", .blue) { onPick(.note) }
            Divider().padding(.leading, 60)
            menuRow("checklist", "新建待办", .orange) { onPick(.todo) }
            Divider().padding(.leading, 60)
            menuRow("yensign.circle", "记一笔", .green) { onPick(.bill) }
            Spacer(minLength: 0)
        }
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
    }

    private func menuRow(_ symbol: String, _ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32)
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview { HomeView() }
