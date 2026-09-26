import SwiftUI

struct BillsView: View {
    @EnvironmentObject var store: LocalStore
    @State private var typeFilter = 0     // 0 全部 1 支出 2 收入
    @State private var month = Date()
    @State private var editing: Bill?

    private var calendar: Calendar { var c = Calendar.current; c.locale = Locale(identifier: "zh_CN"); return c }

    private var visible: [Bill] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let end = calendar.date(byAdding: DateComponents(month: 1), to: start) ?? start
        return store.bills
            .filter { !$0.deleted }
            .filter { $0.billDate >= Int64(start.timeIntervalSince1970 * 1000) && $0.billDate < Int64(end.timeIntervalSince1970 * 1000) }
            .filter { typeFilter == 0 || (typeFilter == 1 ? $0.type == "expense" : $0.type == "income") }
            .sorted { $0.billDate > $1.billDate }
    }

    private var income: Double { visible.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount } }
    private var expense: Double { visible.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        Group {
            if store.bills.filter({ !$0.deleted }).isEmpty {
                EmptyHint(icon: "yensign.circle", title: "还没有账单", subtitle: "点右上角或首页 + 记一笔", color: brandGreen)
            } else {
                List {
                    Section {
                        HStack(spacing: 12) {
                            StatCell(label: "收入", value: yuan(income), color: .green, symbol: "arrow.down.circle.fill")
                            StatCell(label: "支出", value: yuan(expense), color: .orange, symbol: "arrow.up.circle.fill")
                            StatCell(label: "结余", value: yuan(income - expense), color: .primary, symbol: "equal.circle.fill")
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)

                    Section("明细") {
                        ForEach(visible) { bill in
                            Button { editing = bill } label: { BillRow(bill: bill) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { store.softDeleteBill(id: bill.id) } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("记账")
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                Picker("", selection: $typeFilter) {
                    Text("全部").tag(0)
                    Text("支出").tag(1)
                    Text("收入").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                HStack {
                    Button { prevMonth() } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    Text(monthLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    Button { nextMonth() } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 6)
            .background(.bar)
        }
        .toolbar {
            Button { editing = Bill() } label: { Image(systemName: "plus") }
        }
        .sheet(item: $editing) { b in BillEditorView(bill: b) }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: month)
    }

    private func prevMonth() { month = calendar.date(byAdding: .month, value: -1, to: month) ?? month }
    private func nextMonth() { month = calendar.date(byAdding: .month, value: 1, to: month) ?? month }
}

private struct StatCell: View {
    let label: String
    let value: String
    let color: Color
    let symbol: String

    var body: some View {
        VStack(spacing: 6) {
            IconBadge(symbol: symbol, color: color, size: 30, corner: 9)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct BillRow: View {
    let bill: Bill
    var body: some View {
        HStack(spacing: 14) {
            IconBadge(
                symbol: bill.type == "income" ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                color: bill.type == "income" ? .green : .orange,
                size: 42, corner: 12
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.category.isEmpty ? (bill.remark.isEmpty ? "未分类" : bill.remark) : bill.category)
                    .font(.subheadline.weight(.medium))
                Text(bill.remark.isEmpty ? shortDate(bill.billDate) : bill.remark)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            (Text(bill.type == "income" ? "+" : "-")
                .foregroundColor(bill.type == "income" ? Color.green : Color.orange)
             + Text(yuan(bill.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(bill.type == "income" ? Color.green : Color.orange))
        }
        .padding(.vertical, 4)
    }
}

#Preview { BillsView() }
