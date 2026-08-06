import SwiftUI
import PhotosUI
import SwiftData

/// Shared mark-paid form: amount, confirmation code, optional receipt photo.
struct MarkPaidSheet: View {
    let bill: Bill
    var onCancel: () -> Void
    var onConfirm: (_ amount: Double, _ confirmationCode: String?, _ receiptData: Data?) -> Void

    @State private var paidAmountText: String = ""
    @State private var confirmationCodeText: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var receiptImageData: Data?
    @State private var photoLoadError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.s("Payment Record")) {
                    HStack {
                        Text(L10n.s("Amount Paid"))
                        Spacer()
                        TextField(L10n.s("Amount"), text: $paidAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text(L10n.s("Confirmation #"))
                        Spacer()
                        TextField(L10n.s("Optional code"), text: $confirmationCodeText)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(L10n.s("Receipt Photo")) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            receiptImageData == nil ? L10n.s("Add Receipt Photo") : L10n.s("Change Receipt Photo"),
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task { await loadReceipt(from: newItem) }
                    }

                    if let data = receiptImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button(L10n.s("Remove Receipt"), role: .destructive) {
                            receiptImageData = nil
                            selectedPhotoItem = nil
                        }
                    }

                    if let photoLoadError {
                        Text(photoLoadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(L10n.s("Mark as Paid"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.s("Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.s("Confirm")) {
                        guard let amount = CurrencyFormatter.parseAmount(paidAmountText) else { return }
                        let code = confirmationCodeText.isEmpty ? nil : confirmationCodeText
                        onConfirm(amount, code, receiptImageData)
                    }
                    .disabled(CurrencyFormatter.parseAmount(paidAmountText) == nil)
                }
            }
            .onAppear {
                paidAmountText = CurrencyFormatter.inputString(for: bill.amount)
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func loadReceipt(from item: PhotosPickerItem?) async {
        photoLoadError = nil
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                photoLoadError = L10n.s("Couldn't load the selected photo.")
                return
            }
            receiptImageData = data
        } catch {
            photoLoadError = L10n.s("Couldn't load the selected photo.")
        }
    }
}
