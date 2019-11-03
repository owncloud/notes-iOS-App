//
//  CategoryTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 8/1/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class CategoryTableViewController: UITableViewController {
    
    @IBOutlet weak var cancelBarButton: UIBarButtonItem!
    @IBOutlet weak var doneBarButton: UIBarButtonItem!

    let reuseIdentifier = "CategoryCell"

    var categories: [String]? {
        didSet {
            if !(categories?.contains("") ?? false) {
                categories?.insert("", at: 0)
            }
        }
    }
    
    var note: CDNote? {
        didSet {
            if let category = note?.category {
                currentCategory = category
            }
        }
    }

    private var currentCategory = ""
    private var isDirty = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = cancelBarButton
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories?.count ?? 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        let categoryName: String
        if let name = categories?[indexPath.row], !name.isEmpty {
            categoryName = name
        } else {
            categoryName = Constants.noCategory
        }
        cell.textLabel?.text = categoryName
        cell.accessoryType = .none
        let index = categories?.firstIndex(of: currentCategory)
        if indexPath.row == index {
            cell.accessoryType = .checkmark
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedCategory = categories?[indexPath.row] ?? ""
        if selectedCategory != currentCategory {
            currentCategory = selectedCategory
            tableView.reloadData()
            navigationItem.leftBarButtonItem = doneBarButton
            isDirty = true
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        if isDirty,
            let note = self.note {
            note.category = currentCategory
            NotesManager.shared.update(note: note)
            NotificationCenter.default.post(name: .doneSelectingCategory, object: nil)
        }
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onAdd(_ sender: Any) {
        let alert = UIAlertController(title: "Add Category", message: "Enter a name for the new catefgory", preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self, weak alert] (_) in
            if let textField = alert?.textFields?[0],
                let text = textField.text,
                !text.isEmpty {
                self?.categories?.append(text)
                self?.currentCategory = text
                self?.tableView.reloadData()
                self?.navigationItem.leftBarButtonItem = self?.doneBarButton
                self?.isDirty = true
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
