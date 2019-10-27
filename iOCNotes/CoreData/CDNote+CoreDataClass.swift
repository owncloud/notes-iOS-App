//
//  Note+CoreDataClass.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/7/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//
//

import Foundation
import CoreData

@objc(CDNote)
public class CDNote: NSManagedObject {

    static private let entityName = "CDNote"

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = -1
        self.guid = UUID().uuidString
        self.content = ""
        self.category = ""
        self.addNeeded = true
        self.updateNeeded = false
        self.deleteNeeded = false
    }

    @objc var sectionName: String {
        if self.cdCategory.isEmpty {
            return Constants.noCategory
        } else {
            return self.cdCategory
        }
    }

    static func all() -> [CDNote]? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        var noteList = [CDNote]()
        do {
            let results  = try NotesData.mainThreadContext.fetch(request)
            for record in results {
                noteList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return noteList
    }


    static func notes(property: String) -> [CDNote]? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", property, NSNumber(value: true))
        do {
            return try NotesData.mainThreadContext.fetch(request)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func note(id: Int32) -> CDNote? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        let predicate = NSPredicate(format: "cdId == %d", id)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NotesData.mainThreadContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }
    
    static func note(guid: String) -> CDNote? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        let predicate = NSPredicate(format: "cdGuid == %@", guid)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NotesData.mainThreadContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func update(notes: [NoteProtocol]) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            do {
                for note in notes {
                    let predicate: NSPredicate
                    if note.id >= 0 {
                        predicate = NSPredicate(format: "cdId == %d", note.id)
                    } else {
                        predicate = NSPredicate(format: "cdGuid == %@", note.guid ?? "")
                    }
                    request.predicate = predicate
                    let records = try NotesData.mainThreadContext.fetch(request)
                    if let existingRecord = records.first {
                        existingRecord.guid = note.guid
                        existingRecord.category = note.category
                        existingRecord.content = note.content
                        existingRecord.title = note.title
                        existingRecord.favorite = note.favorite
                        existingRecord.modified = note.modified
                    } else {
                        let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDNote.entityName, into: NotesData.mainThreadContext) as! CDNote
                        newRecord.guid = note.guid
                        newRecord.category = note.category
                        newRecord.content = note.content
                        if note.id > 0 {
                            newRecord.id = note.id
                            newRecord.addNeeded = false
                        }
                        newRecord.title = note.title
                        newRecord.favorite = note.favorite
                        newRecord.modified = note.modified
                    }
                }
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
    }

    static func update(note: NoteProtocol) -> CDNote? {
        var result: CDNote?
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            do {
                let predicate: NSPredicate
                if note.id >= 0 {
                    predicate = NSPredicate(format: "cdId == %d", note.id)
                } else {
                    predicate = NSPredicate(format: "cdGuid == %@", note.guid ?? "")
                }
                request.predicate = predicate
                let records = try NotesData.mainThreadContext.fetch(request)
                if let existingRecord = records.first {
                    existingRecord.guid = note.guid
                    existingRecord.category = note.category
                    existingRecord.content = note.content
                    existingRecord.title = note.title
                    existingRecord.favorite = note.favorite
                    existingRecord.modified = note.modified
                    result = existingRecord
                } else {
                    let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDNote.entityName, into: NotesData.mainThreadContext) as! CDNote
                    newRecord.guid = note.guid
                    newRecord.category = note.category
                    newRecord.content = note.content
                    newRecord.id = note.id
                    newRecord.title = note.title
                    newRecord.favorite = note.favorite
                    newRecord.modified = note.modified
                    result = newRecord
                }
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
        return result
    }

    static func delete(note: NoteProtocol) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            do {
                request.predicate = NSPredicate(format: "cdId == %d", note.id)
                let records = try NotesData.mainThreadContext.fetch(request)
                if let existingRecord = records.first {
                    NotesData.mainThreadContext.delete(existingRecord)
                    try NotesData.mainThreadContext.save()
                }
            } catch let error as NSError {
                print("Could not perform deletion \(error), \(error.userInfo)")
                return
            }
        }
    }

    static func delete(ids: [Int64]) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            let predicate = NSPredicate(format: "cdId IN %@", ids)
            request.predicate = predicate
            do {
                let result = try NotesData.mainThreadContext.fetch(request)
                for note in result {
                    NotesData.mainThreadContext.delete(note)
                }
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not perform deletion \(error), \(error.userInfo)")
                return
            }
        }
    }

    static func reset() {
        NotesData.mainThreadContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
            deleteRequest.resultType = .resultTypeCount
            do {
                let deleteResult = try NotesData.mainThreadContext.execute(deleteRequest) as! NSBatchDeleteResult
                print("The batch delete request has deleted \(deleteResult.result ?? 0) records.")
                NotesData.mainThreadContext.reset()
            } catch {
                let updateError = error as NSError
                print("\(updateError), \(updateError.userInfo)")
            }
        }
    }

}
