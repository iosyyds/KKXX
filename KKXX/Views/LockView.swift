import SwiftUI
import LocalAuthentication

struct LockView: View {
    @Binding var unlocked: Bool
    @State private var failed = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(brandGreen)
            Text("KKXX 已锁定")
                .font(.title2.weight(.semibold))
            Text("使用指纹或面容解锁后继续")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                authenticate()
            } label: {
                Label("解锁", systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            if failed {
                Text("解锁失败，请重试；若设备未设置生物识别，可在设置中关闭指纹锁")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear { authenticate() }
    }

    private func authenticate() {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            failed = true
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁 KKXX") { ok, _ in
            DispatchQueue.main.async {
                unlocked = ok
                if !ok { failed = true }
            }
        }
    }
}
