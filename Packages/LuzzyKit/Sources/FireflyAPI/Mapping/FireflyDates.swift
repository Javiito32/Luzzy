import Foundation

/// Conversión de fechas entre Firefly y la app.
enum FireflyDates {
    /// Interpreta fechas ISO 8601 con zona horaria, con o sin fracciones,
    /// o fechas "yyyy-MM-dd" (en el calendario local).
    static func parse(_ text: String?, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if let date = try? Date(text, strategy: .iso8601) { return date }
        if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// "yyyy-MM-dd" en el calendario local, formato de los parámetros de consulta.
    static func day(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Fecha y hora con zona para crear movimientos.
    static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent))
    }

    /// Parámetros `start`/`end` (ambos inclusivos en Firefly).
    static func rangeQuery(_ period: DateInterval) -> [URLQueryItem] {
        [
            URLQueryItem(name: "start", value: day(period.start)),
            URLQueryItem(name: "end", value: day(period.end.addingTimeInterval(-1))),
        ]
    }
}
