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
    
    static func note(id: Int32) -> CDNote? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %d", id)
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
    
    static func withoutCategory() -> [CDNote]? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        let predicate = NSPredicate(format: "category == ''")
        request.predicate = predicate
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

    static func inCategory(category: String) -> [CDNote]? {
        let request: NSFetchRequest<CDNote> = self.fetchRequest()
        let predicate = NSPredicate(format: "category == %@", category)
        request.predicate = predicate
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

    static func update(notes: [NoteProtocol]) {
        NotesData.mainThreadContext.performAndWait {
            let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
            do {
                for note in notes {
                    let predicate = NSPredicate(format: "id == %d", note.id)
                    request.predicate = predicate
                    let records = try NotesData.mainThreadContext.fetch(request)
                    if let existingRecord = records.first {
//                        existingRecord.id = note.id
                        existingRecord.guid = note.guid
                        existingRecord.category = note.category
                        existingRecord.content = note.content
                        existingRecord.title = note.title
                        existingRecord.favorite = note.favorite
                        existingRecord.modified = Date(timeIntervalSince1970: note.modified) as NSDate
                    } else {
                        let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDNote.entityName, into: NotesData.mainThreadContext) as! CDNote
                        newRecord.guid = note.guid
                        newRecord.category = note.category
                        newRecord.content = note.content
                        newRecord.id = note.id
                        newRecord.title = note.title
                        newRecord.favorite = note.favorite
                        newRecord.modified = Date(timeIntervalSince1970: note.modified) as NSDate
                    }
                }
                try NotesData.mainThreadContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
        }
    }


}
