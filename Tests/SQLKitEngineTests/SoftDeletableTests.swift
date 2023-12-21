import XCTest
import SQLKit
import SQLiteKit
@testable import SQLKitEngine

final class SoftDeletableTests: XCTestCase {
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
        
        try await self.db.create(table: "softdeletable_models")
            .ifNotExists()
            .column("id", type: .int, .primaryKey)
            .column("value", type: .text)
            .column("unique_value", type: .text)
            .column("is_deleted", type: .smallint)
            .column("deleted_at", type: .real)
            .run()
        try await self.db.create(index: "softdeletable_models_idx")
            .on("softdeletable_models")
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
    
    func testDeleteSoftDeletableModel() async throws {
        let model = SoftDeletableModel(value: "test", uniqueValue: UUID().uuidString)
        try await model.insert(on: self.db)
        
        XCTAssertFalse(model.isDeleted)
        XCTAssertNil(model.deletedAt)
        
        try await model.delete(on: self.db)
        
        XCTAssertTrue(model.isDeleted)
        XCTAssertNotNil(model.deletedAt)
        
        let deletedModel = try await SoftDeletableModel.first(on: self.db)
        
        XCTAssertNotNil(deletedModel)
        XCTAssertTrue(deletedModel!.isDeleted)
        XCTAssertNotNil(deletedModel?.deletedAt)
    }
    
    func testDeleteSoftDeletableModelWhereClause() async throws {
        let model = SoftDeletableModel(value: "test", uniqueValue: UUID().uuidString)
        try await model.insert(on: self.db)
        
        XCTAssertFalse(model.isDeleted)
        XCTAssertNil(model.deletedAt)
        
        try await SoftDeletableModel.delete(on: self.db) { $0
            .where("id", .equal, 1)
        }
        
        let deletedModel = try await SoftDeletableModel.first(on: self.db)
        
        XCTAssertNotNil(deletedModel)
        XCTAssertTrue(deletedModel!.isDeleted)
        XCTAssertNotNil(deletedModel?.deletedAt)
    }
}
