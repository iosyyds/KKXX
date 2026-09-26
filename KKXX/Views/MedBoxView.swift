import SwiftUI

/// 药盒：家庭常备药记录（列表 + 筛选 + 过期状态）
struct MedBoxView: View {
    @EnvironmentObject var store: LocalStore

    @State private var filter: MedFilter = .all
    @State private var search = ""
    @State private var editing: MedBoxItem?
    @State private var creating = false

    private enum MedFilter: String, CaseIterable, Identifiable {
        case all, normal, expiring, expired
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "全部"
            case .normal: return "正常"
            case .expiring: return "临期"
            case .expired: return "已过期"
            }
        }
    }

    private var allActive: [MedBoxItem] {
        store.medboxes.filter { !$0.deleted }
    }

    private var visible: [MedBoxItem] {
        let kw = search.trimmingCharacters(in: .whitespaces)
        return allActive.filter { m in
            switch filter {
            case .all: break
            case .normal: guard m.expiryStatus == .normal else { return false }
            case .expiring: guard m.expiryStatus == .expiring else { return false }
            case .expired: guard m.expiryStatus == .expired else { return false }
            }
            if !kw.isEmpty {
                let hit = m.name.localizedCaseInsensitiveContains(kw)
                    || m.purpose.localizedCaseInsensitiveContains(kw)
                    || m.usage.localizedCaseInsensitiveContains(kw)
                    || m.manufacturer.localizedCaseInsensitiveContains(kw)
                guard hit else { return false }
            }
            return true
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func count(_ f: MedFilter) -> Int {
        allActive.filter { m in
            switch f {
            case .all: return true
            case .normal: return m.expiryStatus == .normal
            case .expiring: return m.expiryStatus == .expiring
            case .expired: return m.expiryStatus == .expired
            }
        }.count
    }

    var body: some View {
        Group {
            if allActive.isEmpty {
                EmptyHint(icon: "pills", title: "药盒还是空的", subtitle: "记录家里的常备药，到期自动提醒", color: medRed)
            } else {
                List {
                    filterBar
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if visible.isEmpty {
                        HStack {
                            Spacer()
                            Text("没有符合条件的药品")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 30)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(visible) { m in
                            row(m)
                                .listRowSeparator(.hidden)
                                .listRowBackground(
                                    Color(uiColor: .secondarySystemGroupedBackground)
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { store.softDeleteMedBox(id: m.id) }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .onTapGesture { editing = m }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索药名、功效…")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("药盒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundColor(medRed)
                }
            }
        }
        .sheet(item: $editing) { item in
            MedBoxEditorView(item: item)
        }
        .sheet(isPresented: $creating) {
            MedBoxEditorView(item: MedBoxItem())
        }
    }

    /// 顶部筛选：全部/正常/临期/已过期（带数量）
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MedFilter.allCases) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                    } label: {
                        HStack(spacing: 5) {
                            Text(f.label)
                                .font(.subheadline.weight(.medium))
                            Text("\(count(f))")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                filter == f
                                    ? medRed.opacity(0.14)
                                    : Color(uiColor: .secondarySystemGroupedBackground)
                            )
                        )
                        .foregroundColor(filter == f ? medRed : .primary)
                        .overlay(
                            Capsule().strokeBorder(
                                filter == f ? medRed.opacity(0.35) : Color.clear,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func row(_ m: MedBoxItem) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: "pills", color: medRed, size: 46, corner: 13)

            VStack(alignment: .leading, spacing: 5) {
                Text(m.name.isEmpty ? "（未命名药品）" : m.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if !m.purpose.isEmpty {
                    Text(m.purpose)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    statusChip(m.expiryStatus)
                    if m.expiryDate > 0 {
                        Text(m.expiryText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if !m.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(m.tags.prefix(3), id: \.self) { t in
                            TagChip(text: t, color: medRed)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            if let first = m.images.first, let img = image(from: first) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 6)
    }

    private func statusChip(_ s: MedBoxItem.ExpiryStatus) -> some View {
        Text(s.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(s.color.opacity(0.12))
            .foregroundColor(s.color)
            .clipShape(Capsule())
    }

    private func image(from uri: String) -> UIImage? {
        guard let idx = uri.firstIndex(of: ",") else { return nil }
        let b64 = String(uri[uri.index(after: idx)...])
        guard let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }
}

/// 药盒主题色：红
let medRed = Color(red: 0.95, green: 0.30, blue: 0.40)

#Preview { MedBoxView() }
