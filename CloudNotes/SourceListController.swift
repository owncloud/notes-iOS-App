//
//  ViewController.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 1/13/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class SourceListController: NSViewController {

    @IBOutlet var refreshBarButton: NSButton!
    @IBOutlet var refreshProgressIndicator: NSProgressIndicator!
    @IBOutlet var notesOutlineView: NSOutlineView!
    @IBOutlet var leftTopView: NSView!

    var notesViewController: NotesViewController?
    
    private var nodeArray = [NoteTreeNode]()
    private var currentNode: NoteTreeNode?
    private var selectedRow: Int?
    private var selectedColumn: IndexSet?
    private var isSyncing = false
    private var observers = [NSObjectProtocol]()
    private var isInitialLaunch = true

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

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
        
        rebuildCategoryList()
        notesOutlineView.reloadData()
        
        observers.append(NotificationCenter.default.addObserver(forName: .editorUpdatedNote, object: nil, queue: .main, using: { [weak self] _ in
            DispatchQueue.main.async {
                if let row = self?.selectedRow {
                    let selectedItem = self?.notesOutlineView.item(atRow: row)
                    self?.notesOutlineView.reloadItem(selectedItem)
                }
            }
        }))
        observers.append(NotificationCenter.default.addObserver(forName: .categoryUpdated, object: nil, queue: .main, using: { [weak self] notification in
            if let note = notification.object as? CDNote {
                DispatchQueue.main.async {
                    self?.rebuildCategoryList()
                    self?.notesOutlineView.reloadData()
                    let index = self?.nodeArray.firstIndex(where: {
                        if let categoryNode = $0 as? CategoryNode {
                            return categoryNode.category == note.category
                        }
                        return false
                    })
                    self?.notesOutlineView.selectRowIndexes(IndexSet(integer: index ?? 1), byExtendingSelection: false)
                    self?.notesViewController?.notesView.reloadData()
                    self?.notesViewController?.notesView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
            }
        }))
    }

    override func viewWillAppear() {
        if isInitialLaunch {
            notesOutlineView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            outlineViewSelectionDidChange(Notification(name: NSOutlineView.selectionDidChangeNotification))
            isInitialLaunch = false
        }
    }
    
    @IBAction func onRefresh(sender: Any?) {
        guard NoteSessionManager.isOnline else {
            return
        }

        refreshProgressIndicator.startAnimation(nil)
        refreshBarButton.isEnabled = false
        isSyncing = true
        NoteSessionManager.shared.sync { [weak self] in
            self?.isSyncing = false
            self?.refreshBarButton.isEnabled = NoteSessionManager.isOnline
            self?.rebuildCategoryList()
            self?.notesOutlineView.reloadData()
            self?.notesViewController?.notesView.reloadData()
            self?.refreshProgressIndicator.stopAnimation(nil)
        }

    }

    func rebuildCategoryList() {
        self.nodeArray.removeAll()
        self.nodeArray.append(FavoritesNotesNode())
        self.nodeArray.append(AllNotesNode())
        self.nodeArray.append(StarredNotesNode())
        if let categories = CDNote.categories() {
            for category in categories {
                if category.isEmpty {
                    self.nodeArray.append(CategoryNode(category: category))
                    self.nodeArray.append(CategoriesNotesNode())
                } else {
                    self.nodeArray.append(CategoryNode(category: category))
                }
            }
        }
    }

}

extension SourceListController: NSOutlineViewDelegate {
    
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
        if noteNode.isGroupItem {
            if let groupView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "GroupCell"), owner: self) as? NSTableCellView {
                groupView.textField?.stringValue = noteNode.title
                return groupView
            }
        } else {
            if let categoryView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CategoryCell"), owner: self) as? NSTableCellView {
                categoryView.textField?.stringValue = noteNode.title
                if let _ = item as? StarredNotesNode {
                    categoryView.imageView?.image = NSImage.favoriteImage
                } else {
                    categoryView.imageView?.image = NSImage.folderImage
                }
                return categoryView
            }
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 17.0
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return SourceTableRowView(frame: .zero)
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let noteNode = item as? NoteTreeNode else {
            return false
        }
        return noteNode.isGroupItem
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        selectedColumn = notesOutlineView.selectedColumnIndexes
        selectedRow = notesOutlineView.selectedRow
        
        if let selectedRow = selectedRow, let selectedObject = notesOutlineView.item(atRow: selectedRow) as? NoteTreeNode {
            currentNode = selectedObject
            notesViewController?.node = currentNode
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return false
    }
}

extension SourceListController: NSOutlineViewDataSource {

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

extension NSImage {
    static var favoriteImage = NSImage(named: "Starred Articles")
    static var folderImage = NSImage(named: "folder")
}
