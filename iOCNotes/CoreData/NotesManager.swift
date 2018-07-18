//
//  NotesManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import CoreData

class NotesManager: NSObject {

    static let shared = NotesManager()

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

    func sync() {
        //
    }
    
    func add(content: String) {
        self.enqueueCoreDataBlock { (context) in
            let newNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context) as? Note
            newNote?.content = content
        }
    }
    
    func get(note: Note) {
        if self.online == true {
            if note.serverId > 0 {
                let operation = NoteOperationGet(note: note, delegate: self)
                self.addOperationToQueue(operation: operation)
            } else {
                let operation = NoteOperationAdd(note: note, delegate: self)
                self.addOperationToQueue(operation: operation)
            }
        } else {
            //offline
        }
    }
    
    func update(note: Note) {
        if note.addNeeded == false {
                note.updateNeeded = true
        }
        if self.online == true {
            //online
            if note.serverId > 0 {
                let operation = NoteOperationUpdate(note: note, delegate: self)
                self.addOperationToQueue(operation: operation)
            } else {
                let operation = NoteOperationAdd(note: note, delegate: self)
                self.addOperationToQueue(operation: operation)
            }
        } else {
            //offline
            self.enqueueCoreDataBlock { (context) in
                if note.addNeeded == false {
                    note.updateNeeded = true
                }
                note.modified = Date().timeIntervalSince1970
            }
        }
    }
    
    func delete(note: Note) {
        note.deleteNeeded = true
        note.addNeeded = false
        note.updateNeeded = false
        
        if note.serverId > 0 {
            if (online) {
                let operation = NoteOperationDelete(note: note, delegate: self)
                self.addOperationToQueue(operation: operation)
            }
        }
    }
    
    func addOperationToQueue(operation: NoteOperation) {
        for op in self.noteOperationsQueue.operations {
            if let scheduledOp = op as? NoteOperation {
                if scheduledOp.note.guid == operation.note.guid {
                    if scheduledOp.isExecuting {
                        if scheduledOp is NoteOperationAdd && operation is NoteOperationAdd {
                            let updateOperation = NoteOperationUpdate(note: operation.note, delegate: self)
                            updateOperation.addDependency(scheduledOp)
                            self.noteOperationsQueue.addOperation(updateOperation)
                            operation.cancel()
                        } else {
                            operation.addDependency(scheduledOp)
                        }
                    } else {
                        scheduledOp.cancel()
                    }
                }
            }
        }
        self.noteOperationsQueue.addOperation(operation)
    }

}

extension NotesManager: NoteOperationDelegate {
    
    func didStart(operation: NoteOperation) {
        //
    }
    
    func didFinish(operation: NoteOperation) {
        //
    }
    
    func didFail(operation: NoteOperation) {
        //
    }
        
}
