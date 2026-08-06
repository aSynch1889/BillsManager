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
    @State private var persistenceError: String?

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("defaultReminderDays") private var defaultReminderDays: Int = 1
    
    private var isEditing: Bool { billToEdit != nil }

    private var parsedAmount: Double? {
        CurrencyFormatter.parseAmount(amountText)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedAmount != nil
            && (frequency == .once || !hasRepeatEndDate || repeatEndDate >= Calendar.current.startOfDay(for: dueDate))
    }
    
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
                            Text(cat.localizedDisplayName)
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
                            Text(acc.localizedDisplayName)
                        }
                        .tag(Account?.some(acc))
                    }
                }
            }
            
            Section {
                Picker(L10n.s("Repeat Frequency"), selection: $frequency) {
                    ForEach(BillFrequency.allCases) { freq in
                        Text(freq.localizedName).tag(freq)
                    }
                }
                
                Toggle(L10n.s("External Auto-Pay Mark"), isOn: $isAutoPay)
                
                if frequency != .once {
                    Toggle(L10n.s("Set End Date"), isOn: $hasRepeatEndDate)
                    if hasRepeatEndDate {
                        DatePicker(
                            L10n.s("Repeat Until"),
                            selection: $repeatEndDate,
                            in: dueDate...,
                            displayedComponents: [.date]
                        )
                    }
                }
            } header: {
                Text(L10n.s("Recurring & External Auto-Pay"))
            } footer: {
                Text(L10n.s("Marks bills you already set to auto-debit outside this app. Bills Manager never charges your accounts."))
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
                        guard let newItem else { return }
                        do {
                            guard let data = try await newItem.loadTransferable(type: Data.self) else {
                                persistenceError = L10n.s("Couldn't load the selected photo.")
                                return
                            }
                            attachmentImageData = data
                        } catch {
                            persistenceError = L10n.s("Couldn't load the selected photo.")
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
                    .disabled(!canSave)
            }
        }
        .onAppear {
            populateFormIfEditing()
        }
        .persistenceAlert($persistenceError)
    }
    
    private func populateFormIfEditing() {
        if let bill = billToEdit {
            name = bill.name
            amountText = CurrencyFormatter.inputString(for: bill.amount)
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
            selectedCategory = categories.first
            selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
            reminderDaysBefore = defaultReminderDays
        }
    }
    
    private func saveBill() {
        guard let amount = parsedAmount, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if frequency != .once && hasRepeatEndDate {
            guard repeatEndDate >= Calendar.current.startOfDay(for: dueDate) else { return }
        }
        
        let targetEndDate = (frequency != .once && hasRepeatEndDate) ? repeatEndDate : nil
        
        if let bill = billToEdit {
            bill.name = name
            bill.amount = amount
            bill.dueDate = dueDate
            bill.syncRecurrenceAnchor(from: dueDate)
            bill.category = selectedCategory
            bill.account = selectedAccount
            bill.frequency = frequency
            bill.isAutoPay = isAutoPay
            bill.repeatEndDate = targetEndDate
            bill.reminderDaysBefore = reminderDaysBefore
            bill.reminderTime = reminderTime
            bill.notes = notes.isEmpty ? nil : notes
            bill.attachmentImageData = attachmentImageData
            
            Task {
                _ = await NotificationManager.shared.ensureAuthorization()
                NotificationManager.shared.scheduleNotification(for: bill)
            }
        } else {
            let newBill = Bill(
                name: name,
                amount: amount,
                currencyCode: defaultCurrency,
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
            Task {
                _ = await NotificationManager.shared.ensureAuthorization()
                NotificationManager.shared.scheduleNotification(for: newBill)
            }
        }
        
        if let message = Persistence.saveReturningMessage(modelContext) {
            persistenceError = message
            return
        }
        dismiss()
    }
}
