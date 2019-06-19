//
//  SettingsTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/19/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class SettingsTableViewController: UITableViewController {

    @IBOutlet var syncOnStartSwitch: UISwitch!
    @IBOutlet var syncOnStartCell: UITableViewCell!
    @IBOutlet var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha:1.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.syncOnStartSwitch.isOn = KeychainHelper.syncOnStart
//        if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
//            self.statusLabel.text = NSLocalizedString(@"Logged In", @"A status label indicating that the user is logged in");
//        } else {
//            self.statusLabel.text =  NSLocalizedString(@"Not Logged In", @"A status label indicating that the user is not logged in");
//        }

    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func syncOnStartChanged(_ sender: Any) {
        //
    }
    
    @IBAction func didTapDone(_ sender: Any) {
        
    }
    
}
