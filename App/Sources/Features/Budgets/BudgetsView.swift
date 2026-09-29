import LuzzyCore
import LuzzyStore
import LuzzyUI
import SwiftUI

struct BudgetsView: View {
    let session: Session

    @Environment(PurchaseManager.self) private var purchases
    @State private var period = DateInterval.month(containing: .now)
    @State private var resource = Resource<[Budget]>()

    var body: some View {
        NavigationStack {
            Group {
                if purchases.isUnlocked(.budgets) {
                    content
                } else {
                    PremiumLockedView(feature: .budgets)
                }
            }
            .background(LuzzyTheme.groupedBackground)
            .navigationTitle("Presupuestos")
            .toolbar {
                if purchases.isUnlocked(.budgets) {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button { period = period.shiftedMonths(-1) } label: {
                            Label("Mes anterior", systemImage: "chevron.left")
                        }
                        Button { period = period.shiftedMonths(1) } label: {
                            Label("Mes siguiente", systemImage: "chevron.right")
                        }
                    }
                }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(period.start, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                LoadableView(state: resource.state, retry: load) { budgets in
                    let active = budgets.filter(\.isActive)
                    VStack(spacing: 16) {
                        SummaryCard(budgets: active, period: period)
                        VStack(spacing: 0) {
                            ForEach(Array(active.enumerated()), id: \.element.id) { index, budget in
                                if index > 0 { Divider().padding(.leading, 18) }
                                if let limit = budget.limits.first {
                                    BudgetProgressRow(name: budget.name, limit: limit, daysLeft: period.daysRemaining(from: .now))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 12)
                                } else {
                                    HStack {
                                        Text(budget.name)
                                        Spacer()
                                        MoneyList(values: budget.spent)
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                }
                            }
                        }
                        .luzzyCard()
                        if active.isEmpty {
                            Text("No hay presupuestos. Créalos en Firefly III y aparecerán aquí.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await load() }
        .task(id: period) { await load() }
    }

    private func load() async {
        let period = period
        let source = session.dataSource
        await resource.load(key: CacheKey.budgets(period), session: session) {
            try await source.budgets.budgets(in: period)
        }
    }
}

private struct SummaryCard: View {
    let budgets: [Budget]
    let period: DateInterval

    var body: some View {
        let limits = budgets.compactMap(\.limits.first)
        let total = limits.map(\.amount).totalsByCurrency().first
        let spent = limits.map(\.spent).totalsByCurrency().first
        let progress: Double = {
            guard let total, let spent, total.amount > 0 else { return 0 }
            return NSDecimalNumber(decimal: spent.amount / total.amount).doubleValue
        }()

        HStack(spacing: 20) {
            ProgressRing(progress: progress)
                .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 4) {
                Text("Disponible").font(.footnote).foregroundStyle(.secondary)
                if let total, let spent {
                    MoneyText(Money(total.amount - spent.amount, total.currency), coloring: .negativeHighlight)
                        .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        MoneyText(spent)
                        Text("de")
                        MoneyText(total)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text("—").font(.largeTitle.bold())
                }
                Text("Quedan \(period.daysRemaining(from: .now)) días")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .luzzyCard(cornerRadius: LuzzyTheme.heroCornerRadius)
    }
}

/// Fila de presupuesto con barra de progreso.
struct BudgetProgressRow: View {
    let name: String
    let limit: BudgetLimit
    var daysLeft: Int? = nil
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(compact ? .subheadline.weight(.semibold) : .body)
                Spacer()
                HStack(spacing: 2) {
                    MoneyText(limit.spent)
                    Text(verbatim: "/")
                    MoneyText(limit.amount)
                }
                .font(LuzzyTheme.amountFont(.subheadline, weight: limit.isOverspent ? .semibold : .regular))
                .foregroundStyle(limit.isOverspent ? LuzzyTheme.negative : .secondary)
            }
            ProgressBar(progress: limit.progress, tint: limit.isOverspent ? LuzzyTheme.negative : LuzzyTheme.accent)
            if limit.isOverspent {
                HStack(spacing: 4) {
                    Text("Excedido en")
                    MoneyText(limit.remaining.magnitude)
                }
                .font(.caption)
                .foregroundStyle(LuzzyTheme.negative)
            } else if !compact {
                HStack(spacing: 4) {
                    Text("Quedan")
                    MoneyText(limit.remaining)
                    if let daysLeft, daysLeft > 0 {
                        Text(verbatim: "·")
                        MoneyText(Money(limit.remaining.amount / Decimal(daysLeft), limit.remaining.currency))
                        Text("al día")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
