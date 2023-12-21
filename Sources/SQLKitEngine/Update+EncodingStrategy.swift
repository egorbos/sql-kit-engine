import SQLKit

extension SQLQueryEncoder {
    public init(keyEncodingStrategy: KeyEncodingStrategy, nilEncodingStrategy: NilEncodingStrategy) {
        self.init()
        self.keyEncodingStrategy = keyEncodingStrategy
        self.nilEncodingStrategy = nilEncodingStrategy
    }
}

extension SQLColumnUpdateBuilder {
    @inlinable
    @discardableResult
    public func set<E>(
        _ model: E,
        keyEncodingStrategy: SQLQueryEncoder.KeyEncodingStrategy,
        nilEncodingStrategy: SQLQueryEncoder.NilEncodingStrategy
    ) throws -> Self where E: Encodable {
        try SQLQueryEncoder(keyEncodingStrategy: keyEncodingStrategy, nilEncodingStrategy: nilEncodingStrategy)
            .encode(model)
            .reduce(self) {
                $0.set(SQLColumn($1.0), to: $1.1)
            }
    }
}
