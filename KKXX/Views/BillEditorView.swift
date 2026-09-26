import SwiftUI

struct BillEditorView: View {
    @EnvironmentObject var store: LocalStore
    @Environment(\.dismiss) private var dismiss

    @State private var bill: Bill
    @State private var amountText = ""

    private let categories = ["餐饮", "交通", "购物", "居住", "娱乐", "医疗", "工资", "理财", "其他"]

    init(bill: Bill) {
        _bill = State(initialValue: bill)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Picker("类型", selection: $bill.type) {
                        Text("支出").tag("expense")
                        Text("收入").tag("income")
                    }
                    .pickerStyle(.segmented)
                }
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }
                Section("分类") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { c in
                                Button {
                                    bill.category = bill.category == c ? "" : c
                                } label: {
                                    Text(c)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(bill.category == c ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    TextField("或自定义分类", text: $bill.category)
                }
                Section("备注") {
                    TextField("备注（可选）", text: $bill.remark)
                }
                Section("日期") {
                    DatePicker("账单日期", selection: bindingDate, displayedComponents: [.date])
                }
                Section {
                    if store.bills.contains(where: { $0.id == bill.id }) {
                        Button("删除账单", role: .destructive) {
                            store.softDeleteBill(id: bill.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(bill.amount == 0 ? "记一笔" : "编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                if bill.amount > 0 { amountText = String(format: "%.2f", bill.amount) }
            }
        }
    }

    private var bindingDate: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: TimeInterval(bill.billDate) / 1000) },
            set: { bill.billDate = Int64($0.timeIntervalSince1970 * 1000) }
        )
    }

    private func save() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: "")), amount > 0 else { return }
        bill.amount = amount
        store.upsert(bill)
        dismiss()
    }
}
