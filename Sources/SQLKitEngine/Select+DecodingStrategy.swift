import SQLKit

public extension SQLQueryFetcher {
    func first<D>(_ decoding: D.Type, keyDecodingStrategy: SQLRowDecoder.KeyDecodingStrategy) async throws -> D? where D: Decodable {
        try await self.first(decoding: D.self, keyDecodingStrategy: keyDecodingStrategy).get()
    }
    
    func all<D>(_ decoding: D.Type, keyDecodingStrategy: SQLRowDecoder.KeyDecodingStrategy) async throws -> [D] where D: Decodable {
        try await self.all(decoding: D.self, keyDecodingStrategy: keyDecodingStrategy).get()
    }
}

extension SQLQueryFetcher {
    public func first<D: Decodable>(decoding: D.Type, keyDecodingStrategy: SQLRowDecoder.KeyDecodingStrategy) -> EventLoopFuture<D?> {
        var rowDecoder = SQLRowDecoder()
        rowDecoder.prefix = nil
        rowDecoder.keyDecodingStrategy = keyDecodingStrategy
        return self.first().flatMapThrowing {
            try $0?.decode(model: D.self, with: rowDecoder)
        }
    }
    
    public func all<D: Decodable>(decoding: D.Type, keyDecodingStrategy: SQLRowDecoder.KeyDecodingStrategy) -> EventLoopFuture<[D]> {
        var rowDecoder = SQLRowDecoder()
        rowDecoder.prefix = nil
        rowDecoder.keyDecodingStrategy = keyDecodingStrategy
        return self.all().flatMapThrowing {
            try $0.map {
                try $0.decode(model: D.self, with: rowDecoder)
            }
        }
    }
}
