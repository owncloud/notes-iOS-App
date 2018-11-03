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
            if self.online == true {
        
                let params = ["exclude": ""]
                OCAPIClient.shared().requestSerializer = OCAPIClient.jsonRequestSerializer()
                OCAPIClient.shared().get("notes", parameters: params, progress: nil, success: { (task, responseObject) in
                    if let responseArray = responseObject as? [[String: Any]] {
                        for noteDict in responseArray {
                            if let donwloadedId = noteDict[NoteKeys.serverId] as? Int64 {
                                
                            }
                        }


                    }
                    //                        [serverNotesDictArray enumerateObjectsUsingBlock:^(NSDictionary *noteDict, NSUInteger idx, BOOL *stop) {
                    //                            OCNote *ocNote = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [noteDict objectForKey:@"id"]]];
                    //                            //OCNote *ocNote = [OCNote instanceWithPrimaryKey:[noteDict objectForKey:@"id"] createIfNonexistent:YES];
                    //                            if (!ocNote) { //don't re-add a deleted note (it will be deleted from the server below).
                    //                                ocNote = [OCNote new];
                    //                                [ocNote save:^{
                    //                                    ocNote.id = [[noteDict objectForKey:@"id"] intValue];
                    //                                    ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                    //                                    ocNote.title = [noteDict objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
                    //                                    ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                    //                                }];
                    //                            } else {
                    //                                if ([ocNote existsInDatabase]) {
                    //                                    [ocNote save:^{
                    //                                        if (ocNote.modified > [[noteDict objectForKey:@"modified"] doubleValue]) {
                    //                                            ocNote.updateNeeded = YES;
                    //                                        } else {
                    //                                            ocNote.modified = [[noteDict objectForKey:@"modified"] doubleValue];
                    //                                            ocNote.title = [noteDict objectForKeyNotNull:@"title" fallback:NSLocalizedString(@"New note", @"The title of a new note")];
                    //                                            ocNote.content = [noteDict objectForKeyNotNull:@"content" fallback:@""];
                    //                                        }
                    //                                    }];
                    //                                }
                    //                            }
                    //                        }];
                    //
                    //                        NSArray *serverIds = [serverNotesDictArray valueForKey:@"id"];
                    //
                    //                        NSArray *knownIds = [[OCNote resultDictionariesFromQuery:@"SELECT * FROM $T WHERE id > 0"] valueForKey:@"id"];
                    //
                    //        //                NSLog(@"Count: %lu", (unsigned long)knownIds.count);
                    //
                    //                        NSMutableArray *deletedOnServer = [NSMutableArray arrayWithArray:knownIds];
                    //                        [deletedOnServer removeObjectsInArray:serverIds];
                    //                        //TODO: Fix [deletedOnServer removeObjectsInArray:notesToAdd];
                    //        //                NSLog(@"Deleted on server: %@", deletedOnServer);
                    //                        while (deletedOnServer.count > 0) {
                    //                            OCNote *ocNote = [OCNote firstInstanceWhere:[NSString stringWithFormat:@"id=%@", [deletedOnServer lastObject]]];
                    //                            OCNoteOperationDeleteSimple *operation = [[OCNoteOperationDeleteSimple alloc] initWithNote:ocNote delegate:self];
                    //                            [self addOperationToQueue:operation];
                    //                            [deletedOnServer removeLastObject];
                    //                        }
                    self.deleteNotesFromServer()
                    self.addNotesToServer()
                    self.updateNotesOnServer()
                    NotificationCenter.default.post(name: NetworkSuccess, object: self, userInfo: nil)
                }) { (task, error) in
                    let userInfo = [MessageKeys.title: NSLocalizedString("Error Updating Notes", comment: "The title of an error message"),
                                    MessageKeys.message: error.localizedDescription]
                    NotificationCenter.default.post(name: NetworkFailure, object: self, userInfo: userInfo)
                }
            } else {
                let userInfo = [MessageKeys.title: NSLocalizedString("Unable to Reach Server", comment: "The title of an error message"),
                                MessageKeys.message: NSLocalizedString("Please check network connection and login.", comment: "A message to check network connection")]
                NotificationCenter.default.post(name: NetworkFailure, object: self, userInfo: userInfo)
            }
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
    
    func fetchOne(withPredicate predicate: NSPredicate? = nil) -> Note? {
        var result: Note? = nil
        self.persistentContainer.viewContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: NoteKeys.modified, ascending: false)
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.sortDescriptors = [sortDescriptor]
            request.predicate = predicate
            do {
                let results = try self.persistentContainer.viewContext.fetch(request)
                if results.count > 0 {
                    result = results.first!
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        return result
    }

    func allNotes(withPredicate predicate: NSPredicate? = nil) -> [Note] {
        var result = [Note]()
        self.persistentContainer.viewContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: NoteKeys.modified, ascending: false)
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.sortDescriptors = [sortDescriptor]
            request.predicate = predicate
            do {
                result = try self.persistentContainer.viewContext.fetch(request)
            } catch {
                print(error.localizedDescription)
            }
        }
        return result
    }

    func addNotesToServer() {
        let predicate = NSPredicate(format: NoteKeys.addNeeded + " = \(NSNumber(value: true))")
        let notesToAdd = self.allNotes(withPredicate: predicate)
        
        for note in notesToAdd {
            if note.content.count > 0 {
                let operation = NoteOperationAdd(note: note, delegate: self)
                self.addOperationToQueue(operation: operation)
            }
        }
    }

    func updateNotesOnServer() {
        let predicate = NSPredicate(format: NoteKeys.updateNeeded + " = \(NSNumber(value: true))")
        let notesToUpdate = self.allNotes(withPredicate: predicate)

        for note in notesToUpdate {
            let operation = NoteOperationUpdate(note: note, delegate: self)
            self.addOperationToQueue(operation: operation)
        }
    }
    
    func deleteNotesFromServer() {
        let predicate = NSPredicate(format: NoteKeys.deleteNeeded + " = \(NSNumber(value: true))")
        let notesToDelete = self.allNotes(withPredicate: predicate)

        for note in notesToDelete {
            let operation = NoteOperationDelete(note: note, delegate: self)
            self.addOperationToQueue(operation: operation)
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
    
    func didFail(operation: NoteOperation) {
        if operation is NoteOperationAdd {
            let userInfo: [String: String] = [MessageKeys.title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                            MessageKeys.message: operation.errorMessage ?? ""]
            NotificationCenter.default.post(name: NetworkFailure, object: self, userInfo: userInfo)
        }
        if operation is NoteOperationUpdate {
            let userInfo: [String: String] = [MessageKeys.title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                            MessageKeys.message: operation.errorMessage ?? ""]
            NotificationCenter.default.post(name: NetworkFailure, object: self, userInfo: userInfo)
            operation.note.modified = Date().timeIntervalSince1970
        }
        if operation is NoteOperationGet {
            let userInfo: [String: String] = [MessageKeys.title: NSLocalizedString("Error Getting Note", comment: "The title of an error message"),
                            MessageKeys.message: operation.errorMessage ?? ""]
            NotificationCenter.default.post(name: NetworkFailure, object: self, userInfo: userInfo)
        }
        if operation is NoteOperationDelete {
            let userInfo: [String: String] = [MessageKeys.title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                            MessageKeys.message: operation.errorMessage ?? ""]
            NotificationCenter.default.post(name: NetworkFailure, object: self, userInfo: userInfo)
        }
    }
        
}
