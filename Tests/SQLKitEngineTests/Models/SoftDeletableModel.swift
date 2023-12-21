import Foundation
import SQLKitEngine

class SoftDeletableModel: SoftDeletable {
    static let schema: SqlSchemaIdentifier = .init("softdeletable_models")
    
    public var id: Int?
    public var value: String
    public var uniqueValue: String
    
    public var isDeleted: Bool
    public var deletedAt: Date?
    
    public init(id: Int? = nil, value: String, uniqueValue: String) {
        self.id = id
        self.value = value
        self.uniqueValue = uniqueValue
        self.isDeleted = false
    }
}
