import SwiftUI

/// 品牌主色：微信绿
let brandGreen = Color(red: 0.07, green: 0.76, blue: 0.40)

/// 彩色圆角图标底（全局统一组件）
struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 42
    var corner: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(color.opacity(0.14))
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

/// 空状态占位（精致版）
struct EmptyHint: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = brandGreen

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

/// 标签小胶囊
struct TagChip: View {
    let text: String
    var color: Color = brandGreen

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

/// 金额格式化
func yuan(_ v: Double) -> String {
    String(format: "%@%.2f", v < 0 ? "-¥" : "¥", abs(v))
}
