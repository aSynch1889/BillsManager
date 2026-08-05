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
        case .thisMonth: return L10n.s("This Month")
        case .last3Months: return L10n.s("3 Months")
        case .thisYear: return L10n.s("This Year")
        case .allTime: return L10n.s("All Time")
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
    @Environment(StoreManager.self) private var storeManager
    @State private var selectedRange: AnalyticsTimeRange = .thisMonth
    @State private var showingPaywall: Bool = false
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    
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

    private func money(_ amount: Double) -> String {
        CurrencyFormatter.string(amount: amount, currencyCode: defaultCurrency)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Segmented Picker
                Picker(L10n.s("Range"), selection: $selectedRange) {
                    ForEach(AnalyticsTimeRange.allCases) { range in
                        Text(range.localizedTitle).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedRange) { _, newRange in
                    if newRange != .thisMonth && !storeManager.canAccess(.advancedAnalytics) {
                        selectedRange = .thisMonth
                        showingPaywall = true
                    }
                }

                if !storeManager.canAccess(.advancedAnalytics) {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label(L10n.s("Unlock multi-range analytics with PRO"), systemImage: "lock.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                
                // Total Summary Card
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.s("Total Bills"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(money(totalAmount))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.s("Paid / Unpaid"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(money(paidAmount)) / \(money(unpaidAmount))")
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
                        Text(L10n.s("Expense by Category"))
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
                                    Text(money(cat.totalAmount))
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
                        L10n.s("No Analytics Data"),
                        systemImage: "chart.bar.xaxis",
                        description: Text(L10n.s("Add bills to view category spending charts."))
                    )
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.s("Analytics"))
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
    }
}
