import Foundation
import LuzzyCore
import Observation

/// Estado observable de un recurso que se carga de la caché y luego del origen.
@MainActor
@Observable
final class Resource<Value: Codable & Sendable> {
    private(set) var state: Loadable<Value> = .idle

    var value: Value? { state.value }

    func load(
        key: String?,
        session: Session,
        fetch: @escaping @Sendable () async throws -> Value
    ) async {
        state = .loading(previous: state.value)
        do {
            let fresh: Value
            if let key {
                fresh = try await session.fetcher.fetch(key: key, cached: { [weak self] hit in
                    await self?.showCached(hit)
                }, remote: fetch)
            } else {
                fresh = try await fetch()
            }
            state = .loaded(fresh, updatedAt: .now, isStale: false)
        } catch is CancellationError {
            if let previous = state.value { state = .loaded(previous, updatedAt: nil, isStale: true) }
        } catch let error as DataSourceError {
            if error == .cancelled, let previous = state.value {
                state = .loaded(previous, updatedAt: nil, isStale: true)
            } else {
                state = .failed(error, previous: state.value)
            }
        } catch {
            state = .failed(.unknown(String(describing: type(of: error))), previous: state.value)
        }
    }

    func set(_ value: Value) {
        state = .loaded(value, updatedAt: .now, isStale: false)
    }

    private func showCached(_ hit: CachedValue<Value>) {
        state = .loading(previous: hit.value)
    }
}
