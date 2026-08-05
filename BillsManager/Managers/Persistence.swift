import Foundation
import SwiftData
import SwiftUI

enum PersistenceError: LocalizedError {
    case saveFailed(underlying: Error)
    case exportFailed(underlying: Error)
    case containerFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return L10n.s("Couldn't save your changes. Please try again.")
        case .exportFailed:
            return L10n.s("Couldn't create the export file. Please try again.")
        case .containerFailed:
            return L10n.s("Couldn't open the local database.")
        }
    }

    var failureReason: String? {
        switch self {
        case .saveFailed(let error), .exportFailed(let error), .containerFailed(let error):
            return error.localizedDescription
        }
    }
}

enum Persistence {
    static func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    /// Saves and returns a user-facing message on failure; `nil` on success.
    static func saveReturningMessage(_ context: ModelContext) -> String? {
        do {
            try save(context)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct PersistenceAlert: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            L10n.s("Something Went Wrong"),
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button(L10n.s("OK"), role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    func persistenceAlert(_ message: Binding<String?>) -> some View {
        modifier(PersistenceAlert(message: message))
    }
}

struct DatabaseLaunchErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label(L10n.s("Storage Unavailable"), systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(L10n.s("Couldn't open the local database."))
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
