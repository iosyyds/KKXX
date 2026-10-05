import SwiftUI

/// 「我的」Tab 页面：账号 / 外观 / 安全 / 关于
struct MeView: View {
    @EnvironmentObject var store: LocalStore
    @EnvironmentObject var settings: AppSettings

    @State private var confirmLogout = false
    @State private var exiting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "person.crop.circle.fill", color: brandGreen, size: 50, corner: 15)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.isLoggedIn ? (settings.userEmail.isEmpty ? "已登录" : settings.userEmail) : "未登录")
                                .font(.headline)
                                .lineLimit(1)
                            Text(settings.isLoggedIn ? "数据云端同步，跟随账号" : "登录后数据自动跟随账号")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if settings.isLoggedIn {
                            if exiting {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("同步中…")
                                }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            } else {
                                Button("退出", role: .destructive) { startLogout() }
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("外观") {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "paintbrush.fill", color: .blue, size: 30, corner: 9)
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
                        IconBadge(symbol: "faceid", color: .purple, size: 30, corner: 9)
                        Toggle("指纹 / 面容解锁", isOn: $settings.fingerprintLock)
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
                            Text("版本 1.1.0 · 数据云端保存，跟随账号")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
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

    /// 退出流程：先补传，成功直接退出；仍有未同步才弹确认
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

#Preview { MeView() }
