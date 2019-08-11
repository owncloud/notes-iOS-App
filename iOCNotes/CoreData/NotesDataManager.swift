//
//  NotesDataManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import CoreData

class NotesDataManager: NSObject {

    static let shared = NotesDataManager()

    var documentsFolderURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    var objectContext: NSManagedObjectContext
    
    private var persistentContainer: NSPersistentContainer
    private var online = false
    
    let noteOperationsQueue: OperationQueue = {
        let queue = OperationQueue();
        queue.maxConcurrentOperationCount = 1;
        return queue;
    }()

    let persistentContainerQueue: OperationQueue = {
        let queue = OperationQueue();
        queue.maxConcurrentOperationCount = 1;
        return queue;
    }()
    
    override init() {
        persistentContainer = NSPersistentContainer(name: "Notes")
        persistentContainer.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        objectContext = persistentContainer.viewContext
        super.init()
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        
        self.online = OCAPIClient.shared().reachabilityManager.isReachable
        NotificationCenter.default.addObserver(forName: Notification.Name.AFNetworkingReachabilityDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            if let status = notification.userInfo?[AFNetworkingReachabilityNotificationStatusItem] as? AFNetworkReachabilityStatus {
                if status == AFNetworkReachabilityStatus.notReachable {
                    self.online = false
                }
                if status == AFNetworkReachabilityStatus.reachableViaWiFi || status == AFNetworkReachabilityStatus.reachableViaWWAN {
                    self.online = true
                }
            }
        }
    }
    
    func enqueueCoreDataBlock(_ block: @escaping (NSManagedObjectContext) -> Void) {
        self.persistentContainerQueue.addOperation {
            let context = self.persistentContainer.newBackgroundContext()
            context.performAndWait {
                block(context)
                do {
                    try context.save()
                } catch {
                    let nserror = error as NSError
                    fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        }
    }

}
