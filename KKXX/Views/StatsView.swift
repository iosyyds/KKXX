import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: LocalStore

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = Locale(identifier: "zh_CN")
        return c
    }

    private var visibleNotes: [Note] { store.notes.filter { !$0.deleted } }
    private var visibleTodos: [TodoItem] { store.todos.filter { !$0.deleted } }
    private var visibleBills: [Bill] { store.bills.filter { !$0.deleted } }
    private var visibleCheckins: [Checkin] { store.checkins.filter { !$0.deleted } }

    private var monthIncome: Double {
        monthBills.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
    }
    private var monthExpense: Double {
        monthBills.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
    }
    private var monthBills: [Bill] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return visibleBills.filter { $0.billDate >= Int64(start.timeIntervalSince1970 * 1000) }
    }

    private var streak: Int {
        var day = calendar.startOfDay(for: Date())
        let dates = Set(visibleCheckins.map(\.date))
        func str(_ d: Date) -> String {
            let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }
        if !dates.contains(str(day)) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var n = 0
        while dates.contains(str(day)) {
            n += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return n
    }

    private var monthSeries: [(label: String, value: Double)] {
        let now = Date()
        var result: [(String, Double)] = []
        for i in stride(from: 5, through: 0, by: -1) {
            let d = calendar.date(byAdding: .month, value: -i, to: now) ?? now
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? d
            let end = calendar.date(byAdding: DateComponents(month: 1), to: start) ?? start
            let sum = visibleBills
                .filter { $0.type == "expense" }
                .filter { $0.billDate >= Int64(start.timeIntervalSince1970 * 1000) && $0.billDate < Int64(end.timeIntervalSince1970 * 1000) }
                .reduce(0) { $0 + $1.amount }
            let f = DateFormatter(); f.dateFormat = "M月"
            result.append((f.string(from: d), sum))
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    card("笔记", "\(visibleNotes.count)", .blue, "note.text")
                    card("待办", "\(visibleTodos.filter { $0.done }.count)/\(visibleTodos.count)", .orange, "checklist")
                    card("本月收入", yuan(monthIncome), .green, "arrow.down.circle.fill")
                    card("本月支出", yuan(monthExpense), .red, "arrow.up.circle.fill")
                    card("打卡连续", "\(streak) 天", .purple, "flame.fill")
                    card("打卡累计", "\(visibleCheckins.count) 次", .teal, "calendar")
                }
                .padding(.horizontal)

                // 近 6 月支出柱状图
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("近 6 月支出")
                            .font(.headline)
                        Spacer()
                        Text("单位：元")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    let maxV = max(monthSeries.map(\.value).max() ?? 1, 1)
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(Array(monthSeries.enumerated()), id: \.offset) { _, item in
                            VStack(spacing: 6) {
                                Text(item.value > 0 ? String(format: "%.0f", item.value) : "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.85), Color.red.opacity(0.55)],
                                            startPoint: .bottom, endPoint: .top
                                        )
                                    )
                                    .frame(height: max(4, CGFloat(item.value / maxV) * 88))
                                Text(item.label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 128)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)

                // 收支小结
                VStack(alignment: .leading, spacing: 10) {
                    Text("本月收支")
                        .font(.headline)
                    HStack(spacing: 12) {
                        miniStat("收入", yuan(monthIncome), .green)
                        miniStat("支出", yuan(monthExpense), .orange)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("数据总览")
    }

    private func card(_ label: String, _ value: String, _ color: Color, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            IconBadge(symbol: symbol, color: color, size: 38, corner: 11)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview { StatsView() }
