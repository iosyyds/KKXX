import SwiftUI

struct CheckinView: View {
    @EnvironmentObject var store: LocalStore
    @State private var month = Date()

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = Locale(identifier: "zh_CN")
        c.firstWeekday = 2   // 周一开始
        return c
    }

    private var checkedDates: Set<String> {
        Set(store.checkins.filter { !$0.deleted }.map(\.date))
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: month)
    }

    private var streak: Int {
        var day = calendar.startOfDay(for: Date())
        if !checkedDates.contains(dayString(day)) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while checkedDates.contains(dayString(day)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    private func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func toggle(_ dateStr: String) {
        if let existing = store.checkins.first(where: { !$0.deleted && $0.date == dateStr }) {
            store.softDeleteCheckin(id: existing.id)
        } else {
            store.upsert(Checkin(date: dateStr))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计
                HStack {
                    statCard("连续", "\(streak) 天", .orange)
                    statCard("本月", "\(checkedDates.filter { $0.hasPrefix(monthPrefix) }.count) 次", .green)
                    statCard("累计", "\(checkedDates.count) 次", .blue)
                }

                // 日历卡片
                VStack(spacing: 8) {
                    HStack {
                        Button { prev() } label: { Image(systemName: "chevron.left") }
                        Text(monthLabel).font(.headline).frame(maxWidth: .infinity)
                        Button { next() } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(.horizontal, 8)

                    let days = ["一", "二", "三", "四", "五", "六", "日"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(days, id: \.self) { d in
                            Text(d).font(.caption).foregroundColor(.secondary)
                        }
                        ForEach(0..<leadingBlanks, id: \.self) { _ in
                            Color.clear.frame(height: 40)
                        }
                        ForEach(dayNumbers, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("习惯打卡")
        .toolbar {
            Button { month = Date() } label: { Image(systemName: "calendar.badge.clock") }
        }
    }

    private var monthPrefix: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM"
        return f.string(from: month)
    }

    private func statCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 4)
    }

    private var leadingBlanks: Int {
        let comp = calendar.dateComponents([.weekday], from: monthStart)
        let wd = comp.weekday ?? 1
        return (wd + 5) % 7   // 周一=0
    }

    private var dayNumbers: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        return Array(range)
    }

    private func dayCell(_ day: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
        let dateStr = dayString(date)
        let checked = checkedDates.contains(dateStr)
        let isToday = calendar.isDateInToday(date)

        return Button {
            toggle(dateStr)
        } label: {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundColor(isToday ? Color.accentColor : Color.primary)
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(checked ? Color.green : Color(.systemGray4))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func prev() { month = calendar.date(byAdding: .month, value: -1, to: month) ?? month }
    private func next() { month = calendar.date(byAdding: .month, value: 1, to: month) ?? month }
}

#Preview { CheckinView() }
