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
                HStack(spacing: 12) {
                    statCard("连续", "\(streak) 天", .orange, "flame.fill")
                    statCard("本月", "\(checkedDates.filter { $0.hasPrefix(monthPrefix) }.count) 次", .green, "calendar.badge.checkmark")
                    statCard("累计", "\(checkedDates.count) 次", .blue, "rosette")
                }
                .padding(.horizontal)

                // 日历卡片
                VStack(spacing: 10) {
                    HStack {
                        Button { prev() } label: {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 34, height: 34)
                                .background(Color(uiColor: .systemGroupedBackground))
                                .clipShape(Circle())
                        }
                        Text(monthLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        Button { next() } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 34, height: 34)
                                .background(Color(uiColor: .systemGroupedBackground))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 8)

                    let days = ["一", "二", "三", "四", "五", "六", "日"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(days, id: \.self) { d in
                            Text(d)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        ForEach(0..<leadingBlanks, id: \.self) { _ in
                            Color.clear.frame(height: 44)
                        }
                        ForEach(dayNumbers, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
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

    private func statCard(_ label: String, _ value: String, _ color: Color, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            IconBadge(symbol: symbol, color: color, size: 32, corner: 10)
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundColor(isToday ? Color.accentColor : Color.primary)
                ZStack {
                    Circle()
                        .fill(checked ? brandGreen : Color(.systemGray5).opacity(0.5))
                        .frame(width: 22, height: 22)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isToday ? Color.accentColor.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func prev() { month = calendar.date(byAdding: .month, value: -1, to: month) ?? month }
    private func next() { month = calendar.date(byAdding: .month, value: 1, to: month) ?? month }
}

#Preview { CheckinView() }
