import Foundation

/// Estado de carga de una pantalla, conservando el último valor conocido.
public enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading(previous: Value?)
    /// `isStale` indica que el valor viene de la caché y se está refrescando o no se pudo refrescar.
    case loaded(Value, updatedAt: Date?, isStale: Bool)
    case failed(DataSourceError, previous: Value?)

    public var value: Value? {
        switch self {
        case .idle: nil
        case .loading(let previous): previous
        case .loaded(let value, _, _): value
        case .failed(_, let previous): previous
        }
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var error: DataSourceError? {
        if case .failed(let error, _) = self { return error }
        return nil
    }

    public var isStale: Bool {
        switch self {
        case .loaded(_, _, let stale): stale
        case .failed(_, let previous): previous != nil
        default: false
        }
    }
}
