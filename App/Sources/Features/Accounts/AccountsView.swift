import LuzzyCore
import LuzzyUI
import SwiftUI

struct AccountsView: View {
    let session: Session

    @State private var kind: AccountKind = .asset
    private static let kinds: [AccountKind] = [.asset, .expense, .revenue, .liability]
    @State private var resources = Dictionary(uniqueKeysWithValues: Self.kinds.map { ($0, Resource<[Account]>()) })
    @Environment(AppModel.self) private var app

    var body: some View {
        if let accountID = app.accessScope.limitedAccountID {
            SingleAccountView(session: session, accountID: accountID)
        } else {
            allAccounts
        }
    }

    private var allAccounts: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Tipo de cuenta", selection: $kind) {
                        ForEach(Self.kinds, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                let state = resource(for: kind).state
                if let accounts = state.value {
                    totalSection(accounts)
                    ForEach(groups(accounts), id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.accounts) { account in
                                NavigationLink(value: account) {
                                    AccountRow(account: account)
                                }
                            }
                        }
                    }
                } else if let error = state.error {
                    Section { Text(error.userMessage).foregroundStyle(.secondary) }
                } else {
                    Section { ProgressView().frame(maxWidth: .infinity) }
                }
            }
            .navigationTitle("Cuentas")
            .navigationDestination(for: Account.self) { account in
                AccountDetailView(session: session, account: account)
            }
            .refreshable { await load(kind) }
            .task(id: kind) { await load(kind) }
        }
    }

    private func resource(for kind: AccountKind) -> Resource<[Account]> {
        resources[kind] ?? Resource<[Account]>()
    }

    private func load(_ kind: AccountKind) async {
        let resource = resource(for: kind)
        let source = session.dataSource
        await resource.load(key: CacheKey.accounts(kind), session: session) {
            try await source.accounts.accounts(kind: kind, balanceDate: nil)
                .filter(\.isActive)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private func totalSection(_ accounts: [Account]) -> some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.totalTitle).font(.footnote).foregroundStyle(.secondary)
                    ForEach(accounts.map(\.balance).totalsByCurrency(), id: \.currency.code) { total in
                        MoneyText(kind == .expense || kind == .revenue ? total.magnitude : total)
                            .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                            .minimumScaleFactor(0.6)
                    }
                }
                Spacer()
                Text("\(accounts.count) cuentas").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private struct AccountGroup {
        let title: LocalizedStringKey
        let accounts: [Account]
    }

    private func groups(_ accounts: [Account]) -> [AccountGroup] {
        guard kind == .asset else { return [AccountGroup(title: kind.title, accounts: accounts)] }
        let order: [(AccountRole?, LocalizedStringKey)] = [
            (.defaultAsset, "Cuentas corrientes"),
            (.sharedAsset, "Cuentas compartidas"),
            (.savingAsset, "Ahorro"),
            (.cashWallet, "Efectivo"),
            (.creditCard, "Tarjetas de crédito"),
            (nil, "Otras"),
        ]
        return order.compactMap { role, title in
            let matching = accounts.filter { $0.role == role }
            return matching.isEmpty ? nil : AccountGroup(title: title, accounts: matching)
        }
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            InitialAvatar(account.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                if let masked = account.maskedNumber {
                    Text(masked).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            MoneyText(account.kind == .expense || account.kind == .revenue ? account.balance.magnitude : account.balance, coloring: .negativeHighlight)
                .font(LuzzyTheme.amountFont())
        }
        .padding(.vertical, 4)
    }
}

extension AccountKind {
    var title: LocalizedStringKey {
        switch self {
        case .asset: "Activo"
        case .expense: "Gastos"
        case .revenue: "Ingresos"
        case .liability: "Pasivos"
        case .cash: "Efectivo"
        case .other: "Otras"
        }
    }

    var totalTitle: LocalizedStringKey {
        switch self {
        case .asset: "Saldo total"
        case .expense: "Total gastado"
        case .revenue: "Total ingresado"
        case .liability: "Deuda pendiente"
        default: "Total"
        }
    }
}

/// Detalle de una cuenta con sus movimientos.
struct AccountDetailView: View {
    let session: Session
    let account: Account

    @State private var resource = Resource<Page<TransactionGroup>>()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saldo").font(.footnote).foregroundStyle(.secondary)
                    MoneyText(account.balance, coloring: .negativeHighlight)
                        .font(LuzzyTheme.amountFont(.largeTitle, weight: .bold))
                    if let masked = account.maskedNumber {
                        Text(masked).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            if let page = resource.value {
                ForEach(DaySection.make(from: page.items)) { section in
                    Section { ForEach(section.groups) { TransactionRow(group: $0) } } header: { DayTitle(day: section.day) }
                }
            } else if let error = resource.state.error {
                Text(error.userMessage).foregroundStyle(.secondary)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(account.name)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        let query = TransactionQuery(accountID: account.id, page: 1, pageSize: 50)
        let source = session.dataSource
        await resource.load(key: CacheKey.transactions(query), session: session) {
            try await source.transactions.transactions(query)
        }
    }
}

/// Cuentas en el plan gratuito: la cuenta elegida y la invitación a Premium.
private struct SingleAccountView: View {
    let session: Session
    let accountID: EntityID

    @State private var resource = Resource<Account>()
    @State private var changingAccount = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let account = resource.value {
                        NavigationLink(value: account) {
                            AccountRow(account: account)
                        }
                    } else if let error = resource.state.error {
                        Text(error.userMessage).foregroundStyle(.secondary)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Tu cuenta")
                } footer: {
                    Button("Cambiar de cuenta") { changingAccount = true }
                        .font(.footnote.weight(.semibold))
                }

                Section {
                    PremiumTeaser(feature: .multipleAccounts)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Cuentas")
            .navigationDestination(for: Account.self) { account in
                AccountDetailView(session: session, account: account)
            }
            .refreshable { await load() }
            .task(id: accountID) { await load() }
            .sheet(isPresented: $changingAccount) {
                FreeAccountPickerView(session: session, isChanging: true)
            }
        }
    }

    private func load() async {
        let source = session.dataSource
        let accountID = accountID
        await resource.load(key: "account.\(accountID)", session: session) {
            try await source.accounts.account(id: accountID)
        }
    }
}
