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
    @IBOutlet var leftTopView: NSView!
    
    @objc dynamic let managedContext: NSManagedObjectContext = NotesData.mainThreadContext
    @objc dynamic let sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
    @objc dynamic let feedSortDescriptors = [NSSortDescriptor(key: "sortId", ascending: true)]
    @objc dynamic var itemsFilterPredicate: NSPredicate? = nil
    @objc dynamic var nodeArray = [NoteTreeNode]()

    var editorViewController: EditorViewController?
    
    private var currentNode: NoteTreeNode?
    private var selectedRow: Int?
    private var selectedColumn: IndexSet?
    private var isSyncing = false
    private var observers = [NSObjectProtocol]()

    override func viewDidLoad() {
        super.viewDidLoad()
        leftTopView.wantsLayer = true
        let border: CALayer = CALayer()
        border.autoresizingMask = .layerWidthSizable;
        border.frame = CGRect(x: 0,
                              y: 1,
                              width: leftTopView.frame.width,
                              height: 1)
        border.backgroundColor = NSColor.gridColor.cgColor
        leftTopView.layer?.addSublayer(border)
        
        rebuildCategoriesAndNotesList()
        notesOutlineView.reloadData()
        
        observers.append(NotificationCenter.default.addObserver(forName: .editorUpdatedNote, object: nil, queue: .main, using: { [weak self] _ in
            DispatchQueue.main.async {
                if let row = self?.selectedRow {
                    let selectedItem = self?.notesOutlineView.item(atRow: row)
                    self?.notesOutlineView.reloadItem(selectedItem)
                }
            }
        }))
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
    
    private func boldTitle(title: String, content: String?) -> NSAttributedString {
        var attributedString: NSMutableAttributedString
        var boldedRange: NSRange
        if let content = content, !content.isEmpty {
            attributedString = NSMutableAttributedString(string: content, attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
            boldedRange = (content as NSString).range(of: title)
            if boldedRange.length == 0 {
                boldedRange = NSRange(location: 0, length: min(title.count, content.count))
            }
        } else {
            attributedString = NSMutableAttributedString(string: title, attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
            boldedRange = (title as NSString).range(of: title)
        }

        let boldFontAttribute = [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
        attributedString.addAttributes(boldFontAttribute, range: boldedRange)
        return NSAttributedString(attributedString: attributedString)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let noteNode = item as? NoteTreeNode else {
            return nil
        }
        
        if noteNode.isLeaf {
            if let noteView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NoteCell"), owner: self) as? NoteCellView {
                let attributedContent = boldTitle(title: noteNode.title, content: noteNode.content)
                noteView.contentLabel.attributedStringValue = attributedContent
                noteView.modifiedLabel.stringValue = noteNode.modified?.stringValue ?? ""
                return noteView
            }
        } else {
            if let categoryView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CategoryCell"), owner: self) as? CategoryCellView {
                categoryView.titleLabel.stringValue = noteNode.title
                return categoryView
            }
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard let noteNode = item as? NoteTreeNode else {
            return 0.0
        }
        
        if noteNode.isLeaf {
            return 96.0
        } else {
            return 17.0
        }
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
//        guard let outlineView = notification.object as? NSOutlineView else {
//            return
//        }

//        let selectedIndex = outlineView.selectedRow
//        self.currentFeedRowIndex = selectedIndex
        selectedColumn = notesOutlineView.selectedColumnIndexes
        selectedRow = notesOutlineView.selectedRow
        
        if let selectedRow = selectedRow, let selectedObject = notesOutlineView.item(atRow: selectedRow) as? NoteTreeNode {
            currentNode = selectedObject
            
            switch currentNode {
            case _ as AllNotesNode:
//                if NSUserDefaultsController.shared.defaults.integer(forKey: "hideRead") == 0 {
//                    self.itemsFilterPredicate = NSPredicate(format: "unread == true")
//                } else {
//                    self.itemsFilterPredicate = nil
//                }
                break
            case _ as StarredNotesNode:
//                print("Starred articles selected")
//                self.itemsFilterPredicate = NSPredicate(format: "starred == true")
                break
            case _ as CategoryNode:
//                print("Folder: \(folderNode.folder.name ?? "") selected")
//                if let feedIds = CDFeed.idsInFolder(folder: folderNode.folder.id) {
//                    if NSUserDefaultsController.shared.defaults.integer(forKey: "hideRead") == 0 {
//                        let unreadPredicate = NSPredicate(format: "unread == true")
//                        let feedPredicate = NSPredicate(format:"feedId IN %@", feedIds)
//                        self.itemsFilterPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [unreadPredicate, feedPredicate])
//                    } else {
//                        self.itemsFilterPredicate = NSPredicate(format:"feedId IN %@", feedIds)
//                    }
//                }
                break
            case let noteNode as NoteNode:
                let selectedNote = noteNode.note
                editorViewController?.note = selectedNote
//                print("Feed: \(feedNode.feed.title ?? "") selected")
//                if NSUserDefaultsController.shared.defaults.integer(forKey: "hideRead") == 0 {
//                    let unreadPredicate = NSPredicate(format: "unread == true")
//                    let feedPredicate = NSPredicate(format: "feedId == %d", feedNode.feed.id)
//                    self.itemsFilterPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [unreadPredicate, feedPredicate])
//                } else {
//                    self.itemsFilterPredicate = NSPredicate(format: "feedId == %d", feedNode.feed.id)
//                }
                break
            default:
                break
            }
        }
//        self.itemsTableView.scrollRowToVisible(0)

    }
}

extension NotesViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return nodeArray[index]
        }
        guard let noteNode = item as? NoteTreeNode else {
            return 0
        }

        if noteNode.isLeaf {
            return 0
        } else {
            return noteNode.children[index]
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return nodeArray.count
        }
        guard let noteNode = item as? NoteTreeNode else {
            return 0
        }

        if noteNode.isLeaf {
            return 0
        } else {
            return noteNode.childCount
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let noteNode = item as? NoteTreeNode else {
            return false
        }

        if noteNode.isLeaf {
            return false
        } else {
            return true
        }
    }

}
