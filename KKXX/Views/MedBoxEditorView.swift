import SwiftUI
import PhotosUI

/// 药盒：药品编辑（新建 / 编辑）
struct MedBoxEditorView: View {
    @EnvironmentObject var store: LocalStore
    @Environment(\.dismiss) private var dismiss

    @State private var item: MedBoxItem
    @State private var tagText = ""
    @State private var newPhotos: [PhotosPickerItem] = []
    @State private var busy = false
    @State private var hasExpiry = false
    @State private var expiryDate = Date()

    init(item: MedBoxItem) {
        _item = State(initialValue: item)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("药品名称") {
                    TextField("如：布洛芬缓释胶囊", text: $item.name)
                }

                Section("照片（\(item.images.count)）") {
                    if !item.images.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(item.images, id: \.self) { uri in
                                if let img = image(from: uri) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                item.images.removeAll { $0 == uri }
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
                    PhotosPicker(selection: $newPhotos, maxSelectionCount: 4, matching: .images) {
                        Label("从相册添加药盒照片", systemImage: "photo.on.rectangle.angled")
                    }
                    if busy { ProgressView() }
                }

                Section("功效") {
                    TextEditor(text: $item.purpose)
                        .frame(minHeight: 70)
                }
                Section("用法用量") {
                    TextEditor(text: $item.usage)
                        .frame(minHeight: 70)
                }
                Section("禁忌 / 注意事项") {
                    TextEditor(text: $item.contraindication)
                        .frame(minHeight: 70)
                }

                Section("保质期") {
                    Toggle("设置保质期", isOn: $hasExpiry.animation())
                    if hasExpiry {
                        DatePicker("到期日期", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("厂家") {
                    TextField("生产厂家（选填）", text: $item.manufacturer)
                }
                Section("标签") {
                    TextField("多个标签用逗号分隔", text: $tagText)
                        .autocorrectionDisabled()
                }

                Section {
                    if store.medboxes.contains(where: { $0.id == item.id }) {
                        Button("删除药品", role: .destructive) {
                            store.softDeleteMedBox(id: item.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(item.name.isEmpty ? "记录药品" : "编辑药品")
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
                tagText = item.tags.joined(separator: ", ")
                if item.expiryDate > 0 {
                    hasExpiry = true
                    expiryDate = Date(timeIntervalSince1970: TimeInterval(item.expiryDate) / 1000)
                }
            }
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
        for it in items {
            if let data = try? await it.loadTransferable(type: Data.self) {
                item.images.append("data:image/jpeg;base64," + data.base64EncodedString())
            }
        }
        newPhotos = []
    }

    private func save() {
        item.tags = tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        item.expiryDate = hasExpiry ? Int64(expiryDate.timeIntervalSince1970 * 1000) : 0
        store.upsert(item)
        dismiss()
    }
}

#Preview { MedBoxEditorView(item: MedBoxItem()) }
