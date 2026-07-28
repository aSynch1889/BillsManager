import SwiftUI
import SwiftData

struct BillDetailView: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet: Bool = false
    @State private var showingMarkPaidSheet: Bool = false
    @State private var paidAmountText: String = ""
    @State private var confirmationCodeText: String = ""
    @State private var paidNotesText: String = ""
    @State private var showingDeleteConfirmation: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Header Card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(bill.category?.color ?? .blue)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: bill.category?.iconName ?? "doc.text.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    
                    Text(bill.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(bill.formattedAmount)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(bill.statusColor)
                            .frame(width: 8, height: 8)
                        Text(bill.status.localizedName)
                            .font(.subheadline.bold())
                            .foregroundStyle(bill.statusColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(bill.statusColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                // Primary Action Button
                Button(action: {
                    if bill.isPaid {
                        togglePaid()
                    } else {
                        paidAmountText = String(format: "%.2f", bill.amount)
                        showingMarkPaidSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: bill.isPaid ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                        Text(bill.isPaid ? L10n.s("Mark as Unpaid") : L10n.s("Mark as Paid"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bill.isPaid ? Color.gray : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                // Bill Details Info Group
                VStack(spacing: 16) {
                    DetailRow(title: L10n.s("Due Date"), value: formattedDate(bill.dueDate), icon: "calendar")
                    Divider()
                    DetailRow(title: L10n.s("Category"), value: bill.category?.name ?? L10n.s("Uncategorized"), icon: bill.category?.iconName ?? "folder")
                    Divider()
                    DetailRow(title: L10n.s("Payment Account"), value: bill.account?.name ?? L10n.s("None"), icon: bill.account?.iconName ?? "creditcard")
                    Divider()
                    DetailRow(title: L10n.s("Frequency"), value: bill.frequency.localizedName, icon: "repeat")
                    Divider()
                    DetailRow(title: L10n.s("Auto-Pay"), value: bill.isAutoPay ? L10n.s("Enabled") : L10n.s("Disabled"), icon: "arrow.triangle.2.circlepath")
                    Divider()
                    DetailRow(
                        title: L10n.s("Reminder"),
                        value: bill.reminderDaysBefore == 0 ? L10n.s("On due date") : String(format: L10n.s("%d days before"), bill.reminderDaysBefore),
                        icon: "bell"
                    )
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Notes Section
                if let notes = bill.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.s("Notes"))
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Attachment Image Preview
                if let imageData = bill.attachmentImageData, let uiImage = UIImage(data: imageData) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.s("Attachment / Receipt"))
                            .font(.headline)
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Payment History Log Section
                if let history = bill.paymentHistory, !history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.s("Payment History"))
                            .font(.title3.bold())
                        
                        ForEach(history.sorted(by: { $0.paidDate > $1.paidDate })) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formattedDate(record.paidDate))
                                        .font(.subheadline.bold())
                                    if let code = record.confirmationCode, !code.isEmpty {
                                        Text(String(format: L10n.s("Ref: %@"), code))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(String(format: "$%.2f", record.amountPaid))
                                    .font(.callout.bold())
                                    .foregroundStyle(.green)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.s("Bill Details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label(L10n.s("Edit Bill"), systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label(L10n.s("Delete Bill"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                AddEditBillView(billToEdit: bill)
            }
        }
        .sheet(isPresented: $showingMarkPaidSheet) {
            NavigationStack {
                Form {
                    Section(L10n.s("Payment Record")) {
                        HStack {
                            Text(L10n.s("Amount Paid"))
                            Spacer()
                            TextField("Amount", text: $paidAmountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text(L10n.s("Confirmation #"))
                            Spacer()
                            TextField("Optional code", text: $confirmationCodeText)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .navigationTitle(L10n.s("Mark as Paid"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.s("Cancel")) { showingMarkPaidSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.s("Confirm")) {
                            let amount = Double(paidAmountText) ?? bill.amount
                            let code = confirmationCodeText.isEmpty ? nil : confirmationCodeText
                            bill.markAsPaid(paidAmount: amount, confirmationCode: code)
                            NotificationManager.shared.cancelNotification(for: bill)
                            try? modelContext.save()
                            showingMarkPaidSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Are you sure you want to delete this bill?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.s("Delete Bill"), role: .destructive) {
                NotificationManager.shared.cancelNotification(for: bill)
                modelContext.delete(bill)
                try? modelContext.save()
                dismiss()
            }
            Button(L10n.s("Cancel"), role: .cancel) {}
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func togglePaid() {
        withAnimation {
            bill.markAsUnpaid()
            NotificationManager.shared.scheduleNotification(for: bill)
            try? modelContext.save()
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
        }
    }
}
