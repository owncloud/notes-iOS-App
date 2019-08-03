//
//  CategoryTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 8/1/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class CategoryTableViewController: UITableViewController {
    
    let reuseIdentifier = "CategoryCell"
    
    var categories = [String]()
    var currentCategory = "No Category"
    var note: CDNote? {
        didSet {
            currentCategory = note?.category ?? "No Category"
            if currentCategory.isEmpty {
                currentCategory = "No Category"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.textLabel?.text = categories[indexPath.row]
        cell.accessoryType = .none
//        if note?.cdCategory?.isEmpty ?? true,
//            indexPath.row == 0 {
//            cell.accessoryType = .checkmark
//        } else {
            let index = categories.index(of: currentCategory)
            if indexPath.row == index {
                cell.accessoryType = .checkmark
            }
//        }
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentCategory = categories[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadData()
    }
    
    @IBAction func onCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onSave(_ sender: Any) {
    }
    
    @IBAction func onAdd(_ sender: Any) {
    }
}
