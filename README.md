# SQLKitEngine

<p align="center">
    <a href="LICENSE">
        <img src="https://img.shields.io/badge/LICENSE-MIT-green.svg" alt="MIT License">
    </a>
    <a href="https://swift.org">
        <img src="https://img.shields.io/badge/swift-5.6-orange.svg" alt="Swift 5.6">
    </a>
</p>

SQLKitEngine - lightweight tool for simple SQL database CRUD operations with application models, written arround the [Vapor SQLKit](https://github.com/vapor/sql-kit).

## Supported Databases

These database packages are drivers for SQLKit:

- [vapor/postgres-kit](https://github.com/vapor/postgres-kit): PostgreSQL
- [vapor/mysql-kit](https://github.com/vapor/mysql-kit): MySQL and MariaDB
- [vapor/sqlite-kit](https://github.com/vapor/sqlite-kit): SQLite

Use the appropriate project's documentation for create a database connection.

## Usage example

Create a model that conforms `Model` protocol.

```swift
import SQLKitEngine

class SomeModel: Model {
    static let schema: SqlSchemaIdentifier = .init("some_models") // for set schema, also use `schema` initialization parameter
    
    public var id: Int?
    public var value: String
    public var uniqueValue: String
    
    public init(id: Int? = nil, value: String, uniqueValue: String) {
        self.id = id
        self.value = value
        self.uniqueValue = uniqueValue
    }
}
```

`SQLKitEngine` use `camel_case` key encoding/decoding strategy, which means that your table `some_models` structure should have the following field names: `id`, `value`, `unique_value`. Actions for encoding/decoding field names are performed automatically when preparing a SQL query.

You can also use the `SQLKit` framework to create your database structure:

```swift
import SQLKit

var db: SQLDatabase = ... // use documentation of driver for your database type, to create connection

try await self.db.create(table: "some_models")
            .ifNotExists()
            .column("id", type: .int, .primaryKey)
            .column("value", type: .text)
            .column("unique_value", type: .text)
            .run()
try await self.db.create(index: "some_models_unique_idx")
    .on("some_models")
    .column("unique_value")
    .unique()
    .run()
```

### Insert

```swift
let entity = SomeModel(value: "foo", uniqueValue: UUID().uuidString)
try await entity.insert(on: self.db)
```

### Upsert

The code bellow updates the `value` field if an object with the given `unique_value` field value already exists.

```swift
let someValue = ...
let entity = SomeModel(value: "bar", uniqueValue: someValue)
try await entity.insert(on: self.db) { $0
    .onConflict(with: "unique_value") { updateBuilder in
        updateBuilder.set(excludedValueOf: "value")
    }
}
```

### Select

For more information of querying (`where`, `orWhere`, `limit`, `offset`, `orderBy`, etc.) see [SQLKit](https://github.com/vapor/sql-kit) documentation.

```swift
let entities = try await SomeModel.all(on: self.db)

let entities = try await SomeModel.all(on: self.db) { $0
    .where("value", .equal, "foo")
}

let entity = try await SomeModel.first(on: self.db)

let entity = try await SomeModel.first(on: self.db) { $0
    .where("value", .equal, "bar")
}
```

### Count

```swift
let allCount = try await SomeModel.count(on: self.db)

let fooCount = try await SomeModel.count(on: self.db) { $0
    .where("value", .equal, "foo")
}
```

### Update

You can use the entity inserted, or an entity retrieved from the database.

```swift
let entity = SomeModel(value: "bar", uniqueValue: UUID().uuidString)
try await entity.insert(on: self.db)
// OR
let entity = try await SomeModel.first(on: self.db) { $0
    .where("value", .equal, "bar")
}

entity.value = "foo"
try await entity.update(on: self.db)
```

Be careful, if an entity does not have an identifier value, an `SQLKitEngineError.idRequired` will be thrown

You can also update objects using a where clause.

```swift
let updatedIds = try await SomeModel.update(on: self.db) { $0
    .set("value", to: "bar")
    .where("value", .equal, "foo")
}
```

### Delete

```swift
let entity = ...
try await entity.delete(on: self.db)
```

Be careful, if an entity does not have an identifier value, an `SQLKitEngineError.idRequired` will be thrown

You can also delete objects using a where clause.

```swift
let deletedIds = try await SomeModel.delete(on: self.db) { $0
    .where("value", .equal, "foo")
}
// OR
try await SomeModel.delete(on: self.db) { $0
    .where("id", .equal, 123)
}
```
### Timestampable

To track the creation/update time of an entity, you can implement a `Timestampable` protocol in your model and also create corresponding fields (`created_at`, `updated_at`) with `Timestamp` data type in the database model table.

```swift
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
```

### SoftDeletable

To track the fact and time of entity deletion, you can implement the `SoftDeletable` protocol in your model, and also create the corresponding fields (`is_deleted` - `Boolean`, `deleted_at` - `Timestamp allow null`) in the database model table.

```swift
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
```

## Adding `SQLKitEngine` to your project

### Swift Package Manager

Add the following line to the 'dependencies' section of the `Package.swift` file:

```swift
dependencies: [
  // .package(url: "https://github.com/vapor/sqlite-kit.git", from: "4.4.1"),
  // .package(url: "https://github.com/vapor/postgres-kit.git", from: "2.12.2"),
  // .package(url: "https://github.com/vapor/mysql-kit.git", from: "4.7.1"),
  .package(url: "https://github.com/egorbos/sql-kit-engine.git", from: "0.1.0"),
],
```

### CocoaPods

Add the following line to the `Podfile`:

```text
pod 'SQLKitEngine', :git => "https://github.com/egorbos/sql-kit-engine.git", :tag => "0.1.0"
```

## Compatibility

Platform | Minimum version
--- | ---
macOS | 10.15 (Catalina)
iOS, iPadOS & tvOS | 13
watchOS | 6

## License

SQLKitEngine is available under the MIT license. See the LICENSE file for more info.