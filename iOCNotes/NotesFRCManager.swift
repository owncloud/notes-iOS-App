//
//  NotesFRCManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 11/5/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import CoreData
import UIKit

protocol NotesFRCManagerChange {
    func applyChanges(tableView: UITableView)
    func applyChanges(tableView: UITableView, with animation: UITableView.RowAnimation)
    func shiftIndexSections(by: Int)

    var insertedRows: [IndexPath] { get }
    var deletedRows: [IndexPath] { get }
    var updatedRows: [IndexPath] { get }
    var insertedSections: IndexSet { get }
    var deletedSections: IndexSet { get }
}

protocol FRCManagerDelegate: AnyObject {
    func managerDidChangeContent(_ controller: NSObject, change: NotesFRCManagerChange)
}

class FRCSection {
    var items = [NSFetchRequestResult]()

    init(_ items: [NSFetchRequestResult]) {
        self.items = items
    }
}

class FRCChange: NotesFRCManagerChange {
    var insertedSections = IndexSet()
    var deletedSections = IndexSet()

    var insertedRows: [IndexPath] {
        return insertedElements.map{ $0.index }
    }

    var deletedRows: [IndexPath] {
        return deletedElements.map{ $0.index }
    }

    var updatedRows: [IndexPath] {
        return updatedElements.map{ $0.index }
    }

    var insertedElements = [(index: IndexPath, element: NSFetchRequestResult)]()
    var deletedElements = [(index: IndexPath, element: NSFetchRequestResult)]()
    var updatedElements = [(index: IndexPath, element: NSFetchRequestResult)]()

    func applyChanges(tableView: UITableView) {
        applyChanges(tableView: tableView, with: .none)
    }

    func applyChanges(tableView: UITableView, with animation: UITableView.RowAnimation) {
        tableView.beginUpdates()
        tableView.deleteRows(at: deletedRows, with: animation)
        tableView.deleteSections(deletedSections, with: animation)
        tableView.insertSections(insertedSections, with: animation)
        tableView.insertRows(at: insertedRows, with: animation)
        tableView.endUpdates()

        tableView.reloadRows(at: updatedRows, with: animation)
    }

    //        override var description: String {
    //            return "insertedSections:\(insertedSections.toArray()), deletedSections:\(deletedSections.toArray()), insertedRows:\(insertedRows), deletedRows:\(deletedRows), updatedRows:\(updatedRows)"
    //        }

    func shiftIndexSections(by: Int) {
        insertedSections = IndexSet(insertedSections.map { $0 + by })
        deletedSections = IndexSet(deletedSections.map { $0 + by })
        insertedElements = insertedElements.map { (IndexPath(row: $0.row, section: ($0.section + by)), $1 ) }
        deletedElements = deletedElements.map { (IndexPath(row: $0.row, section: ($0.section + by)), $1 ) }
        updatedElements = updatedElements.map { (IndexPath(row: $0.row, section: ($0.section + by)), $1 ) }
    }
}

class FRCManager<ResultType>: NSObject, NSFetchedResultsControllerDelegate where ResultType: NSFetchRequestResult {

    var fetchedResultsController: NSFetchedResultsController<ResultType>
    private var currentFRCChange: FRCChange?
    weak var delegate: FRCManagerDelegate?

    var sections = [FRCSection]()

    var fetchedObjectsCount: Int {
        return self.sections.reduce(0, {$0 + $1.items.count})
    }
    
    var first: NSFetchRequestResult? {
        return self.sections.first?.items.first
    }

    var fetchedObjects: [NSFetchRequestResult] {
        return sections.flatMap { $0.items }
    }

    func sectionCount() -> Int {
        return sections.count
    }

    // TODO: Remove after all uses removed. You should never need to look up an indexPath for an object.
    func indexPath(forObject: ResultType) -> IndexPath? {
        for (section, sectionInfo) in sections.enumerated() {
            for (row, object) in sectionInfo.items.enumerated() {
                if forObject.isEqual(object) {
                    return IndexPath(row: row, section: section)
                }
            }
        }
        return nil
    }

    func itemCount(in section: Int) -> Int {
        return self.sections[section].items.count
    }

    func object(at indexPath: IndexPath) -> NSFetchRequestResult {
        return self.sections[indexPath.section].items[indexPath.row]
    }

    public init(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext context: NSManagedObjectContext, sectionNameKeyPath: String?, delegate: FRCManagerDelegate?) {
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)

        super.init()
        fetchedResultsController.delegate = self
        self.delegate = delegate
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch in fetchedResultsControllerManager from core data:\(error)")
        }
        self.sections = self.fetchedResultsController.sections?.compactMap({ $0.objects as? [NSFetchRequestResult]}).compactMap { FRCSection($0) } ?? []
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.currentFRCChange = FRCChange()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.currentFRCChange?.insertedSections.insert(sectionIndex)
        case .delete:
            self.currentFRCChange?.deletedSections.insert(sectionIndex)
        default:
            //shouldn't happen
            print("FetchedResultsControllerManager didChange atSectionIndex:\(sectionIndex) unknown type:\(type.rawValue)")
            return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let anObject = anObject as? ResultType {
            switch type {
            case .insert:
                if let i = newIndexPath {
                    self.currentFRCChange?.insertedElements.append((i, anObject))
                }
            case .delete:
                if let i = indexPath {
                    self.currentFRCChange?.deletedElements.append((i, anObject))
                }
            case .update:
                if let i = indexPath {
                    self.currentFRCChange?.updatedElements.append((i, anObject))
                }
            case .move:
                if let i = indexPath {
                    self.currentFRCChange?.deletedElements.append((i, anObject))
                }
                if let i = newIndexPath {
                    self.currentFRCChange?.insertedElements.append((i, anObject))
                }
            @unknown default:
                fatalError()
            }
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let change = self.currentFRCChange else {
            return
        }
        change.insertedElements.sort { $0.index < $1.index }
        change.deletedElements.sort { $0.index > $1.index }

        change.updatedElements.forEach { (index, element) in
            sections[index.section].items[index.row] = element
        }

        let updateOnlyChange = FRCChange()
        updateOnlyChange.updatedElements = change.updatedElements
        if !updateOnlyChange.updatedElements.isEmpty {
            self.delegate?.managerDidChangeContent(self, change:updateOnlyChange)
        }

        change.deletedElements.forEach { (indexPath, _) in
            sections[indexPath.section].items.remove(at: indexPath.row)
        }
        change.deletedSections.reversed().forEach { index in
            sections.remove(at: index)
        }
        change.insertedSections.forEach { (index) in
            sections.insert(FRCSection([]), at: index)
        }
        change.insertedElements.forEach { (index, element) in
            sections[index.section].items.insert(element, at: index.row)
        }
        change.updatedElements = []
        if !change.deletedRows.isEmpty || !change.deletedSections.isEmpty || !change.insertedSections.isEmpty || !change.insertedElements.isEmpty {
            self.delegate?.managerDidChangeContent(self, change: change)
        }

        self.currentFRCChange = nil
    }
}
