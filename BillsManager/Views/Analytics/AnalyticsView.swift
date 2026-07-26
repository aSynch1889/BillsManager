import SwiftUI
import SwiftData
import Charts

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case thisMonth = "This Month"
    case last3Months = "3 Months"
    case thisYear = "This Year"
    case allTime = "All Time"
    
    var id: String { rawValue }
    
    var localizedTitle: String {
        switch self {
        case .thisMonth: return NSLocalizedString("This Month", comment: "")
        case .last3Months: return NSLocalizedString("3 Months", comment: "")
        case .thisYear: return NSLocalizedString("This Year", comment: "")
        case .allTime: return NSLocalizedString("All Time", comment: "")
        }
    }
}

struct CategoryExpense: Identifiable {
    let id = UUID()
    let categoryName: String
    let color: Color
    let totalAmount: Double
}

struct MonthlyExpense: Identifiable {
    let id = UUID()
    let monthName: String
    let amount: Double
}

struct AnalyticsView: View {
    @Query private var bills: [Bill]
    @State private var selectedRange: AnalyticsTimeRange = .thisMonth
    
    private var filteredBills: [Bill] {
        let calendar = Calendar.current
        let now = Date()
        
        return bills.filter { bill in
            switch selectedRange {
            case .thisMonth:
                return calendar.isDate(bill.dueDate, equalTo: now, toGranularity: .month)
            case .last3Months:
                if let date3MonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) {
                    return bill.dueDate >= date3MonthsAgo
                }
                return true
            case .thisYear:
                return calendar.isDate(bill.dueDate, equalTo: now, toGranularity: .year)
            case .allTime:
                return true
            }
        }
    }
    
    private var totalAmount: Double {
        filteredBills.reduce(0) { $0 + $1.amount }
    }
    
    private var paidAmount: Double {
        filteredBills.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    private var unpaidAmount: Double {
        filteredBills.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }
    
    private var categoryExpenses: [CategoryExpense] {
        let grouped = Dictionary(grouping: filteredBills) { $0.category?.name ?? "Uncategorized" }
        return grouped.map { name, bills in
            let total = bills.reduce(0) { $0 + $1.amount }
            let color = bills.first?.category?.color ?? .gray
            return CategoryExpense(categoryName: name, color: color, totalAmount: total)
        }.sorted(by: { $0.totalAmount > $1.totalAmount })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Segmented Picker
                Picker("Range", selection: $selectedRange) {
                    ForEach(AnalyticsTimeRange.allCases) { range in
                        Text(range.localizedTitle).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Total Summary Card
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Total Bills", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "$%.2f", totalAmount))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(NSLocalizedString("Paid / Unpaid", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "$%.0f / $%.0f", paidAmount, unpaidAmount))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                
                // Category Expense Donut Chart
                if !categoryExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("Expense by Category", comment: ""))
                            .font(.title3.bold())
                        
                        Chart(categoryExpenses) { item in
                            SectorMark(
                                angle: .value("Amount", item.totalAmount),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(item.color)
                        }
                        .frame(height: 220)
                        
                        // Category Legend Table
                        VStack(spacing: 10) {
                            ForEach(categoryExpenses) { cat in
                                HStack {
                                    Circle()
                                        .fill(cat.color)
                                        .frame(width: 10, height: 10)
                                    Text(cat.categoryName)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "$%.2f", cat.totalAmount))
                                        .font(.subheadline.bold())
                                    Text(String(format: "(%.1f%%)", totalAmount > 0 ? (cat.totalAmount / totalAmount * 100) : 0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        NSLocalizedString("No Analytics Data", comment: ""),
                        systemImage: "chart.bar.xaxis",
                        description: Text(NSLocalizedString("Add bills to view category spending charts.", comment: ""))
                    )
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(NSLocalizedString("Analytics", comment: ""))
    }
}
