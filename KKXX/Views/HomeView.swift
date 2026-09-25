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
        case .todos: return Color(red: 0.98, green: 0.62, blue: 0.20)   // 橙
        case .bills: return Color(red: 0.07, green: 0.76, blue: 0.40)   // 绿
        case .checkin: return Color(red: 0.62, green: 0.36, blue: 0.95) // 紫
        case .tools: return Color(red: 0.05, green: 0.70, blue: 0.70)   // 青
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
    @State private var showFabDialog = false
    @State private var newItem: NewItemType?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var todayLine: String {
        Date().formatted(.dateTime.month(.wide).day().weekday(.wide))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    searchBar
                    if search.trimmingCharacters(in: .whitespaces).isEmpty {
                        moduleGrid
                    } else {
                        searchResults
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("KKXX")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Module.self) { m in
                destination(m)
            }
            .toolbar { avatarButton }
            .sheet(isPresented: $showSettings) { SettingsSheet() }
            .sheet(item: $newItem) { item in
                switch item {
                case .note: NoteEditorView(note: Note())
                case .todo: TodoEditorView(todo: TodoItem())
                case .bill: BillEditorView(bill: Bill())
                }
            }
            .overlay(alignment: .bottomTrailing) { fab }
            .confirmationDialog("新建", isPresented: $showFabDialog, titleVisibility: .visible) {
                Button("新建笔记") { newItem = .note }
                Button("新建待办") { newItem = .todo }
                Button("记一笔") { newItem = .bill }
                Button("取消", role: .cancel) {}
            }
            .task { store.syncOnLaunchIfNeeded() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayLine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isSyncing ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(store.syncStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索笔记、待办、账单…", text: $search)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var moduleGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Module.allCases, id: \.self) { m in
                NavigationLink(value: m) {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.22))
                            Image(systemName: m.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 42, height: 42)

                        Spacer(minLength: 0)

                        Text(m.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(subtitle(m))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [m.color, m.color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: m.color.opacity(0.30), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
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
        .scrollContentBackground(.hidden)
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
        Button { showFabDialog = true } label: {
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
                .shadow(color: Color(red: 0.03, green: 0.65, blue: 0.35).opacity(0.40), radius: 8, x: 0, y: 4)
        }
        .padding(20)
    }
}

#Preview { HomeView() }
