import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings

    @State private var serverInput = ""
    @State private var keyInput = ""
    @State private var verifying = false
    @State private var verifyResult: String?

    var body: some View {
        Form {
            Section("服务器") {
                TextField("后台地址", text: $serverInput)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("管理员密钥", text: $keyInput)
                    .autocorrectionDisabled()
            }
            Section("同步策略") {
                Toggle("Wi-Fi 下自动同步", isOn: $settings.autoSyncOnWifi)
                Toggle("启动 App 自动拉取", isOn: $settings.syncOnLaunch)
            }
            Section("操作") {
                Button {
                    Task { await store.syncNow(mode: .normal) }
                } label: {
                    Label(store.isSyncing ? "同步中…" : "立即同步", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isSyncing || !settings.isConfigured)

                Button("以云端覆盖本地") {
                    Task { await store.syncNow(mode: .pullOnly) }
                }
                .disabled(store.isSyncing || !settings.isConfigured)

                Button("以本地覆盖云端") {
                    Task { await store.syncNow(mode: .pushOnly) }
                }
                .disabled(store.isSyncing || !settings.isConfigured)

                Button {
                    Task { await verify() }
                } label: {
                    Label(verifying ? "校验中…" : "校验服务器连接", systemImage: "checkmark.shield")
                }
                .disabled(verifying)

                if let r = verifyResult {
                    Text(r).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("状态") {
                LabeledContent("服务器", value: settings.normalizedServerURL.isEmpty ? "未配置" : settings.normalizedServerURL)
                LabeledContent("上次同步", value: shortTime(store.lastSyncTime))
                LabeledContent("待同步操作", value: "\(store.pendingCount)")
                LabeledContent("同步状态", value: store.syncStatus)
            }
        }
        .navigationTitle("同步与设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            serverInput = settings.serverURL
            keyInput = settings.adminKey
        }
        .onChange(of: serverInput) { v in settings.serverURL = v.trimmingCharacters(in: .whitespaces) }
        .onChange(of: keyInput) { v in settings.adminKey = v.trimmingCharacters(in: .whitespaces) }
    }

    private func verify() async {
        verifying = true
        defer { verifying = false }
        do {
            let ok = try await SyncService().verify(settings: settings)
            verifyResult = ok ? "连接正常，密钥有效 ✓" : "密钥无效或服务器未就绪"
        } catch {
            verifyResult = "连接失败：" + error.localizedDescription
        }
    }
}

#Preview { NavigationStack { SyncSettingsView() } }
