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

/// Due = unpaid bills by dueDate; Paid = PaymentRecord by paidDate.
enum AnalyticsMetricMode: String, CaseIterable, Identifiable {
    case paid
    case due

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .paid: return L10n.s("Paid (Actual)")
        case .due: return L10n.s("Due (Unpaid)")
        }
    }
}

struct CategoryExpense: Identifiable {
    let id = UUID()
    let categoryName: String
    let color: Color
    let totalAmount: Double
}

struct AnalyticsView: View {
    @Query private var bills: [Bill]
    @Environment(StoreManager.self) private var storeManager
    @State private var selectedRange: AnalyticsTimeRange = .thisMonth
    @State private var metricMode: AnalyticsMetricMode = .paid
    @State private var showingPaywall: Bool = false
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    private var calendar: Calendar { .current }

    private func isDateInSelectedRange(_ date: Date) -> Bool {
        let now = Date()
        switch selectedRange {
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .last3Months:
            guard let start = calendar.date(byAdding: .month, value: -3, to: now) else { return true }
            return date >= start
        case .thisYear:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .allTime:
            return true
        }
    }

    /// Actual payments settled in the selected range (by payment date).
    private var paidRecordsInRange: [(record: PaymentRecord, bill: Bill)] {
        bills.flatMap { bill in
            (bill.paymentHistory ?? []).compactMap { record in
                isDateInSelectedRange(record.paidDate) ? (record, bill) : nil
            }
        }
    }

    /// Unpaid obligations whose current dueDate falls in the selected range.
    private var dueUnpaidBills: [Bill] {
        bills.filter { !$0.isPaid && isDateInSelectedRange($0.dueDate) }
    }

    private var paidAmount: Double {
        paidRecordsInRange.reduce(0) { $0 + $1.record.amountPaid }
    }

    private var unpaidAmount: Double {
        dueUnpaidBills.reduce(0) { $0 + $1.amount }
    }

    private var chartTotal: Double {
        metricMode == .paid ? paidAmount : unpaidAmount
    }

    private var categoryExpenses: [CategoryExpense] {
        switch metricMode {
        case .paid:
            let grouped = Dictionary(grouping: paidRecordsInRange) {
                $0.bill.category?.localizedDisplayName ?? L10n.s("Uncategorized")
            }
            return grouped.map { name, items in
                let total = items.reduce(0) { $0 + $1.record.amountPaid }
                let color = items.first?.bill.category?.color ?? .gray
                return CategoryExpense(categoryName: name, color: color, totalAmount: total)
            }.sorted { $0.totalAmount > $1.totalAmount }

        case .due:
            let grouped = Dictionary(grouping: dueUnpaidBills) {
                $0.category?.localizedDisplayName ?? L10n.s("Uncategorized")
            }
            return grouped.map { name, bills in
                let total = bills.reduce(0) { $0 + $1.amount }
                let color = bills.first?.category?.color ?? .gray
                return CategoryExpense(categoryName: name, color: color, totalAmount: total)
            }.sorted { $0.totalAmount > $1.totalAmount }
        }
    }

    private func money(_ amount: Double) -> String {
        CurrencyFormatter.string(amount: amount, currencyCode: defaultCurrency)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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

                // Summary: paid from PaymentRecord; unpaid from current due obligations
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.s("Paid (Actual)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(money(paidAmount))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.s("Due (Unpaid)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(money(unpaidAmount))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                Picker(L10n.s("Chart Metric"), selection: $metricMode) {
                    ForEach(AnalyticsMetricMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

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
                                    Text(String(format: "(%.1f%%)", chartTotal > 0 ? (cat.totalAmount / chartTotal * 100) : 0))
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
                        description: Text(
                            metricMode == .paid
                                ? L10n.s("Mark bills as paid to see actual spending by category.")
                                : L10n.s("Add unpaid bills with due dates in this range to see obligations.")
                        )
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
