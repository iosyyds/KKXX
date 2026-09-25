import SwiftUI

struct TodosView: View {
    @EnvironmentObject var store: LocalStore
    @State private var editing: TodoItem?

    private var visible: [TodoItem] {
        store.todos.filter { !$0.deleted }.sorted {
            if $0.done != $1.done { return !$0.done }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                EmptyHint(icon: "checklist", title: "暂无待办", subtitle: "点右上角新增，或从首页 + 新建")
            } else {
                List {
                    ForEach(visible) { todo in
                        TodoRow(todo: todo) {
                            var t = todo
                            t.done.toggle()
                            store.upsert(t)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = todo }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.softDeleteTodo(id: todo.id) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("待办")
        .toolbar {
            Button { editing = TodoItem() } label: { Image(systemName: "plus") }
        }
        .sheet(item: $editing) { t in TodoEditorView(todo: t) }
    }
}

private struct TodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(todo.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(todo.done)
                    .foregroundStyle(todo.done ? Color.secondary : Color.primary)
                if todo.dueDate > 0 {
                    let overdue = !todo.done && todo.dueDate < nowMs()
                    Label(shortDate(todo.dueDate), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(overdue ? Color.red : Color.secondary)
                }
                if !todo.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(todo.tags.prefix(4), id: \.self) { TagChip(text: $0) }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview { TodosView() }
