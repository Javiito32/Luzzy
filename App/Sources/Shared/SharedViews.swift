import LuzzyCore
import LuzzyUI
import SwiftUI

/// Presenta un `Loadable`: contenido (aunque sea de la caché), carga o error.
struct LoadableView<Value: Sendable, Content: View>: View {
    let state: Loadable<Value>
    let retry: () async -> Void
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        if let value = state.value {
            content(value)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let error = state.error {
                        StaleBanner(message: error.userMessage, retry: retry)
                    }
                }
        } else if let error = state.error {
            ContentUnavailableView {
                Label("No se han podido cargar los datos", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error.userMessage)
            } actions: {
                Button("Reintentar") { Task { await retry() } }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Aviso discreto cuando se muestran datos guardados porque falló la actualización.
struct StaleBanner: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "icloud.slash")
            Text(message).font(.footnote).lineLimit(2)
            Spacer(minLength: 0)
            Button("Reintentar") { Task { await retry() } }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .luzzyGlass(in: Capsule(), interactive: false)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

/// Cabecera de sección con acción opcional ("Ver todo").
struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer()
            trailing.font(.body)
        }
        .padding(.horizontal, 4)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        trailing = EmptyView()
    }
}

/// Fila de movimiento reutilizable.
struct TransactionRow: View {
    let group: TransactionGroup

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(group.signedTotals, id: \.currency.code) { total in
                    MoneyText(total, showsSign: group.kind == .deposit, coloring: group.kind == .deposit ? .positiveHighlight : .none)
                        .font(LuzzyTheme.amountFont())
                        .foregroundStyle(group.kind == .transfer ? LuzzyTheme.transfer : .primary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch group.kind {
        case .transfer:
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(LuzzyTheme.transfer)
                .frame(width: 40, height: 40)
                .background(Circle().fill(LuzzyTheme.transfer.opacity(0.12)))
        default:
            InitialAvatar(counterpartName)
        }
    }

    private var counterpartName: String {
        guard let split = group.splits.first else { return group.displayTitle }
        let name = group.kind == .deposit ? split.source.name : split.destination.name
        return name.isEmpty ? group.displayTitle : name
    }

    private var subtitle: String {
        guard let split = group.splits.first else { return "" }
        switch group.kind {
        case .transfer:
            return "\(split.source.name) → \(split.destination.name)"
        case .deposit:
            return [split.source.name, split.category?.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        default:
            let parts = [split.category?.name, split.source.name].compactMap { $0 }.filter { !$0.isEmpty }
            return group.isSplit ? String(localized: "\(group.splits.count) partes") : parts.joined(separator: " · ")
        }
    }
}

/// Agrupa movimientos por día para las listas.
struct DaySection: Identifiable {
    let day: Date
    let groups: [TransactionGroup]
    var id: Date { day }

    static func make(from groups: [TransactionGroup], calendar: Calendar = .autoupdatingCurrent) -> [DaySection] {
        let grouped = Dictionary(grouping: groups) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { DaySection(day: $0, groups: grouped[$0] ?? []) }
    }
}

/// Título relativo del día: "Hoy", "Ayer" o la fecha.
struct DayTitle: View {
    let day: Date

    var body: some View {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(day) {
            Text("Hoy")
        } else if calendar.isDateInYesterday(day) {
            Text("Ayer")
        } else {
            Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
        }
    }
}

/// Lista de dinero por divisa en una sola línea.
struct MoneyList: View {
    let values: [Money]
    var showsSign = false

    var body: some View {
        if values.isEmpty {
            Text("—").foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(values, id: \.currency.code) { MoneyText($0, showsSign: showsSign) }
            }
        }
    }
}
