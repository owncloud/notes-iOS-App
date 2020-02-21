//
//  CategoriesViewController.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 2/16/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Cocoa

class CategoriesViewController: NSViewController {

    @IBOutlet var categoriesTableView: NSTableView!
    @IBOutlet var categoryTextField: NSTextField!
    @IBOutlet var addButton: NSButton!
    
    var note: CDNote? {
    didSet {
        selectedCategory = note?.category
        }
    }
    
    private var categories: [String]?
    private var selectedCategory: String?
    private var selectedRow = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addButton.isEnabled = false
        categoryTextField.delegate = self
        categories = CDNote.categories()
        categoriesTableView.reloadData()
    }
    
    @IBAction func onAdd(_ sender: Any) {
        let newCategory = categoryTextField.stringValue
        if !newCategory.isEmpty {
            categories?.append(newCategory)
            selectedCategory = newCategory
            categoriesTableView.reloadData()
        }
    }

    @IBAction func onSave(_ sender: Any) {
        if let note = note, let category = selectedCategory, category != note.category {
            note.category = category
            NotesManager.shared.update(note: note) { [weak self] in
                NotificationCenter.default.post(name: .editorUpdatedNote, object: note)
                self?.dismiss(nil)
            }
        } else {
            dismiss(nil)
        }
    }
}

extension CategoriesViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let categories = categories else {
            return nil
        }
        let category = categories[row]
        if let categoryView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CategoryCell"), owner: self) as? NSTableCellView {
            if category.isEmpty {
                categoryView.textField?.stringValue = Constants.noCategory
            } else {
                categoryView.textField?.stringValue = category
            }
            categoryView.imageView?.image = nil
            if category == selectedCategory {
                categoryView.imageView?.image = NSImage(named: NSImage.menuOnStateTemplateName)
                selectedRow = row
                if category.isEmpty {
                    categoryTextField.stringValue = Constants.noCategory
                } else {
                    categoryTextField.stringValue = category
                }
            }
            return categoryView
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let oldSelectedRow = selectedRow
        selectedRow = categoriesTableView.selectedRow
        guard let categories = categories else {
            return
        }
        let category = categories[selectedRow]
        if category.isEmpty {
            categoryTextField.stringValue = Constants.noCategory
        } else {
            categoryTextField.stringValue = category
        }
        selectedCategory = category
        categoriesTableView.reloadData(forRowIndexes: IndexSet([oldSelectedRow, selectedRow]), columnIndexes: IndexSet(integer: 0))
    }

}

extension CategoriesViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return categories?.count ?? 0
    }

}

extension CategoriesViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        let text = categoryTextField.stringValue
        if text.isEmpty {
            addButton.isEnabled = false
        } else {
            if let _ = categories?.lastIndex(of: text) {
                addButton.isEnabled = false
            } else {
                addButton.isEnabled = true
            }
        }
    }

}
