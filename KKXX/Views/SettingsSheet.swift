import SwiftUI
import CoreTransferable

struct JSONFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .json) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            JSONFile(url: received.file)
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var confirmLogout = false

    var body: some View {
        Group {
            if #available(iOS 16.4, *) {
                main.presentationDetents([.medium, .large])
            } else {
                main
            }
        }
    }

    private var main: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    if settings.isLoggedIn {
                        LabeledContent("登录账号", value: settings.userEmail.isEmpty ? "-" : settings.userEmail)
                        Button("退出登录", role: .destructive) { confirmLogout = true }
                    } else if settings.skipLogin {
                        LabeledContent("当前状态", value: "未登录，仅本地使用")
                        NavigationLink("登录 / 注册账号") { AuthView() }
                    } else {
                        NavigationLink("登录 / 注册账号") { AuthView() }
                    }
                }

                Section("外观") {
                    Picker("主题", selection: $settings.theme) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section("安全") {
                    Toggle("指纹 / 面容解锁", isOn: $settings.fingerprintLock)
                }

                Section("数据") {
                    if let url = exportURL {
                        ShareLink(item: JSONFile(url: url), preview: SharePreview("KKXX 本地数据备份")) {
                            Label("导出本地数据备份", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("关于") {
                    LabeledContent("应用", value: "KKXX")
                    LabeledContent("版本", value: "1.1.0")
                    LabeledContent("数据存储", value: "本地存储，登录后自动备份")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .confirmationDialog("退出登录？", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("退出登录并清除本地数据", role: .destructive) { store.logout() }
                Button("取消", role: .cancel) {}
            }
            .onAppear { exportURL = store.exportLocalJSON() }
        }
    }
}

#Preview { SettingsSheet() }
