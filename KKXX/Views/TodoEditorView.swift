import SwiftUI

struct TodoEditorView: View {
    @EnvironmentObject var store: LocalStore
    @Environment(\.dismiss) private var dismiss

    @State private var todo: TodoItem
    @State private var tagText = ""
    @State private var hasDue = false
    @State private var due = Date()

    init(todo: TodoItem) {
        _todo = State(initialValue: todo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("待办内容", text: $todo.title)
                }
                Section("截止时间") {
                    Toggle("设置截止时间", isOn: $hasDue)
                    if hasDue {
                        DatePicker("截止", selection: $due, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("标签") {
                    TextField("多个标签用逗号分隔", text: $tagText)
                        .autocorrectionDisabled()
                }
                Section {
                    if store.todos.contains(where: { $0.id == todo.id }) {
                        Button("删除待办", role: .destructive) {
                            store.softDeleteTodo(id: todo.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(todo.title.isEmpty ? "新待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                tagText = todo.tags.joined(separator: ", ")
                if todo.dueDate > 0 {
                    hasDue = true
                    due = Date(timeIntervalSince1970: TimeInterval(todo.dueDate) / 1000)
                }
            }
        }
    }

    private func save() {
        todo.dueDate = hasDue ? Int64(due.timeIntervalSince1970 * 1000) : 0
        todo.tags = tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.upsert(todo)
        dismiss()
    }
}
