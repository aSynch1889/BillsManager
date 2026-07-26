import SwiftUI
import SwiftData

struct DashboardView: View {
    @Binding var showingAddBill: Bool
    
    @Query(sort: \Bill.dueDate) private var allBills: [Bill]
    @Environment(\.modelContext) private var modelContext
    
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
                            Text(String(format: NSLocalizedString("Overdue Bills (%d)", comment: ""), overdueBills.count))
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text(String(format: NSLocalizedString("Total overdue: $%.2f", comment: ""), totalOverdueAmount))
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
                        title: NSLocalizedString("Due This Month", comment: ""),
                        value: String(format: "$%.2f", totalDueThisMonth),
                        iconName: "calendar.badge.clock",
                        iconColor: .orange
                    )
                    
                    MetricCardView(
                        title: NSLocalizedString("Overdue Amount", comment: ""),
                        value: String(format: "$%.2f", totalOverdueAmount),
                        iconName: "exclamationmark.circle.fill",
                        iconColor: .red
                    )
                    
                    MetricCardView(
                        title: NSLocalizedString("Paid This Month", comment: ""),
                        value: String(format: "$%.2f", totalPaidThisMonth),
                        iconName: "checkmark.circle.fill",
                        iconColor: .green
                    )
                    
                    MetricCardView(
                        title: NSLocalizedString("Active Bills", comment: ""),
                        value: "\(allBills.filter { !$0.isPaid }.count)",
                        iconName: "tray.full.fill",
                        iconColor: .blue
                    )
                }
                
                // Due Soon Section
                if !dueSoonBills.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("Action Required Soon", comment: ""))
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
                        Text(NSLocalizedString("Upcoming Bills", comment: ""))
                            .font(.title3.bold())
                        Spacer()
                    }
                    
                    if upcomingBills.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green.opacity(0.8))
                            Text(NSLocalizedString("All bills are paid up!", comment: ""))
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
        .navigationTitle(NSLocalizedString("Dashboard", comment: ""))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddBill = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
    }
}
