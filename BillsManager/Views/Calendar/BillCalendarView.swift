import SwiftUI
import SwiftData

struct BillCalendarView: View {
    @Query(sort: \Bill.dueDate) private var allBills: [Bill]
    
    @State private var selectedMonthDate: Date = Date()
    @State private var selectedDayDate: Date = Date()
    
    private var calendar: Calendar { Calendar.current }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonthDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = monthFirstWeek.start
        while currentDate < monthLastWeek.end {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }
    
    private var billsOnSelectedDay: [Bill] {
        allBills.filter { calendar.isDate($0.dueDate, inSameDayAs: selectedDayDate) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Header Selector
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                }
                
                Spacer()
                
                Text(monthYearString(selectedMonthDate))
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // Days of week header
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    let isCurrentMonth = calendar.isDate(date, equalTo: selectedMonthDate, toGranularity: .month)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDayDate)
                    let bills = allBills.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
                    
                    CalendarGridCell(
                        date: date,
                        isCurrentMonth: isCurrentMonth,
                        isSelected: isSelected,
                        bills: bills
                    )
                    .onTapGesture {
                        selectedDayDate = date
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .background(Color(.systemGroupedBackground))
            
            Divider()
            
            // Selected Day Bills List
            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: L10n.s("Bills Due on %@"), formattedSelectedDate(selectedDayDate)))
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)
                
                if billsOnSelectedDay.isEmpty {
                    ContentUnavailableView(
                        L10n.s("No Bills Due"),
                        systemImage: "calendar.badge.checkmark",
                        description: Text(L10n.s("No bill payments scheduled for this date."))
                    )
                } else {
                    List {
                        ForEach(billsOnSelectedDay) { bill in
                            NavigationLink(destination: BillDetailView(bill: bill)) {
                                BillRowView(bill: bill)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .navigationTitle(L10n.s("Calendar"))
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonthDate) {
            selectedMonthDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonthDate) {
            selectedMonthDate = newDate
        }
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formattedSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
