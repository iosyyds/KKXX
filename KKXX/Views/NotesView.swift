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
                EmptyHint(icon: "note.text", title: "暂无笔记", subtitle: "点右上角新建")
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
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title.isEmpty ? "（无标题）" : note.title)
                .font(.headline)
            if !note.content.isEmpty {
                Text(note.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                if !note.images.isEmpty {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(note.tags.prefix(4), id: \.self) { TagChip(text: $0) }
                Spacer()
                Text(shortTime(note.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview { NotesView() }
