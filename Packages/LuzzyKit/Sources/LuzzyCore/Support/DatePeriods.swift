import Foundation

public extension DateInterval {
    /// Mes natural que contiene `date` (inicio inclusivo, fin exclusivo).
    static func month(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    /// Desplaza el intervalo mensual `offset` meses.
    func shiftedMonths(_ offset: Int, calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        guard let shifted = calendar.date(byAdding: .month, value: offset, to: start) else { return self }
        return .month(containing: shifted, calendar: calendar)
    }

    /// Último instante incluido (Firefly trata `end` como día inclusivo).
    var inclusiveEnd: Date { end.addingTimeInterval(-1) }

    /// Días que quedan desde `date` hasta el final del periodo (incluido el día actual).
    func daysRemaining(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        guard date < end else { return 0 }
        let from = calendar.startOfDay(for: max(date, start))
        let components = calendar.dateComponents([.day], from: from, to: end)
        return max(components.day ?? 0, 0)
    }
}
