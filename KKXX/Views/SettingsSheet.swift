import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

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
                    HStack(spacing: 14) {
                        IconBadge(symbol: "person.crop.circle.fill", color: brandGreen, size: 44, corner: 13)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(settings.isLoggedIn ? (settings.userEmail.isEmpty ? "已登录" : settings.userEmail) : "未登录")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(settings.isLoggedIn ? "数据云端同步，跟随账号" : "登录后数据自动跟随账号")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if settings.isLoggedIn {
                            Button("退出", role: .destructive) { confirmLogout = true }
                                .font(.subheadline)
                        } else {
                            NavigationLink("登录 / 注册") { AuthView() }
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("外观") {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "paintbrush.fill", color: .blue, size: 28, corner: 8)
                        Picker("主题", selection: $settings.theme) {
                            Text("跟随系统").tag("system")
                            Text("浅色").tag("light")
                            Text("深色").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("安全") {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "faceid", color: .purple, size: 28, corner: 8)
                        Toggle("指纹 / 面容解锁", isOn: $settings.fingerprintLock)
                    }
                }

                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.16, green: 0.85, blue: 0.48), Color(red: 0.03, green: 0.65, blue: 0.35)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 44, height: 44)
                            Text("KX")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("KKXX")
                                .font(.subheadline.weight(.semibold))
                            Text("版本 1.1.0 · 数据云端保存，跟随账号")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
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
                Button("退出登录", role: .destructive) { store.logout() }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

#Preview { SettingsSheet() }
