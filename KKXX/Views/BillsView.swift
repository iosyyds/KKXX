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
                EmptyHint(icon: "yensign.circle", title: "还没有账单", subtitle: "点右上角 + 记一笔", color: brandGreen)
            } else {
                List {
                    // 本月概览大卡片
                    Section {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("本月支出")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Text(yuan(expense))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("本月收入")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Text(yuan(income))
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .foregroundColor(.green)
                                }
                            }
                            Divider()
                            HStack {
                                Label("结余 \(yuan(income - expense))", systemImage: "equal.circle.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(income - expense >= 0 ? .primary : .red)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowSeparator(.hidden)

                    // 筛选分段 + 月份
                    Section {
                        Picker("", selection: $typeFilter) {
                            Text("全部").tag(0)
                            Text("支出").tag(1)
                            Text("收入").tag(2)
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Button { prevMonth() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 32, height: 32)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(Circle())
                            }
                            Text(monthLabel)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                            Button { nextMonth() } label: {
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 32, height: 32)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .listRowSeparator(.hidden)

                    // 明细
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
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 110) }
            }
        }
        .navigationTitle("记账")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { editing = Bill() } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
            }
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
