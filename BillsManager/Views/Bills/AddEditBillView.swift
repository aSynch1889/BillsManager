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
            Section(header: Text(NSLocalizedString("Bill Overview", comment: ""))) {
                TextField(NSLocalizedString("Bill Name (e.g. Electric Bill)", comment: ""), text: $name)
                
                HStack {
                    Text(NSLocalizedString("Amount", comment: ""))
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                DatePicker(NSLocalizedString("Due Date", comment: ""), selection: $dueDate, displayedComponents: [.date])
            }
            
            Section(header: Text(NSLocalizedString("Category & Payment Account", comment: ""))) {
                Picker(NSLocalizedString("Category", comment: ""), selection: $selectedCategory) {
                    Text(NSLocalizedString("Uncategorized", comment: "")).tag(Category?.none)
                    ForEach(categories) { cat in
                        HStack {
                            Image(systemName: cat.iconName)
                                .foregroundStyle(cat.color)
                            Text(cat.name)
                        }
                        .tag(Category?.some(cat))
                    }
                }
                
                Picker(NSLocalizedString("Account", comment: ""), selection: $selectedAccount) {
                    Text(NSLocalizedString("None", comment: "")).tag(Account?.none)
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
            
            Section(header: Text(NSLocalizedString("Recurring & Auto-Pay", comment: ""))) {
                Picker(NSLocalizedString("Repeat Frequency", comment: ""), selection: $frequency) {
                    ForEach(BillFrequency.allCases) { freq in
                        Text(freq.localizedName).tag(freq)
                    }
                }
                
                Toggle(NSLocalizedString("Auto-Pay", comment: ""), isOn: $isAutoPay)
                
                if frequency != .once {
                    Toggle(NSLocalizedString("Set End Date", comment: ""), isOn: $hasRepeatEndDate)
                    if hasRepeatEndDate {
                        DatePicker(NSLocalizedString("Repeat Until", comment: ""), selection: $repeatEndDate, displayedComponents: [.date])
                    }
                }
            }
            
            Section(header: Text(NSLocalizedString("Reminders & Notifications", comment: ""))) {
                Picker(NSLocalizedString("Remind Me", comment: ""), selection: $reminderDaysBefore) {
                    Text(NSLocalizedString("On due date", comment: "")).tag(0)
                    Text(NSLocalizedString("1 day before", comment: "")).tag(1)
                    Text(NSLocalizedString("2 days before", comment: "")).tag(2)
                    Text(NSLocalizedString("3 days before", comment: "")).tag(3)
                    Text(NSLocalizedString("7 days before", comment: "")).tag(7)
                }
                
                DatePicker(NSLocalizedString("Reminder Time", comment: ""), selection: $reminderTime, displayedComponents: [.hourAndMinute])
            }
            
            Section(header: Text(NSLocalizedString("Notes & Attachments", comment: ""))) {
                TextField(NSLocalizedString("Notes / Account numbers...", comment: ""), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(attachmentImageData == nil ? NSLocalizedString("Attach Receipt / Invoice", comment: "") : NSLocalizedString("Change Attachment", comment: ""))
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
        .navigationTitle(isEditing ? NSLocalizedString("Edit Bill", comment: "") : NSLocalizedString("New Bill", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveBill() }
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
