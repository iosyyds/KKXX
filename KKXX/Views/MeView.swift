import SwiftUI
import PhotosUI

/// 「我的」Tab：个人中心（头像/昵称/数据/设置/退出）
struct MeView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings

    @State private var confirmLogout = false
    @State private var exiting = false

    private var noteCount: Int { store.notes.filter { !$0.deleted }.count }
    private var openTodoCount: Int { store.todos.filter { !$0.deleted && !$0.done }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { ProfileEditView() } label: {
                        HStack(spacing: 14) {
                            avatarImage(size: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settings.nickname.isEmpty ? "未设置昵称" : settings.nickname)
                                    .font(.headline)
                                Text(settings.userEmail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = settings.myKxNumber
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "number")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                            Text("KX号：\(settings.myKxNumber)")
                                .font(.subheadline)
                            Spacer()
                            if !settings.myKxNumber.isEmpty {
                                Image(systemName: "doc.on.doc").font(.footnote).foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    NavigationLink { FriendsListView() } label: {
                        Label("好友", systemImage: "person.2")
                    }
                }

                Section("我的数据") {
                    HStack(spacing: 0) {
                        dataCell("\(noteCount)", "笔记")
                        divider
                        dataCell("\(openTodoCount)", "待办")
                        divider
                        dataCell("\(store.bills.filter { !$0.deleted }.count)", "账单")
                        divider
                        dataCell("\(store.medboxes.filter { !$0.deleted }.count)", "药品")
                    }
                    NavigationLink { StatsView() } label: {
                        Label("数据总览", systemImage: "chart.pie")
                    }
                    HStack {
                        Label(store.syncStatus, systemImage: store.isSyncing ? "arrow.triangle.2.circlepath" : "cloud")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            Task { await store.syncNow(mode: .normal) }
                        } label: {
                            Text("立即同步")
                                .font(.footnote.weight(.medium))
                        }
                    }
                }

                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.16, green: 0.85, blue: 0.48), Color(red: 0.03, green: 0.65, blue: 0.35)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 46, height: 46)
                            Text("KX")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("KKXX")
                                .font(.subheadline.weight(.semibold))
                            Text("版本 \((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0") · 数据云端保存，跟随账号")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button(role: .destructive) {
                        startLogout()
                    } label: {
                        HStack {
                            Spacer()
                            if exiting {
                                ProgressView()
                            } else {
                                Text("退出登录")
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .task {
                guard settings.isLoggedIn else { return }
                if let p = try? await SyncService().fetchProfile(settings: settings) {
                    settings.nickname = p.nickname
                    if !p.avatar.isEmpty, let d = Data(base64Encoded: p.avatar) {
                        settings.avatarData = d
                    }
                }
                if let me = try? await SyncService().myKx(settings: settings) {
                    settings.myKxNumber = (me["kx"] as? String) ?? ""
                }
            }
            .confirmationDialog(store.pendingCount > 0
                                ? "还有 \(store.pendingCount) 条数据未同步到云端，退出后可能丢失。仍要退出？"
                                : "退出登录？",
                                isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) { store.logout() }
                Button("取消", role: .cancel) {}
            }
            .disabled(exiting)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 32)
    }

    private func dataCell(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func avatarImage(size: CGFloat) -> some View {
        if let img = UIImage(data: settings.avatarData) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        } else {
            Circle()
                .fill(brandGreen.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.38))
                        .foregroundColor(brandGreen)
                )
        }
    }

    private func startLogout() {
        exiting = true
        Task {
            await store.syncBeforeLogout()
            exiting = false
            if store.pendingCount > 0 {
                confirmLogout = true
            } else {
                store.logout()
            }
        }
    }
}

/// 个人资料编辑：头像（相册）+ 昵称
struct ProfileEditView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var nickname = ""
    @State private var saving = false
    @State private var saveError = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        avatarEditor
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)

            Section("昵称") {
                TextField("输入昵称", text: $nickname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("账号") {
                LabeledContent("邮箱", value: settings.userEmail)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "保存中…" : "完成") {
                    let nick = nickname.trimmingCharacters(in: .whitespaces)
                    settings.nickname = nick
                    // 头像太大则不传，避免 POST 超限；新选的头像已压到 128 JPEG 很小
                    var avatarB64 = settings.avatarData.base64EncodedString()
                    if avatarB64.count > 50000 { avatarB64 = "" }
                    let s = settings
                    saving = true
                    Task {
                        do {
                            try await SyncService().updateProfile(nickname: nick, avatarB64: avatarB64, settings: s)
                            saving = false
                            dismiss()
                        } catch {
                            saving = false
                            saveError = (error as NSError).localizedDescription
                        }
                    }
                }.fontWeight(.semibold).disabled(saving)
            }
        }
        .alert("保存失败", isPresented: .constant(!saveError.isEmpty)) {
            Button("好", role: .cancel) { saveError = "" }
        } message: {
            Text(saveError)
        }
        .onAppear { nickname = settings.nickname }
        .onChange(of: pickerItem) { item in
            Task { await loadAvatar(item) }
        }
    }

    private var avatarEditor: some View {
        Group {
            if let img = UIImage(data: settings.avatarData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(brandGreen.opacity(0.15))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 38))
                            .foregroundColor(brandGreen)
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(brandGreen)
                .clipShape(Circle())
                .offset(x: 4, y: 4)
        }
    }

    private func loadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            let resized = img.preparingThumbnail(of: CGSize(width: 128, height: 128)) ?? img
            settings.avatarData = (resized.jpegData(compressionQuality: 0.5) ?? data)
        }
    }
}

#Preview { MeView() }
