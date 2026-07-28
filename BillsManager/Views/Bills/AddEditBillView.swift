import SwiftUI
import SwiftData
import PhotosUI

struct AddEditBillView: View {
    let billToEdit: Bill?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    
    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var dueDate: Date = Date()
    @State private var selectedCategory: Category? = nil
    @State private var selectedAccount: Account? = nil
    @State private var frequency: BillFrequency = .monthly
    @State private var isAutoPay: Bool = false
    @State private var hasRepeatEndDate: Bool = false
    @State private var repeatEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var reminderDaysBefore: Int = 1
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes: String = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var attachmentImageData: Data? = nil
    
    @State private var showingCategoryManager: Bool = false
    @State private var showingAccountManager: Bool = false
    
    private var isEditing: Bool { billToEdit != nil }
    
    var body: some View {
        Form {
            Section(header: Text(L10n.s("Bill Overview"))) {
                TextField(L10n.s("Bill Name (e.g. Electric Bill)"), text: $name)
                
                HStack {
                    Text(L10n.s("Amount"))
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                DatePicker(L10n.s("Due Date"), selection: $dueDate, displayedComponents: [.date])
            }
            
            Section(header: Text(L10n.s("Category & Payment Account"))) {
                Picker(L10n.s("Category"), selection: $selectedCategory) {
                    Text(L10n.s("Uncategorized")).tag(Category?.none)
                    ForEach(categories) { cat in
                        HStack {
                            Image(systemName: cat.iconName)
                                .foregroundStyle(cat.color)
                            Text(cat.name)
                        }
                        .tag(Category?.some(cat))
                    }
                }
                
                Picker(L10n.s("Account"), selection: $selectedAccount) {
                    Text(L10n.s("None")).tag(Account?.none)
                    ForEach(accounts) { acc in
                        HStack {
                            Image(systemName: acc.iconName)
                                .foregroundStyle(acc.color)
                            Text(acc.name)
                        }
                        .tag(Account?.some(acc))
                    }
                }
            }
            
            Section(header: Text(L10n.s("Recurring & Auto-Pay"))) {
                Picker(L10n.s("Repeat Frequency"), selection: $frequency) {
                    ForEach(BillFrequency.allCases) { freq in
                        Text(freq.localizedName).tag(freq)
                    }
                }
                
                Toggle(L10n.s("Auto-Pay"), isOn: $isAutoPay)
                
                if frequency != .once {
                    Toggle(L10n.s("Set End Date"), isOn: $hasRepeatEndDate)
                    if hasRepeatEndDate {
                        DatePicker(L10n.s("Repeat Until"), selection: $repeatEndDate, displayedComponents: [.date])
                    }
                }
            }
            
            Section(header: Text(L10n.s("Reminders & Notifications"))) {
                Picker(L10n.s("Remind Me"), selection: $reminderDaysBefore) {
                    Text(L10n.s("On due date")).tag(0)
                    Text(L10n.s("1 day before")).tag(1)
                    Text(L10n.s("2 days before")).tag(2)
                    Text(L10n.s("3 days before")).tag(3)
                    Text(L10n.s("7 days before")).tag(7)
                }
                
                DatePicker(L10n.s("Reminder Time"), selection: $reminderTime, displayedComponents: [.hourAndMinute])
            }
            
            Section(header: Text(L10n.s("Notes & Attachments"))) {
                TextField(L10n.s("Notes / Account numbers..."), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(attachmentImageData == nil ? L10n.s("Attach Receipt / Invoice") : L10n.s("Change Attachment"))
                        Spacer()
                        if attachmentImageData != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            attachmentImageData = data
                        }
                    }
                }
                
                if let data = attachmentImageData, let uiImage = UIImage(data: data) {
                    HStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            attachmentImageData = nil
                            selectedPhotoItem = nil
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? L10n.s("Edit Bill") : L10n.s("New Bill"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.s("Cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.s("Save")) { saveBill() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountText) == nil)
            }
        }
        .onAppear {
            populateFormIfEditing()
        }
    }
    
    private func populateFormIfEditing() {
        if let bill = billToEdit {
            name = bill.name
            amountText = String(format: "%.2f", bill.amount)
            dueDate = bill.dueDate
            selectedCategory = bill.category
            selectedAccount = bill.account
            frequency = bill.frequency
            isAutoPay = bill.isAutoPay
            if let endDate = bill.repeatEndDate {
                hasRepeatEndDate = true
                repeatEndDate = endDate
            }
            reminderDaysBefore = bill.reminderDaysBefore
            reminderTime = bill.reminderTime
            notes = bill.notes ?? ""
            attachmentImageData = bill.attachmentImageData
        } else {
            // Default selected category & account
            selectedCategory = categories.first
            selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
        }
    }
    
    private func saveBill() {
        guard let amount = Double(amountText), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let targetEndDate = (frequency != .once && hasRepeatEndDate) ? repeatEndDate : nil
        
        if let bill = billToEdit {
            bill.name = name
            bill.amount = amount
            bill.dueDate = dueDate
            bill.category = selectedCategory
            bill.account = selectedAccount
            bill.frequency = frequency
            bill.isAutoPay = isAutoPay
            bill.repeatEndDate = targetEndDate
            bill.reminderDaysBefore = reminderDaysBefore
            bill.reminderTime = reminderTime
            bill.notes = notes.isEmpty ? nil : notes
            bill.attachmentImageData = attachmentImageData
            
            NotificationManager.shared.scheduleNotification(for: bill)
        } else {
            let newBill = Bill(
                name: name,
                amount: amount,
                dueDate: dueDate,
                isAutoPay: isAutoPay,
                frequency: frequency,
                repeatEndDate: targetEndDate,
                reminderDaysBefore: reminderDaysBefore,
                reminderTime: reminderTime,
                notes: notes.isEmpty ? nil : notes,
                attachmentImageData: attachmentImageData,
                category: selectedCategory,
                account: selectedAccount
            )
            modelContext.insert(newBill)
            NotificationManager.shared.scheduleNotification(for: newBill)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
