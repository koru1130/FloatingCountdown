import Combine
import Foundation

/// The menu-facing list of active countdowns.
///
/// Every countdown still owns an independent ``CountdownStore``. The
/// collection only publishes membership changes; rows observe their own store
/// directly so one timer ticking does not rebuild the state of another timer.
@MainActor
final class CountdownCollection: ObservableObject {
    @Published private(set) var stores: [CountdownStore] = []

    var isEmpty: Bool { stores.isEmpty }
    var count: Int { stores.count }

    func contains(_ id: UUID) -> Bool {
        stores.contains { $0.id == id }
    }

    func add(_ store: CountdownStore) {
        guard !contains(store.id) else { return }
        stores.append(store)
    }

    func remove(_ id: UUID) {
        stores.removeAll { $0.id == id }
    }
}
