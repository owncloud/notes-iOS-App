//
//  LoginTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/17/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import KeychainAccess
import Alamofire
import SwiftMessages

class LoginTableViewController: UITableViewController {

    @IBOutlet var serverTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var connectionActivityIndicator: UIActivityIndicatorView!
    @IBOutlet var connectLabel: UILabel!
    @IBOutlet weak var certificateSwitch: UISwitch!

    private let session = Session(serverTrustManager: CustomServerTrustPolicyManager(allHostsMustBeEvaluated: true, evaluators: [:]))

    override func viewDidLoad() {
        super.viewDidLoad()
        self.serverTextField.delegate = self
        self.usernameTextField.delegate = self
        self.passwordTextField.delegate = self
        #if targetEnvironment(macCatalyst)
        navigationController?.navigationBar.isHidden = true
        self.tableView.sectionHeaderHeight = UITableView.automaticDimension;
        self.tableView.estimatedSectionHeaderHeight = 44.0;
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let server = KeychainHelper.server
        self.serverTextField.text = server
        self.usernameTextField.text = KeychainHelper.username
        self.passwordTextField.text = KeychainHelper.password
        certificateSwitch.isOn = KeychainHelper.allowUntrustedCertificate
        if NoteSessionManager.isConnectedToServer {
            self.connectLabel.text = NSLocalizedString("Reconnect", comment: "A button title")
        } else {
            self.connectLabel.text = NSLocalizedString("Connect", comment: "A button title")
        }
    }

    // MARK: - Table view data source
    #if !targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return UITableView.automaticDimension
        }
        return 0.0001
    }
    #endif
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        default:
            guard !KeychainHelper.productName.isEmpty,
                !KeychainHelper.productVersion.isEmpty
                else {
                return NSLocalizedString("Not logged in", comment: "Message about not being logged in")
            }
            let notesVersion = KeychainHelper.notesVersion.isEmpty ? "" : "\(KeychainHelper.notesVersion) "
            let format = NSLocalizedString("Using Notes %@on %@ %@.", comment:"Message with Notes version, product name and version")
            return String.localizedStringWithFormat(format, notesVersion, KeychainHelper.productName, KeychainHelper.productVersion)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1,
            connectLabel.isEnabled,
            let serverAddress = serverTextField.text,
            let username = usernameTextField.text,
            let password = passwordTextField.text else {
                return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        connectionActivityIndicator.startAnimating()
        
        NoteSessionManager.shared.status(server: serverAddress, username: username, password: password) { [weak self] in
            NoteSessionManager.shared.capabilities(server: serverAddress, username: username, password: password) { [weak self] in
                if KeychainHelper.notesApiVersion == Router.defaultApiVersion {
                    NoteSessionManager.shared.login(server: serverAddress, username: username, password: password) { [weak self] in
                        self?.connectionActivityIndicator.stopAnimating()
                        self?.tableView.reloadSections(IndexSet(integer: 1), with: .none)
                    }
                } else {
                    self?.connectionActivityIndicator.stopAnimating()
                    self?.tableView.reloadSections(IndexSet(integer: 1), with: .none)
                }
            }
        }
    }
    
    @IBAction func onClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onCertificateSwitch(_ sender: Any) {
        KeychainHelper.allowUntrustedCertificate = certificateSwitch.isOn
    }

}

extension LoginTableViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == serverTextField {
            usernameTextField.becomeFirstResponder()
        } else if textField == usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var labelText = NSLocalizedString("Reconnect", comment: "A button title")
        var textHasChanged = false

        let proposedNewString = textField.text
        if (range.length + range.location) > proposedNewString?.count ?? 0 {
            return false
        }
        if var newString = proposedNewString {
            newString = (newString as NSString).replacingCharacters(in: range, with: string)

            if textField == serverTextField {
                textHasChanged = !(newString == KeychainHelper.server)
            } else if textField == usernameTextField {
                textHasChanged = !(newString == KeychainHelper.username)
            } else if textField == passwordTextField {
                textHasChanged = !(newString == KeychainHelper.password)
            }
            if (textHasChanged) {
                labelText = NSLocalizedString("Connect", comment: "A button title")
            }
        }
        connectLabel.text = labelText;
        return true
    }

}
