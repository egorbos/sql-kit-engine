import SQLKit
import Foundation

extension Array where Element: Model {
    @discardableResult
    public func insert(on db: SQLDatabase) async throws -> [Element.IdType] {
        if Element.self is any Timestampable.Type {
            let now = Date()
            for case let element as any Timestampable in self {
                element.createdAt = now
                element.updatedAt = now
            }
        }
        return try await db.insert(into: Element.schema)
            .models(
                self,
                keyEncodingStrategy: .convertToSnakeCase,
                nilEncodingStrategy: .asNil
            )
            .returning("id")
            .all()
            .map { try $0.decode(column: "id", as: Element.IdType.self) }
    }
    
    @discardableResult
    public func insert(on db: SQLDatabase, builder: (SQLInsertBuilder) -> SQLInsertBuilder) async throws -> [Element.IdType] {
        if Element.self is any Timestampable.Type {
            let now = Date()
            for case let element as any Timestampable in self {
                element.createdAt = now
                element.updatedAt = now
            }
        }
        return try await builder(
            db.insert(into: Element.schema)
                .models(
                    self,
                    keyEncodingStrategy: .convertToSnakeCase,
                    nilEncodingStrategy: .asNil
                )
        )
        .returning("id")
        .all()
        .map { try $0.decode(column: "id", as: Element.IdType.self) }
    }
    
    @discardableResult
    public func delete(on db: SQLDatabase) async throws -> [Element.IdType] {
        if Element.self is any SoftDeletable.Type {
            let now = Date()
            for case let element as any SoftDeletable in self {
                element.isDeleted = true
                element.deletedAt = now
            }
            return try await db.update(Element.schema)
                .set("is_deleted", to: true)
                .set("deleted_at", to: now)
                .where("id", .in, self.map { try $0.requireId() })
                .returning("id")
                .all()
                .map { try $0.decode(column: "id", as: Element.IdType.self) }
        }
        
        return try await db.delete(from: Element.schema)
            .where("id", .in, self.map { try $0.requireId() })
            .returning("id")
            .all()
            .map { try $0.decode(column: "id", as: Element.IdType.self) }
    }
}
