import SQLKit
import Foundation

public protocol Timestampable where Self: Model {
    /// The date when the object was inserted into the database.
    var createdAt: Date { get set }
    
    /// The date when the object was last updated in the database.
    var updatedAt: Date { get set }
}

extension Timestampable {
    public func insert(on db: SQLDatabase) async throws {
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
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
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
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
        self.updatedAt = Date()
        
        try await db.update(Self.schema)
            .set(
                self,
                keyEncodingStrategy: .convertToSnakeCase,
                nilEncodingStrategy: .asNil
            )
            .where("id", .equal, self.id)
            .returning("id")
            .run()
    }
    
    @discardableResult
    public static func update(on db: SQLDatabase, builder: (SQLUpdateBuilder) -> SQLUpdateBuilder) async throws -> [IdType] {
        let now = Date()
        
        return try await builder(
            db.update(Self.schema)
                .set("updated_at", to: now)
        )
        .returning("id")
        .all()
        .map { try $0.decode(column: "id", as: IdType.self) }
    }
}
