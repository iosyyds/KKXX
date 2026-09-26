import SwiftUI

/// 登录 / 注册页（多账号版）
/// 逻辑：服务器地址已内置（app.puaaa.cn）不显示给用户 → 注册或登录获取令牌 → 进入主界面；
/// 也可「暂不登录」跳过（数据仅存本机，登录后以云端为准）。同步失败时自动检测服务器链接。
struct AuthView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: LocalStore

    enum Mode: String, CaseIterable {
        case login = "登录"
        case register = "注册"
    }

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                logo
                Text("KKXX · 多设备同步")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("模式", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    fieldRow("邮箱", text: $email, keyboard: .emailAddress, placeholder: "you@example.com")
                    Divider().padding(.leading, 44)
                    fieldRow("密码", text: $password, secure: true, placeholder: "至少 6 位")
                    if mode == .register {
                        Divider().padding(.leading, 44)
                        fieldRow("确认密码", text: $confirm, secure: true, placeholder: "再次输入密码")
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let e = errorMessage {
                    Text(e)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if busy {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: mode == .login ? "arrow.right.circle.fill" : "person.crop.circle.badge.plus")
                        }
                        Text(busy ? "请稍候…" : (mode == .login ? "登 录" : "注 册"))
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.85, blue: 0.48), Color(red: 0.03, green: 0.65, blue: 0.35)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(busy)

                Button {
                    settings.skipLogin = true
                } label: {
                    Text("暂不登录")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                }

                Text(mode == .login
                     ? "没有账号？切换到「注册」创建一个，登录后数据自动同步。"
                     : "数据保存在云端，登录后多设备自动同步，不同账号数据相互隔离。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.85, blue: 0.48), Color(red: 0.03, green: 0.65, blue: 0.35)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 92, height: 92)
                .shadow(color: Color(red: 0.03, green: 0.65, blue: 0.35).opacity(0.35), radius: 12, x: 0, y: 6)
            Text("KX")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.top, 32)
    }

    private func fieldRow(_ label: String, text: Binding<String>, secure: Bool = false,
                          keyboard: UIKeyboardType = .default, placeholder: String = "") -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 68, alignment: .leading)
            if secure {
                SecureField(placeholder, text: text)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: text)
                    .font(.subheadline)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func submit() async {
        errorMessage = nil
        let mail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let pass = password

        guard !settings.normalizedServerURL.isEmpty else { errorMessage = "服务初始化未完成，请重新打开应用"; return }
        guard mail.contains("@") && mail.contains(".") else { errorMessage = "邮箱格式不正确"; return }
        guard pass.count >= 6 else { errorMessage = "密码至少 6 位"; return }
        if mode == .register {
            guard pass == confirm else { errorMessage = "两次输入的密码不一致"; return }
        }

        busy = true
        defer { busy = false }
        do {
            let token: String
            if mode == .login {
                token = try await SyncService().login(email: mail, password: pass, settings: settings)
            } else {
                token = try await SyncService().register(email: mail, password: pass, settings: settings)
            }
            settings.authToken = token
            settings.userEmail = mail
            settings.skipLogin = false
            // 登录成功后同步：先上传本机变更（如有），再以服务器数据合并（数据跟随账号）
            await store.syncNow(mode: .normal)
        } catch {
            // 失败时先检测服务器链接，区分「链接失败」与「账号/业务错误」
            let reachable = (try? await SyncService().verify(settings: settings)) ?? false
            if reachable {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "无法连接服务器（链接失败），请检查网络后重试"
            }
        }
    }
}

#Preview { AuthView() }
