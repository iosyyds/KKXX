import SwiftUI

struct NotesView: View {
    @EnvironmentObject var store: LocalStore
    @State private var editing: Note?

    private var visible: [Note] {
        store.notes.filter { !$0.deleted }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                EmptyHint(icon: "note.text", title: "暂无笔记", subtitle: "点右上角新建，随手记录灵感", color: .blue)
            } else {
                List {
                    ForEach(visible) { note in
                        Button { editing = note } label: { NoteRow(note: note) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.softDeleteNote(id: note.id) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("笔记")
        .toolbar {
            Button { editing = Note() } label: { Image(systemName: "square.and.pencil") }
        }
        .sheet(item: $editing) { note in NoteEditorView(note: note) }
    }
}

private struct NoteRow: View {
    let note: Note
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(symbol: "note.text", color: .blue, size: 44, corner: 12)
            VStack(alignment: .leading, spacing: 5) {
                Text(note.title.isEmpty ? "（无标题）" : note.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                if !note.content.isEmpty {
                    Text(note.snippet)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    if !note.images.isEmpty {
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    ForEach(note.tags.prefix(4), id: \.self) { TagChip(text: $0) }
                    Spacer(minLength: 4)
                    Text(shortTime(note.updatedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview { NotesView() }
