import SQLKitEngine

class TestModel: Model {
    static let schema: SqlSchemaIdentifier = .init("test_models")
    
    public var id: Int?
    public var value: String
    public var uniqueValue: String
    
    public init(id: Int? = nil, value: String, uniqueValue: String) {
        self.id = id
        self.value = value
        self.uniqueValue = uniqueValue
    }
}
