import SwiftUI

struct CalendarGridCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let bills: [Bill]
    
    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(date) }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(.body, design: .rounded, weight: isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : (isCurrentMonth ? (isToday ? .blue : .primary) : .secondary.opacity(0.4)))
            
            // Status dots indicator
            HStack(spacing: 3) {
                if !bills.isEmpty {
                    ForEach(bills.prefix(3)) { bill in
                        Circle()
                            .fill(bill.statusColor)
                            .frame(width: 5, height: 5)
                    }
                } else {
                    Spacer().frame(height: 5)
                }
            }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                } else if isToday {
                    Circle()
                        .stroke(Color.blue, lineWidth: 1.5)
                }
            }
        )
    }
}
