import SwiftUI

/// 小工具：简单四则计算器（iOS 计算器风格）
struct ToolsView: View {
    @State private var display = "0"
    @State private var accumulator: Double?
    @State private var pendingOp: String?
    @State private var isTyping = false

    private let rows: [[String]] = [
        ["C", "⌫", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["±", "0", ".", "="]
    ]

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 16)
            Text(display)
                .font(.system(size: 52, weight: .light, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 26)

            VStack(spacing: 10) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("小工具")
        .toolbar {
            Text("简单计算器").font(.caption)
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        Button {
            tap(key)
        } label: {
            Text(key)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(keyColor(key))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(buttonColor(key))
                .clipShape(Circle())
                .shadow(color: buttonColor(key) == Color(.systemGray5) ? Color.black.opacity(0.05) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func keyColor(_ key: String) -> Color {
        switch key {
        case "C": return .red
        case "=": return .white
        case "÷", "×", "−", "+", "%": return .orange
        default: return .primary
        }
    }

    private func buttonColor(_ key: String) -> Color {
        switch key {
        case "=":
            return brandGreen
        case "÷", "×", "−", "+", "%", "C": return Color(.systemGray5)
        default: return Color(.secondarySystemGroupedBackground)
        }
    }

    private var displayValue: Double {
        Double(display) ?? 0
    }

    private func tap(_ key: String) {
        switch key {
        case "C":
            display = "0"; accumulator = nil; pendingOp = nil; isTyping = false
        case "⌫":
            if isTyping {
                if display.count > 1 { display.removeLast() } else { display = "0"; isTyping = false }
            }
        case "±":
            if display != "0" {
                display = display.hasPrefix("-") ? String(display.dropFirst()) : "-" + display
            }
        case "%":
            let v = displayValue / 100
            display = format(v); isTyping = false
        case ".":
            if isTyping {
                if !display.contains(".") { display += "." }
            } else {
                display = "0."; isTyping = true
            }
        case "+", "−", "×", "÷":
            applyPending()
            accumulator = displayValue
            pendingOp = key
            isTyping = false
        case "=":
            applyPending()
            accumulator = nil
            pendingOp = nil
            isTyping = false
        default: // 数字
            if isTyping {
                if display == "0" { display = key } else { display += key }
            } else {
                display = key
                isTyping = true
            }
        }
    }

    private func applyPending() {
        guard let acc = accumulator, let op = pendingOp else { return }
        let rhs = displayValue
        var result: Double
        switch op {
        case "+": result = acc + rhs
        case "−": result = acc - rhs
        case "×": result = acc * rhs
        case "÷": result = rhs == 0 ? 0 : acc / rhs
        default: result = rhs
        }
        display = format(result)
    }

    private func format(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1e15 {
            return String(Int(v))
        }
        return String(format: "%.8f", v)
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
}

#Preview { ToolsView() }
