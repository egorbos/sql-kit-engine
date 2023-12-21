import XCTest
import SQLKit
import SQLiteKit
@testable import SQLKitEngine

final class TimestampableTests: XCTestCase {
    var db: any SQLDatabase { self.connection.sql() }
    
    var eventLoopGroup: (any EventLoopGroup)!
    var threadPool: NIOThreadPool!
    var connection: SQLiteConnection!

    override func setUp() async throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()
        self.connection = try await SQLiteConnectionSource(
            configuration: .init(storage: .memory, enableForeignKeys: false),
            threadPool: self.threadPool
        ).makeConnection(logger: .init(label: "test"), on: self.eventLoopGroup.any()).get()
        
        try await self.db.create(table: "timestampable_models")
            .ifNotExists()
            .column("id", type: .int, .primaryKey)
            .column("value", type: .text)
            .column("unique_value", type: .text)
            .column("created_at", type: .real)
            .column("updated_at", type: .real)
            .run()
        try await self.db.create(index: "timestampable_models_idx")
            .on("timestampable_models")
            .column("unique_value")
            .unique()
            .run()
    }
    
    override func tearDown() async throws {
        try await self.connection.close().get()
        self.connection = nil
        try await self.threadPool.shutdownGracefully()
        self.threadPool = nil
        try await self.eventLoopGroup.shutdownGracefully()
        self.eventLoopGroup = nil
    }
    
    func testInsertTimestampableModel() async throws {
        let model = TimestampableModel(value: "test", uniqueValue: UUID().uuidString)

        let createdAt = model.createdAt
        let updatedAt = model.updatedAt
        
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())
        XCTAssertGreaterThan(model.createdAt, createdAt)
        XCTAssertGreaterThan(model.updatedAt, updatedAt)
    }
    
    func testUpsertTimestampableModel() async throws {
        let uuidValue = UUID().uuidString
        
        let model = TimestampableModel(value: "test", uniqueValue: uuidValue)
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())
        
        let dbModel = try await TimestampableModel.first(on: self.db)
        
        let newModel = TimestampableModel(value: "foo", uniqueValue: uuidValue)
        try await newModel.insert(on: self.db) { $0
            .onConflict(with: "unique_value") { updateBuilder in
                updateBuilder
                    .set(excludedValueOf: "value")
                    .set(excludedValueOf: "updated_at")
            }
        }
     
        let upsertedModel = try await TimestampableModel.first(on: self.db)
        
        XCTAssertNotNil(upsertedModel)
        XCTAssertEqual(upsertedModel?.createdAt, dbModel?.createdAt)
        XCTAssertGreaterThan(upsertedModel!.updatedAt, dbModel!.updatedAt)
    }
    
    func testUpdateTimestampableModel() async throws {
        let model = TimestampableModel(value: "test", uniqueValue: UUID().uuidString)
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())

        let createdAt = model.createdAt
        let updatedAt = model.updatedAt
        
        model.value = "foo"
        try await model.update(on: self.db)
        
        let updatedModel = try await TimestampableModel.first(on: self.db)
        
        XCTAssertNotNil(updatedModel)
        XCTAssertEqual(updatedModel?.id, 1)
        XCTAssertEqual(updatedModel?.value, "foo")
        XCTAssertEqual(updatedModel?.createdAt, createdAt)
        XCTAssertGreaterThan(updatedModel!.updatedAt, updatedAt)
    }
    
    func testUpdateTimestampableModelsWhereClause() async throws {
        let firstModel = TimestampableModel(value: "foo", uniqueValue: UUID().uuidString)
        try await firstModel.insert(on: self.db)
        
        let secondModel = TimestampableModel(value: "test", uniqueValue: UUID().uuidString)
        try await secondModel.insert(on: self.db)
        
        let updatedId = try await TimestampableModel.update(on: self.db) { $0
            .set("value", to: "bar")
            .where("value", .equal, "foo")
        }
        
        XCTAssertEqual(updatedId.count, 1)
        XCTAssertEqual(updatedId, [1])
        
        let updatedModel = try await TimestampableModel.first(on: self.db) { $0
            .where("value", .equal, "bar")
        }
        
        XCTAssertNotNil(updatedModel)
        XCTAssertEqual(updatedModel?.createdAt, firstModel.createdAt)
        XCTAssertGreaterThan(updatedModel!.updatedAt, firstModel.updatedAt)
    }
}
