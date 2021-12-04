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
    func applyChanges(tableView: UITableView, animation: UITableView.RowAnimation?)

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

enum FrcDelegateUpdate {
    case disable
    case enable(withFetch: Bool)
}

struct IndexNote {
    var index: IndexPath
    var note: CDNote
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

    var insertedElements = [IndexNote]()
    var deletedElements = [IndexNote]()
    var updatedElements = [IndexNote]()

    func applyChanges(tableView: UITableView, animation: UITableView.RowAnimation?) {
        tableView.beginUpdates()
        tableView.deleteRows(at: deletedRows, with: animation ?? .fade)
        tableView.deleteSections(deletedSections, with: animation ?? .fade)
        tableView.insertSections(insertedSections, with: animation ?? .fade)
        tableView.insertRows(at: insertedRows, with: animation ?? .fade)
        tableView.endUpdates()

        tableView.reloadRows(at: updatedRows, with: animation ?? .fade)
    }

}

class FRCManager<ResultType>: NSObject, NSFetchedResultsControllerDelegate where ResultType: NSFetchRequestResult {

    weak var delegate: FRCManagerDelegate?

    var fetchedResultsController: NSFetchedResultsController<ResultType>
    var isSyncing = false
    var currentSectionObjectCount = 0
    var sections = [FRCSection]()
    var disclosureSections: DisclosureSections {
        get {
            return KeychainHelper.sectionExpandedInfo
        }
        set {
            KeychainHelper.sectionExpandedInfo = newValue
        }
    }

    var fetchedObjectsCount: Int {
        return sections.reduce(0, {$0 + $1.items.count})
    }
    
    var first: NSFetchRequestResult? {
        return sections.first?.items.first
    }

    var fetchedObjects: [NSFetchRequestResult] {
        return sections.flatMap { $0.items }
    }

    private var currentFRCChange: FRCChange?

    func sectionCount() -> Int {
        return sections.count
    }

    func itemCount(in section: Int) -> Int {
        return sections[section].items.count
    }

    func object(at indexPath: IndexPath) -> NSFetchRequestResult {
        return sections[indexPath.section].items[indexPath.row]
    }

    public init(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext context: NSManagedObjectContext, sectionNameKeyPath: String?, delegate: FRCManagerDelegate?) {
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)

        super.init()
        fetchedResultsController.delegate = self
        self.delegate = delegate
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch in fetchedResultsControllerManager from core data:\(error)")
        }
        sections = fetchedResultsController.sections?.compactMap({ $0.objects as? [NSFetchRequestResult]}).compactMap { FRCSection($0) } ?? []
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        currentFRCChange = FRCChange()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            currentFRCChange?.insertedSections.insert(sectionIndex)
            var tempDisclosureSections = disclosureSections
            tempDisclosureSections.append(DisclosureSection(title: sectionInfo.name, collapsed: false))
            disclosureSections = tempDisclosureSections

        case .delete:
            currentFRCChange?.deletedSections.insert(sectionIndex)
            let tempDisclosureSections = disclosureSections
            disclosureSections = tempDisclosureSections.filter({ $0.title != sectionInfo.name })

        default:
            //shouldn't happen
            print("FetchedResultsControllerManager didChange atSectionIndex:\(sectionIndex) unknown type:\(type.rawValue)")
            return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let note = anObject as? CDNote {
            let sectionName = note.category == "" ? Constants.noCategory : note.category

            switch type {
            case .insert:
                if let i = newIndexPath {
                    if let collapsedInfo = disclosureSections.first(where: { $0.title == sectionName }) {
                        if !collapsedInfo.collapsed {
                            currentFRCChange?.insertedElements.append(IndexNote(index: i, note: note))
                        }
                    }
                }
                
            case .delete:
                if let i = indexPath {
                    if let collapsedInfo = disclosureSections.first(where: { $0.title == sectionName }) {
                        if !collapsedInfo.collapsed {
                            if isSyncing {
                                currentFRCChange?.deletedElements.append(IndexNote(index: i, note: note))
                            } else if currentSectionObjectCount > 1 {
                                print("Deleting row")
                                currentFRCChange?.deletedElements.append(IndexNote(index: i, note: note))
                            }
                        }
                    }
                }

            case .update:
                if let i = newIndexPath {
                    currentFRCChange?.updatedElements.append(IndexNote(index: i, note: note))
                }

            case .move:
                if let i = indexPath, let sectionCount = controller.sections?.count {
                    if i.section < sectionCount, let oldSection = controller.sections?[i.section] {
                        let oldSectionName = oldSection.name
                        if let collapsedInfo = disclosureSections.first(where: { $0.title == oldSectionName }) {
                            if !collapsedInfo.collapsed {
                                currentFRCChange?.deletedElements.append(IndexNote(index: i, note: note))
                            }
                        }
                    }
                }
                if let i = newIndexPath {
                    if let collapsedInfo = disclosureSections.first(where: { $0.title == sectionName }) {
                        if !collapsedInfo.collapsed {
                            currentFRCChange?.insertedElements.append(IndexNote(index: i, note: note))
                        }
                    }
                }

            @unknown default:
                fatalError()
            }
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let change = currentFRCChange else {
            return
        }
        change.insertedElements.sort { $0.index < $1.index }
        change.deletedElements.sort { $0.index > $1.index }

        change.updatedElements.forEach { indexNote in
            sections[indexNote.index.section].items[indexNote.index.row] = indexNote.note
        }

        change.deletedElements.forEach { indexNote in
            sections[indexNote.index.section].items.remove(at: indexNote.index.row)
        }
        change.deletedSections.reversed().forEach { index in
            sections.remove(at: index)
        }
        change.insertedSections.forEach { index in
            sections.insert(FRCSection([NSFetchRequestResult]()), at: index)
        }
        change.insertedElements.forEach { indexNote in
            sections[indexNote.index.section].items.insert(indexNote.note, at: indexNote.index.row)
        }

        if !change.updatedRows.isEmpty || !change.deletedRows.isEmpty || !change.deletedSections.isEmpty || !change.insertedSections.isEmpty || !change.insertedElements.isEmpty {
            delegate?.managerDidChangeContent(self, change: change)
        }

        currentFRCChange = nil
    }
}

extension NSFetchedResultsController {

    @objc func validate(indexPath: IndexPath) -> Bool {
        if let sections = sections {
            if indexPath.section >= sections.count {
                return false
            }

            if indexPath.row >= sections[indexPath.section].numberOfObjects {
                return false
            }
        }
        return true
    }

}
