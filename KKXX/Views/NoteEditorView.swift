import SwiftUI
import PhotosUI

struct NoteEditorView: View {
    @EnvironmentObject var store: LocalStore
    @Environment(\.dismiss) private var dismiss

    @State private var note: Note
    @State private var tagText = ""
    @State private var newPhotos: [PhotosPickerItem] = []
    @State private var busy = false

    init(note: Note) {
        _note = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("标题", text: $note.title)
                }
                Section("内容") {
                    TextEditor(text: $note.content)
                        .frame(minHeight: 150)
                }
                Section("图片（\(note.images.count)）") {
                    if !note.images.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(note.images, id: \.self) { uri in
                                if let img = image(from: uri) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                note.images.removeAll { $0 == uri }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.55)))
                                            }
                                            .padding(3)
                                        }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    PhotosPicker(selection: $newPhotos, maxSelectionCount: 6, matching: .images) {
                        Label("从相册添加", systemImage: "photo.on.rectangle.angled")
                    }
                    if busy { ProgressView() }
                }
                Section("标签") {
                    TextField("多个标签用逗号分隔", text: $tagText)
                        .autocorrectionDisabled()
                }
                Section {
                    if store.notes.contains(where: { $0.id == note.id }) {
                        Button("删除笔记", role: .destructive) {
                            store.softDeleteNote(id: note.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(note.title.isEmpty ? "新笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear { tagText = note.tags.joined(separator: ", ") }
            .onChange(of: newPhotos) { items in
                Task { await loadPhotos(items) }
            }
        }
    }

    private func image(from uri: String) -> UIImage? {
        guard let idx = uri.firstIndex(of: ",") else { return nil }
        let b64 = String(uri[uri.index(after: idx)...])
        guard let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        busy = true
        defer { busy = false }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                note.images.append("data:image/jpeg;base64," + data.base64EncodedString())
            }
        }
        newPhotos = []
    }

    private func save() {
        note.tags = tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.upsert(note)
        dismiss()
    }
}
