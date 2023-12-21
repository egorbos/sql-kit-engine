import XCTest
import SQLKit
import SQLiteKit
@testable import SQLKitEngine

final class ModelTests: XCTestCase {
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
    }
    
    override func tearDown() async throws {
        try await self.connection.close().get()
        self.connection = nil
        try await self.threadPool.shutdownGracefully()
        self.threadPool = nil
        try await self.eventLoopGroup.shutdownGracefully()
        self.eventLoopGroup = nil
    }
    
    func testGetAllModels() async throws {
        _ = try await self.db.insert(into: "test_models")
            .columns("id", "value", "unique_value")
            .values(SQLLiteral.null, SQLBind("test"), SQLBind(UUID().uuidString))
            .values(SQLLiteral.null, SQLBind("test"), SQLBind(UUID().uuidString))
            .run()
        
        let models = try await TestModel.all(on: self.db)
        
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models.map { $0.id! }, [1, 2])
    }
    
    func testGetModelsWhereClause() async throws {
        _ = try await self.db.insert(into: "test_models")
            .columns("id", "value", "unique_value")
            .values(SQLLiteral.null, SQLBind("foo"), SQLBind(UUID().uuidString))
            .values(SQLLiteral.null, SQLBind("test"), SQLBind(UUID().uuidString))
            .values(SQLLiteral.null, SQLBind("test"), SQLBind(UUID().uuidString))
            .values(SQLLiteral.null, SQLBind("bar"), SQLBind(UUID().uuidString))
            .run()
        
        let models = try await TestModel.all(on: self.db) { $0
            .where("value", .equal, "test")
        }
        
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models.map { $0.id! }, [2, 3])
    }
    
    func testGetFirstModel() async throws {
        _ = try await self.db.insert(into: "test_models")
            .columns("id", "value", "unique_value")
            .values(SQLLiteral.null, SQLBind("foo"), SQLBind(UUID().uuidString))
            .values(SQLLiteral.null, SQLBind("bar"), SQLBind(UUID().uuidString))
            .run()
        
        let model = try await TestModel.first(on: self.db)
        
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.id, 1)
    }
    
    func testGetFirstModelWhereClause() async throws {
        _ = try await self.db.insert(into: "test_models")
            .columns("id", "value", "unique_value")
            .values(SQLLiteral.null, SQLBind("foo"), SQLBind(UUID().uuidString))
            .values(SQLLiteral.null, SQLBind("test"), SQLBind(UUID().uuidString))
            .run()
        
        let model = try await TestModel.first(on: self.db) { $0
            .where("value", .equal, "test")
        }
        
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.id, 2)
    }
    
    func testInsertModel() async throws {
        let model = TestModel(value: "test", uniqueValue: UUID().uuidString)
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())
        
        let dbModel = try await TestModel.first(on: self.db)
        
        XCTAssertNotNil(dbModel)
    }
    
    func testThrowsIdRequiredErrorWhenModelNotInserted() async throws {
        let model = TestModel(value: "test", uniqueValue: UUID().uuidString)
        
        XCTAssertThrowsError(try model.requireId()) { error in
            XCTAssertEqual(error as! SQLKitEngineError, SQLKitEngineError.idRequired)
        }
    }

    
    func testUpsertModel() async throws {
        let uuidValue = UUID().uuidString
        
        let model = TestModel(value: "test", uniqueValue: uuidValue)
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())
        
        let dbModel = try await TestModel.first(on: self.db)
        
        XCTAssertNotNil(dbModel)
        XCTAssertEqual(dbModel?.value, "test")
        XCTAssertEqual(dbModel?.uniqueValue, uuidValue)
        
        let newModel = TestModel(value: "foo", uniqueValue: uuidValue)
        try await newModel.insert(on: self.db) { $0
            .onConflict(with: "unique_value") { updateBuilder in
                updateBuilder.set(excludedValueOf: "value")
            }
        }
     
        let upsertedModel = try await TestModel.first(on: self.db) { $0
            .where("id", .equal, 1)
        }
        
        XCTAssertNotNil(upsertedModel)
        XCTAssertEqual(upsertedModel?.value, "foo")
        XCTAssertEqual(upsertedModel?.uniqueValue, uuidValue)
    }
    
    func testCountModelsInDatabase() async throws {
        try await TestModel(value: "foo", uniqueValue: UUID().uuidString).insert(on: self.db)
        try await TestModel(value: "test", uniqueValue: UUID().uuidString).insert(on: self.db)
        try await TestModel(value: "foo", uniqueValue: UUID().uuidString).insert(on: self.db)
        
        let allCount = try await TestModel.count(on: self.db)
        
        XCTAssertEqual(allCount, 3)
        
        let fooCount = try await TestModel.count(on: self.db) { $0
            .where("value", .equal, "foo")
        }

        XCTAssertEqual(fooCount, 2)
    }
    
    func testUpdateModel() async throws {
        let uuidValue = UUID().uuidString

        let model = TestModel(value: "test", uniqueValue: uuidValue)
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())
        
        model.value = "foo"
        try await model.update(on: self.db)
        
        let updatedModel = try await TestModel.first(on: self.db)
        
        XCTAssertNotNil(updatedModel)
        XCTAssertEqual(updatedModel?.value, "foo")
        XCTAssertEqual(updatedModel?.uniqueValue, uuidValue)
    }
    
    func testUpdateModelsWhereClause() async throws {
        try await TestModel(value: "foo", uniqueValue: UUID().uuidString).insert(on: self.db)
        try await TestModel(value: "test", uniqueValue: UUID().uuidString).insert(on: self.db)
        try await TestModel(value: "foo", uniqueValue: UUID().uuidString).insert(on: self.db)
        
        let updatedIds = try await TestModel.update(on: self.db) { $0
            .set("value", to: "bar")
            .where("value", .equal, "foo")
        }
        
        XCTAssertEqual(updatedIds.count, 2)
        XCTAssertEqual(updatedIds, [1, 3])

        let updatedModels = try await TestModel.all(on: self.db) { $0
            .where("value", .equal, "bar")
        }
        
        XCTAssertEqual(updatedModels.count, 2)
        XCTAssertEqual(updatedModels.map { $0.id }, [1, 3])
    }
    
    func testDeleteModel() async throws {
        let model = TestModel(value: "test", uniqueValue: UUID().uuidString)
        try await model.insert(on: self.db)
        
        XCTAssertNoThrow(try model.requireId())
        XCTAssertEqual(try model.requireId(), 1)
        XCTAssertEqual(model.id, try model.requireId())
        
        var dbModel = try await TestModel.first(on: self.db)
        
        XCTAssertNotNil(dbModel)
        
        try await dbModel?.delete(on: self.db)
        
        dbModel = try await TestModel.first(on: self.db)
        
        XCTAssertNil(dbModel)
    }
    
    func testDeleteModelWhereClause() async throws {
        try await TestModel(value: "foo", uniqueValue: UUID().uuidString).insert(on: self.db)
        try await TestModel(value: "test", uniqueValue: UUID().uuidString).insert(on: self.db)

        var models = try await TestModel.all(on: self.db)
        
        XCTAssertEqual(models.count, 2)
        
        let deletedIds = try await TestModel.delete(on: self.db) { $0
            .where("value", .equal, "foo")
        }
        
        XCTAssertEqual(deletedIds.count, 1)
        XCTAssertEqual(deletedIds, [1])
        
        models = try await TestModel.all(on: self.db)
        
        XCTAssertEqual(models.count, 1)
    }
}
