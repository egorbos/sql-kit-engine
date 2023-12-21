import SQLKit
import Foundation

public protocol SoftDeletable where Self: Model {
    /// A flag indicating that the object has been removed from the database.
    var isDeleted: Bool { get set }
    
    /// The date when the object was deleted from the database.
    var deletedAt: Date? { get set }
}

extension SoftDeletable {
    public func delete(on db: SQLDatabase) async throws {
        self.isDeleted = true
        self.deletedAt = Date()
        
        try await db.update(Self.schema)
            .set("is_deleted", to: true)
            .set("deleted_at", to: self.deletedAt)
            .where("id", .equal, try self.requireId())
            .run()
    }
    
    @discardableResult
    public static func delete(on db: SQLDatabase, builder: (SQLUpdateBuilder) -> SQLUpdateBuilder) async throws -> [IdType] {
        let now = Date()
        
        return try await builder(
            db.update(Self.schema)
                .set("is_deleted", to: true)
                .set("deleted_at", to: now)
        )
        .returning("id")
        .all()
        .map { try $0.decode(column: "id", as: IdType.self) }
    }
}
