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

    @NSManaged public var category: String?
    @NSManaged public var content: String?
    @NSManaged public var favorite: Bool
    @NSManaged public var guid: String?
    @NSManaged public var modified: NSDate?
    @NSManaged public var id: Int64
    @NSManaged public var title: String?
    @NSManaged public var errorMessage: String?
    @NSManaged public var error: Bool
    @NSManaged public var etag: String?

}
