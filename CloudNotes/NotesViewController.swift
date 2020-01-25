//
//  ViewController.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 1/13/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class NotesViewController: NSViewController {

    @IBOutlet var addBarButton: NSButton!
    @IBOutlet var refreshBarButton: NSButton!
    @IBOutlet var refreshProgressIndicator: NSProgressIndicator!
    @IBOutlet var notesOutlineView: NSOutlineView!
    @IBOutlet var notesTreeController: NSTreeController!
    
    @objc dynamic let managedContext: NSManagedObjectContext = NotesData.mainThreadContext
    @objc dynamic let sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
    @objc dynamic let feedSortDescriptors = [NSSortDescriptor(key: "sortId", ascending: true)]
    @objc dynamic var itemsFilterPredicate: NSPredicate? = nil
    @objc dynamic var nodeArray = [NoteTreeNode]()

    private var isSyncing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        rebuildCategoriesAndNotesList()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func onRefresh(sender: Any?) {
        guard NotesManager.isOnline else {
            return
        }

        refreshProgressIndicator.startAnimation(nil)
        refreshBarButton.isEnabled = false
        addBarButton.isEnabled = false
        isSyncing = true
        NotesManager.shared.sync { [weak self] in
            self?.isSyncing = false
            self?.addBarButton.isEnabled = true
            self?.refreshBarButton.isEnabled = NotesManager.isOnline
            self?.refreshProgressIndicator.stopAnimation(nil)
//          self?.tableView.reloadData()
        }

    }
    
    @IBAction func onAdd(sender: Any?) {
//        HUD.show(.progress)
//        NotesManager.shared.add(content: "", category: "", completion: { [weak self] note in
//            if note != nil {
//                let indexPath = IndexPath(row: 0, section: 0)
//                if self?.notesFrc.validate(indexPath: indexPath) ?? false,
//                    let collapsedInfo = self?.sectionCollapsedInfo.first(where: { $0.title == Constants.noCategory }),
//                    !collapsedInfo.collapsed {
//                    self?.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
//                }
//                self?.performSegue(withIdentifier: detailSegueIdentifier, sender: self)
//            }
//            HUD.hide()
//        })

    }
    
    func rebuildCategoriesAndNotesList() {
        self.nodeArray.removeAll()
        self.nodeArray.append(AllNotesNode())
        self.nodeArray.append(StarredNotesNode())
        if let categories = CDNote.categories() {
            for category in categories {
                self.nodeArray.append(CategoryNode(category: category))
            }
        }
    }

}

extension NotesViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let treeNode = item as? NSTreeNode, let noteNode = treeNode.representedObject as? NoteTreeNode else {
            return nil
        }
        
        if noteNode.isLeaf {
            if let noteView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NoteCell"), owner: self) as? NoteCellView {
                return noteView
            }
        } else {
            if let categoryView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CategoryCell"), owner: self) as? CategoryCellView {
                return categoryView
            }
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard let treeNode = item as? NSTreeNode, let noteNode = treeNode.representedObject as? NoteTreeNode else {
            return 0.0
        }
        
        if noteNode.isLeaf {
            return 96.0
        } else {
            return 17.0
        }
        return 0.0
    }
    
}
