import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings

    @State private var serverInput = ""
    @State private var checking = false
    @State private var checkResult: String?

    var body: some View {
        Form {
            Section {
                TextField("服务器地址", text: $serverInput)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text("例：http://app.puaaa.cn")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("服务器")
            } footer: {
                Text("填写你部署后台的网址，App 会自动把数据同步到该服务器，无需任何密钥。")
            }

            Section("同步策略") {
                Toggle("Wi-Fi 下自动同步", isOn: $settings.autoSyncOnWifi)
                Toggle("启动 App 自动拉取", isOn: $settings.syncOnLaunch)
            }

            Section("手动同步") {
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
            }

            Section("状态") {
                LabeledContent("服务器", value: settings.normalizedServerURL.isEmpty ? "未配置" : settings.normalizedServerURL)
                LabeledContent("上次同步", value: shortTime(store.lastSyncTime))
                LabeledContent("待同步操作", value: "\(store.pendingCount)")
                LabeledContent("同步状态", value: store.syncStatus)

                Button {
                    Task { await check() }
                } label: {
                    Label(checking ? "检测中…" : "检测服务器连接", systemImage: "bolt.horizontal.circle")
                }
                .disabled(checking || !settings.isConfigured)

                if let r = checkResult {
                    Text(r)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("云同步")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            serverInput = settings.serverURL
        }
        .onChange(of: serverInput) { v in
            settings.serverURL = v.trimmingCharacters(in: .whitespaces)
        }
    }

    private func check() async {
        checking = true
        defer { checking = false }
        do {
            let ok = try await SyncService().verify(settings: settings)
            checkResult = ok ? "连接正常 ✓" : "服务器未就绪（请先完成后台安装）"
        } catch {
            checkResult = "连接失败：" + error.localizedDescription
        }
    }
}

#Preview { NavigationStack { SyncSettingsView() } }
