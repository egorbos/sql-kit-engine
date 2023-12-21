import XCTest
import SQLKit
import SQLiteKit
@testable import SQLKitEngine

final class ModelsArrayTests: XCTestCase {
    var db: any SQLDatabase { self.connection.sql() }
    
    var eventLoopGroup: (any EventLoopGroup)!
    var threadPool: NIOThreadPool!
    var connection: SQLiteConnection!

    override func setUp() async throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()
        self.connection = try await SQLiteConnectionSource(
            configuration: .init(storage: .memory),
            threadPool: self.threadPool
        ).makeConnection(logger: .init(label: "test"), on: self.eventLoopGroup.any()).get()
        
        try await self.db.create(table: "test_models")
            .ifNotExists()
            .column("id", type: .int, .primaryKey)
            .column("value", type: .text)
            .column("unique_value", type: .text)
            .run()
        try await self.db.create(index: "test_models_idx")
            .on("test_models")
            .column("unique_value")
            .unique()
            .run()
        try await self.db.create(table: "softdeletable_models")
            .ifNotExists()
            .column("id", type: .int, .primaryKey)
            .column("value", type: .text)
            .column("unique_value", type: .text)
            .column("is_deleted", type: .smallint)
            .column("deleted_at", type: .real)
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
    
    func testInsertArrayModels() async throws {
        let models = [
            TestModel(value: "test", uniqueValue: UUID().uuidString),
            TestModel(value: "test", uniqueValue: UUID().uuidString),
            TestModel(value: "test", uniqueValue: UUID().uuidString),
            ]
        let insertIds = try await models.insert(on: self.db)
        
        XCTAssertEqual(insertIds.count, 3)
        XCTAssertEqual(insertIds, [1, 2, 3])
    }
    
    func testUpsertArrayModels() async throws {
        let uids = [UUID().uuidString, UUID().uuidString, UUID().uuidString]
        let models = [
            TestModel(value: "test", uniqueValue: uids[0]),
            TestModel(value: "test", uniqueValue: uids[1]),
            TestModel(value: "test", uniqueValue: uids[2]),
        ]
        
        let insertIds = try await models.insert(on: self.db)
        
        XCTAssertEqual(insertIds.count, 3)
        XCTAssertEqual(insertIds, [1, 2, 3])
        
        let upsertModels = [
            TestModel(value: "foo", uniqueValue: uids[0]),
            TestModel(value: "foo", uniqueValue: uids[1]),
            TestModel(value: "foo", uniqueValue: uids[2]),
        ]
        
        let upsertIds = try await upsertModels.insert(on: self.db) { $0
            .onConflict(with: "unique_value") { updateBuilder in
                updateBuilder.set(excludedValueOf: "value")
            }
        }
        
        XCTAssertEqual(upsertIds.count, 3)
        XCTAssertEqual(upsertIds, [1, 2, 3])
        
        let count = try await TestModel.count(on: self.db)
        XCTAssertEqual(count, 3)
    }
    
    func testDeleteArrayModels() async throws {
        let models = [
            TestModel(value: "test", uniqueValue: UUID().uuidString),
            TestModel(value: "test", uniqueValue: UUID().uuidString),
            TestModel(value: "test", uniqueValue: UUID().uuidString),
            ]
        try await models.insert(on: self.db)
        
        let dbModels = try await TestModel.all(on: self.db)
        XCTAssertEqual(dbModels.count, 3)
        
        try await dbModels.delete(on: self.db)
        
        let count = try await TestModel.count(on: self.db)
        XCTAssertEqual(count, 0)
    }
    
    func testDeleteArraySoftDeletableModels() async throws {
        let models = [
            SoftDeletableModel(value: "test", uniqueValue: UUID().uuidString),
            SoftDeletableModel(value: "test", uniqueValue: UUID().uuidString),
            SoftDeletableModel(value: "test", uniqueValue: UUID().uuidString),
            ]
        try await models.insert(on: self.db)
        
        var dbModels = try await SoftDeletableModel.all(on: self.db)
        XCTAssertEqual(dbModels.count, 3)
        XCTAssertFalse(dbModels.contains { $0.isDeleted })
        
        try await dbModels.delete(on: self.db)
        
        dbModels = try await SoftDeletableModel.all(on: self.db)
        XCTAssertEqual(dbModels.count, 3)
        XCTAssertEqual(dbModels.filter { $0.isDeleted }.count, 3)
    }
}
