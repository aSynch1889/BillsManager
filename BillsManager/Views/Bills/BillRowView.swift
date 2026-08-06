import SwiftUI
import SwiftData

struct BillRowView: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @State private var persistenceError: String?
    @State private var showingMarkPaidSheet: Bool = false
    @State private var showingUnpayConfirm: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(bill.category?.color ?? .blue)
                    .frame(width: 44, height: 44)

                Image(systemName: bill.category?.iconName ?? "doc.text.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bill.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if bill.isAutoPay {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(dueDateText)
                        .font(.caption)
                        .foregroundStyle(bill.statusColor)

                    if let categoryName = bill.category?.localizedDisplayName {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(categoryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bill.formattedAmount)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Button(action: {
                    if bill.isPaid {
                        showingUnpayConfirm = true
                    } else {
                        showingMarkPaidSheet = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(bill.isPaid ? .green : .secondary)
                        Text(bill.isPaid ? L10n.s("Paid") : L10n.s("Pay"))
                            .font(.caption.bold())
                            .foregroundStyle(bill.isPaid ? .green : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bill.isPaid ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sheet(isPresented: $showingMarkPaidSheet) {
            MarkPaidSheet(
                bill: bill,
                onCancel: { showingMarkPaidSheet = false },
                onConfirm: { amount, code, receipt in
                    bill.markAsPaid(paidAmount: amount, confirmationCode: code, receiptData: receipt)
                    if let message = Persistence.saveReturningMessage(modelContext) {
                        persistenceError = message
                        return
                    }
                    NotificationManager.shared.applyPaidSideEffects(
                        for: bill,
                        overdueCount: overdueCount()
                    )
                    showingMarkPaidSheet = false
                }
            )
        }
        .confirmationDialog(
            L10n.s("Undo last payment and remove its history record?"),
            isPresented: $showingUnpayConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.s("Undo Last Payment"), role: .destructive) {
                withAnimation {
                    if let record = bill.undoLastPayment() {
                        modelContext.delete(record)
                    }
                    if let message = Persistence.saveReturningMessage(modelContext) {
                        persistenceError = message
                        return
                    }
                    NotificationManager.shared.applyPaidSideEffects(
                        for: bill,
                        overdueCount: overdueCount()
                    )
                }
            }
            Button(L10n.s("Cancel"), role: .cancel) {}
        }
        .persistenceAlert($persistenceError)
    }

    private var dueDateText: String {
        if bill.isPaid {
            return L10n.s("Paid")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: bill.dueDate)
    }

    private func overdueCount() -> Int {
        let bills = (try? modelContext.fetch(FetchDescriptor<Bill>())) ?? []
        return bills.filter { $0.status == .overdue }.count
    }
}
