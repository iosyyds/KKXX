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
        case .notes: return .blue
        case .todos: return .orange
        case .bills: return .green
        case .checkin: return .purple
        case .tools: return .teal
        case .stats: return .pink
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
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

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索笔记、待办、账单…", text: $search)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var moduleGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Module.allCases, id: \.self) { m in
                NavigationLink(value: m) {
                    VStack(spacing: 10) {
                        Image(systemName: m.symbol)
                            .font(.title2)
                            .foregroundColor(m.color)
                        Text(m.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
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
            }
        }
    }

    private var fab: some View {
        Button { showFabDialog = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
        .padding(20)
    }
}

#Preview { HomeView() }
