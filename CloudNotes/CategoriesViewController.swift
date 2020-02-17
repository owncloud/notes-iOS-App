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
    
    var note: CDNote?
    
    private var categories: [String]?
    private var selectedCategory: String?
    private var selectedRow = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addButton.isEnabled = false
        categories = CDNote.categories()
        categoriesTableView.reloadData()
    }
    
    @IBAction func onAdd(_ sender: Any) {
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
            if category == note?.category {
                categoryView.imageView?.image = NSImage(named: NSImage.menuOnStateTemplateName)
                selectedCategory = category
                selectedRow = row
                categoryTextField.stringValue = category
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
        note?.category = category
        categoriesTableView.reloadData(forRowIndexes: IndexSet([oldSelectedRow, selectedRow]), columnIndexes: IndexSet(integer: 0))
    }

}

extension CategoriesViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return categories?.count ?? 0
    }

}

extension CategoriesViewController: NSTextFieldDelegate {
    
}
