import SQLKit
import Foundation

public struct SqlSchemaIdentifier: SQLExpression {
    
    public var schema: String
    
    public var table: String
    
    @inlinable
    public init(_ table: String, schema: String = "") {
        self.table = table
        self.schema = schema
    }
    
    @inlinable
    public func serialize(to serializer: inout SQLSerializer) {
        if self.schema.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
            serializer.dialect.identifierQuote.serialize(to: &serializer)
            serializer.write(self.schema)
            serializer.dialect.identifierQuote.serialize(to: &serializer)
            serializer.write(".")
        }
        serializer.dialect.identifierQuote.serialize(to: &serializer)
        serializer.write(self.table)
        serializer.dialect.identifierQuote.serialize(to: &serializer)
    }
}

extension SqlSchemaIdentifier: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}
