import SQLKit
import Foundation

public protocol Model: AnyObject, Codable where IdType: Codable, IdType: Hashable {
    associatedtype IdType
    
    static var schema: SqlSchemaIdentifier { get }
    var id: IdType? { get set }
}

extension Model {
    public static func all(on db: SQLDatabase, builder: ((SQLSelectBuilder) -> SQLSelectBuilder) = { $0 }) async throws -> [Self] {
        return try await builder(
            db.select().column("*").from(Self.schema)
        ).all(Self.self, keyDecodingStrategy: .convertFromSnakeCase)
    }
    
    public static func first(on db: SQLDatabase, builder: ((SQLSelectBuilder) -> SQLSelectBuilder) = { $0 }) async throws -> Self? {
        return try await builder(
            db.select().column("*").from(Self.schema)
        ).first(Self.self, keyDecodingStrategy: .convertFromSnakeCase)
    }
    
    public static func count(on db: SQLDatabase, builder: ((SQLSelectBuilder) -> SQLSelectBuilder) = { $0 }) async throws -> Int {
        let result = try await builder(
            db.select().column(SQLFunction("count")).from(Self.schema)
        ).first()
        
        guard let count = result else {
            return 0
        }
        
        return try count.decode(column: "count()", as: Int.self)
    }
    
    public func insert(on db: SQLDatabase) async throws {
        self.id = try await db.insert(into: Self.schema)
            .model(
                self,
                keyEncodingStrategy: .convertToSnakeCase,
                nilEncodingStrategy: .asNil
            )
            .returning("id")
            .first()?.decode(column: "id", as: IdType.self)
    }
    
    public func insert(on db: SQLDatabase, builder: (SQLInsertBuilder) -> SQLInsertBuilder) async throws {
        self.id = try await builder(
            db.insert(into: Self.schema)
                .model(
                    self,
                    keyEncodingStrategy: .convertToSnakeCase,
                    nilEncodingStrategy: .asNil
                )
        )
        .returning("id")
        .first()?.decode(column: "id", as: IdType.self)
    }
    
    public func update(on db: SQLDatabase) async throws {
        try await db.update(Self.schema)
            .set(
                self,
                keyEncodingStrategy: .convertToSnakeCase,
                nilEncodingStrategy: .asNil
            )
            .where("id", .equal, try self.requireId())
            .run()
    }
    
    @discardableResult
    public static func update(on db: SQLDatabase, builder: (SQLUpdateBuilder) -> SQLUpdateBuilder) async throws -> [IdType] {
        return try await builder(
            db.update(Self.schema)
        )
        .returning("id")
        .all()
        .map { try $0.decode(column: "id", as: IdType.self) }
    }
    
    public func delete(on db: SQLDatabase) async throws {
        try await db.delete(from: Self.schema)
            .where("id", .equal, try self.requireId())
            .run()
    }
    
    @discardableResult
    public static func delete(on db: SQLDatabase, builder: (SQLDeleteBuilder) -> SQLDeleteBuilder) async throws -> [IdType] {
        return try await builder(
            db.delete(from: Self.schema)
        )
        .returning("id")
        .all()
        .map { try $0.decode(column: "id", as: IdType.self) }
    }
    
    public func requireId() throws -> IdType {
        guard let id = self.id else {
            throw SQLKitEngineError.idRequired
        }
        return id
    }
}
