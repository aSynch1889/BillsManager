import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var showingAddBill: Bool
    
    @Query(sort: \Bill.dueDate) private var allBills: [Bill]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    
    private var overdueBills: [Bill] {
        allBills.filter { $0.status == .overdue }
    }
    
    private var dueSoonBills: [Bill] {
        allBills.filter { $0.status == .dueToday || $0.status == .dueSoon }
    }
    
    private var upcomingBills: [Bill] {
        allBills.filter { !$0.isPaid && $0.status != .overdue }.prefix(5).map { $0 }
    }
    
    private var totalDueThisMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        return allBills.filter {
            !$0.isPaid && calendar.isDate($0.dueDate, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalOverdueAmount: Double {
        overdueBills.reduce(0) { $0 + $1.amount }
    }
    
    private var totalPaidThisMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        return allBills.filter {
            $0.isPaid && calendar.isDate($0.dueDate, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }

    private func money(_ amount: Double) -> String {
        CurrencyFormatter.string(amount: amount, currencyCode: defaultCurrency)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Overdue Alert Banner
                if !overdueBills.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: L10n.s("Overdue Bills (%d)"), overdueBills.count))
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text(String(format: L10n.s("Total overdue: %@"), money(totalOverdueAmount)))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Metrics Overview Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCardView(
                        title: L10n.s("Due This Month"),
                        value: money(totalDueThisMonth),
                        iconName: "calendar.badge.clock",
                        iconColor: .orange
                    )
                    
                    MetricCardView(
                        title: L10n.s("Overdue Amount"),
                        value: money(totalOverdueAmount),
                        iconName: "exclamationmark.circle.fill",
                        iconColor: .red
                    )
                    
                    MetricCardView(
                        title: L10n.s("Paid This Month"),
                        value: money(totalPaidThisMonth),
                        iconName: "checkmark.circle.fill",
                        iconColor: .green
                    )
                    
                    MetricCardView(
                        title: L10n.s("Active Bills"),
                        value: "\(allBills.filter { !$0.isPaid }.count)",
                        iconName: "tray.full.fill",
                        iconColor: .blue
                    )
                }
                
                // Due Soon Section
                if !dueSoonBills.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.s("Action Required Soon"))
                            .font(.title3.bold())
                        
                        ForEach(dueSoonBills) { bill in
                            NavigationLink(destination: BillDetailView(bill: bill)) {
                                BillRowView(bill: bill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Upcoming Bills Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.s("Upcoming Bills"))
                            .font(.title3.bold())
                        Spacer()
                    }
                    
                    if upcomingBills.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green.opacity(0.8))
                            Text(L10n.s("All bills are paid up!"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        ForEach(upcomingBills) { bill in
                            NavigationLink(destination: BillDetailView(bill: bill)) {
                                BillRowView(bill: bill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.s("Dashboard"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddBill = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .onAppear {
            NotificationManager.shared.updateBadgeCount(overdueCount: overdueBills.count)
        }
        .onChange(of: overdueBills.count) { _, newCount in
            NotificationManager.shared.updateBadgeCount(overdueCount: newCount)
        }
    }
}
