import CoreData
import Foundation
import Testing
@testable import ntfy

/// Existing users have stores written with older model versions. If one fails to load, Store only logs it and the
/// app runs with no data, so every shipped version must migrate to the current one.
struct ModelMigrationTests {
    private static let firstVersion = "Model"

    private func loadModel(_ url: URL) throws -> NSManagedObjectModel {
        let model = try #require(NSManagedObjectModel(contentsOf: url))
        // Generic objects only: a second model claiming Subscription etc. would confuse Store's entity lookups.
        for entity in model.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        return model
    }

    private func modelDirectory() throws -> URL {
        try #require(Bundle(for: Store.self).url(forResource: Store.modelName, withExtension: "momd"))
    }

    private func openStore(at url: URL, model: NSManagedObjectModel) throws -> NSPersistentContainer {
        let description = NSPersistentStoreDescription(url: url)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        let container = NSPersistentContainer(name: Store.modelName, managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            throw loadError
        }
        return container
    }

    @Test func firstVersionHasNoDisplayName() throws {
        let first = try loadModel(modelDirectory().appendingPathComponent("\(Self.firstVersion).mom"))
        #expect(first.entitiesByName["Subscription"]?.attributesByName["customDisplayName"] == nil)
    }

    @Test func currentVersionHasDisplayName() throws {
        let current = try loadModel(modelDirectory())
        #expect(current.entitiesByName["Subscription"]?.attributesByName["customDisplayName"] != nil)
    }

    @Test func storeFromFirstVersionMigratesToCurrent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeUrl = directory.appendingPathComponent("ntfy.sqlite")

        let old = try openStore(at: storeUrl, model: loadModel(modelDirectory().appendingPathComponent("\(Self.firstVersion).mom")))
        let subscription = NSEntityDescription.insertNewObject(forEntityName: "Subscription", into: old.viewContext)
        subscription.setValue("https://ntfy.sh", forKey: "baseUrl")
        subscription.setValue("garage", forKey: "topic")
        try old.viewContext.save()
        for store in old.persistentStoreCoordinator.persistentStores {
            try old.persistentStoreCoordinator.remove(store)
        }

        let migrated = try openStore(at: storeUrl, model: loadModel(modelDirectory()))
        let rows = try migrated.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "Subscription"))
        #expect(rows.count == 1)
        #expect(rows.first?.value(forKey: "topic") as? String == "garage")
        #expect(rows.first?.value(forKey: "customDisplayName") == nil)
    }
}
