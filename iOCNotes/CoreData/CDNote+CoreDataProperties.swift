//
//  Note+CoreDataProperties.swift
//  
//
//  Created by Peter Hedlund on 1/23/19.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension CDNote {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDNote> {
        return NSFetchRequest<CDNote>(entityName: "CDNote")
    }

    @NSManaged public var cdCategory: String
    @NSManaged public var cdContent: String
    @NSManaged public var cdFavorite: Bool
    @NSManaged public var cdGuid: String?
    @NSManaged public var cdModified: Double
    @NSManaged public var cdId: Int64
    @NSManaged public var cdTitle: String?
    @NSManaged public var cdErrorMessage: String?
    @NSManaged public var cdError: Bool
    @NSManaged public var cdEtag: String?
    @NSManaged public var cdAddNeeded: Bool
    @NSManaged public var cdDeleteNeeded: Bool
    @NSManaged public var cdUpdateNeeded: Bool
}

extension CDNote: NoteProtocol {
    var category: String {
        get {
            return self.cdCategory
        }
        set {
            self.cdCategory = newValue
        }
    }

    var content: String {
        get {
            return self.cdContent
        }
        set {
            self.cdContent = newValue
        }
    }

    var favorite: Bool {
        get {
            return self.cdFavorite
        }
        set {
            self.cdFavorite = newValue
        }
    }

    var guid: String? {
        get {
            return self.cdGuid
        }
        set {
            self.cdGuid = newValue
        }
    }

    var modified: TimeInterval {
        get {
            return self.cdModified
        }
        set {
            self.cdModified = newValue
        }
    }

    var id: Int64 {
        get {
            return self.cdId
        }
        set {
            self.cdId = newValue
        }
    }

    var title: String {
        get {
            return self.cdTitle ?? Constants.newNote
        }
        set {
            self.cdTitle = newValue
        }
    }

    var errorMessage: String? {
        get {
            return self.cdErrorMessage
        }
        set {
            self.cdErrorMessage = newValue
        }
    }

    var error: Bool {
        get {
            return self.cdError
        }
        set {
            self.cdError = newValue
        }
    }

    var etag: String {
        get {
            return self.cdEtag ?? ""
        }
        set {
            self.cdEtag = newValue
        }
    }

    var addNeeded: Bool {
        get {
            return self.cdAddNeeded
        }
        set {
            self.cdAddNeeded = newValue
        }
    }

    var deleteNeeded: Bool {
        get {
            return self.cdDeleteNeeded
        }
        set {
            self.cdDeleteNeeded = newValue
        }
    }

    var updateNeeded: Bool {
        get {
            return self.cdUpdateNeeded
        }
        set {
            self.cdUpdateNeeded = newValue
        }
    }

}
