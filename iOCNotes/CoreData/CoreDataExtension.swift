//
//  CoreDataExtension.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation
import CoreData

extension NSFetchRequestResult where Self: NSManagedObject {

    @discardableResult
    public static func delete(ids: [Int64], in context: NSManagedObjectContext) -> NSBatchDeleteResult? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
        let predicate = NSPredicate(format: "cdId IN %@", ids)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        do {
            let result = try context.execute(deleteRequest)
            try context.save()
            return result as? NSBatchDeleteResult
        } catch let error as NSError {
            print("Could not perform deletion \(error), \(error.userInfo)")
            return nil
        }
    }

    @discardableResult
    public static func deleteItemIds(itemIds: [Int32], in context: NSManagedObjectContext) -> NSBatchDeleteResult? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
        let predicate = NSPredicate(format: "cdId IN %@", itemIds)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        do {
            let result = try context.execute(deleteRequest)
            try context.save()
            return result as? NSBatchDeleteResult
        } catch let error as NSError {
            print("Could not perform deletion \(error), \(error.userInfo)")
            return nil
        }
    }

}
