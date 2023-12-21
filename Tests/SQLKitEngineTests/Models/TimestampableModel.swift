import Foundation
import SQLKitEngine

class TimestampableModel: Timestampable {
    static let schema: SqlSchemaIdentifier = .init("timestampable_models")
    
    public var id: Int?
    public var value: String
    public var uniqueValue: String
    
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: Int? = nil, value: String, uniqueValue: String) {
        self.id = id
        self.value = value
        self.uniqueValue = uniqueValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
