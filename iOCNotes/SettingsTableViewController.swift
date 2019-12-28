//
//  SettingsTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/19/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import MessageUI

class SettingsTableViewController: UITableViewController {

    @IBOutlet var syncOnStartSwitch: UISwitch!
    @IBOutlet weak var offlineModeSwitch: UISwitch!
    @IBOutlet var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        #if targetEnvironment(macCatalyst)
        navigationController?.navigationBar.isHidden = true
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.syncOnStartSwitch.isOn = KeychainHelper.syncOnStart
        offlineModeSwitch.isOn = KeychainHelper.offlineMode
        if NotesManager.isConnectedToInternet {
            self.statusLabel.text = NSLocalizedString("Logged In", comment:"A status label indicating that the user is logged in")
        } else {
            self.statusLabel.text =  NSLocalizedString("Not Logged In", comment: "A status label indicating that the user is not logged in")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppDelegate.shared.sceneDidActivate(identifier: "Preferences")
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            if MFMailComposeViewController.canSendMail() {
                let mailViewController = MFMailComposeViewController()
                mailViewController.mailComposeDelegate = self
                mailViewController.setToRecipients(["support@pbh.dev"])
                mailViewController.setSubject(NSLocalizedString("CloudNotes Support Request", comment: "Support email subject"))
                mailViewController.setMessageBody(NSLocalizedString("<Please state your question or problem here>", comment: "Support email body placeholder"), isHTML: false)
                mailViewController.modalPresentationStyle = .formSheet;
                present(mailViewController, animated: true, completion: nil)
            }
        }
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination
        vc.navigationItem.rightBarButtonItem = nil
    }

    @IBAction func syncOnStartChanged(_ sender: Any) {
        KeychainHelper.syncOnStart = syncOnStartSwitch.isOn
    }
    
    @IBAction func offlineModeChanged(_ sender: Any) {
        KeychainHelper.offlineMode = offlineModeSwitch.isOn
    }

    @IBAction func onDone(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension SettingsTableViewController: MFMailComposeViewControllerDelegate {

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }

}
