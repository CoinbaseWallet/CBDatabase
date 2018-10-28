// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import CoreData
import RxSwift

extension NSManagedObjectContext {
    private var isBackgroundContext: Bool {
        return concurrencyType == .privateQueueConcurrencyType
    }

    func fetch(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = []
    ) throws -> [NSManagedObject] {
        let request = buildFetchRequest(entityName: entityName, predicate: predicate, sortDescriptors: sortDescriptors)
        return try fetch(request)
    }

    func count(
        entityName: String,
        predicate: NSPredicate? = nil
    ) throws -> Int {
        let request = buildFetchRequest(entityName: entityName, predicate: predicate)
        return try count(for: request)
    }

    func fetch<T: DatabaseModelObject>(_: T.Type, identifier: String) throws -> NSManagedObject? {
        assert(isBackgroundContext != Thread.isMainThread)

        let items: [NSManagedObject] = try fetch(T.fetchRequest(id: identifier))
        assert(items.count <= 1)

        return items.first
    }

    func delete<T: DatabaseModelObject>(_ type: T.Type, identifier: String) throws -> Bool {
        assert(isBackgroundContext != Thread.isMainThread)

        guard let object = try fetch(type, identifier: identifier) else { return false }
        delete(object)
        return true
    }

    func deleteAll<T: DatabaseModelObject>(_ type: T.Type) throws {
        assert(isBackgroundContext != Thread.isMainThread)

        try fetch(type.fetchRequest()).forEach { self.delete($0) }
    }

    func saveChangesIfNeeded() {
        assert(isBackgroundContext != Thread.isMainThread)
        guard hasChanges else { return }

        do {
            try save()
        } catch {
            print("Error saving managed object context: \(error)")
        }
    }

    // MARK: - Private

    private func buildFetchRequest(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = []
    ) -> NSFetchRequest<NSManagedObject> {
        assert(isBackgroundContext != Thread.isMainThread)

        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: entityName)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors

        return fetchRequest
    }
}
