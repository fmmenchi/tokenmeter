import AppIntents
import TokenMeterCore
import WidgetKit

/// An account a widget can show: a card of the panel, named by its id and title (ADR 0018).
struct AccountEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
    static let defaultQuery = AccountQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

/// The accounts on offer are the cards of the snapshot the widget reads: the panel's, in its order, a hidden one left out.
struct AccountQuery: EntityQuery {
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        accounts().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AccountEntity] { accounts() }

    private func accounts() -> [AccountEntity] {
        (SnapshotStore.appGroupStore()?.read()?.providers ?? []).map { AccountEntity(id: $0.provider.rawValue, title: $0.title) }
    }
}

/// What the person sets with Edit on a widget: the account it shows. None set, the widget shows the first card.
struct ChooseAccountIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Account"
    static let description = IntentDescription("The account this widget shows.")

    @Parameter(title: "Account")
    var account: AccountEntity?
}
