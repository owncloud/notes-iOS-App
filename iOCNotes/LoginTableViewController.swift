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
        if NotesManager.isConnectedToInternet {
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1,
            connectLabel.isEnabled,
            var serverAddress = serverTextField.text,
            let username = usernameTextField.text,
            let password = passwordTextField.text else {
                return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        connectionActivityIndicator.startAnimating()

        serverAddress = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !serverAddress.contains("://"),
            !serverAddress.hasPrefix("http") {
            serverAddress = "https://\(serverAddress)"
        }
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password
        let shouldRetry = !serverAddress.hasSuffix(".php")
        
        let router = Router.allNotes(exclude: "")
        AF
            .request(router)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: [NoteStruct].self) { [weak self] response in
                var message: String?
                var title: String?
                switch response.result {
                case let .success(result):
                    if !result.isEmpty {
                        if let firstNote = result.first, !firstNote.etag.isEmpty {
                            KeychainHelper.isNextCloud = true
                        } else {
                            KeychainHelper.isNextCloud = false
                        }
                        self?.showSyncMessage()
                    } else {
                        self?.pickServer()
                    }
                case let .failure(error):
                    if (shouldRetry) {
                        self?.serverTextField.text = "\(serverAddress)/index.php"
                        self?.tableView(tableView, didSelectRowAt: indexPath)
                        return
                    }
                    KeychainHelper.server = ""
                    KeychainHelper.username = ""
                    KeychainHelper.password = ""
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 200:
                            title = NSLocalizedString("Notes not found", comment: "An error message title")
                            message = NSLocalizedString("Notes could not be found on your server. Make sure it is installed and enabled", comment: "An error message");
                        case 401:
                            title = NSLocalizedString("Unauthorized", comment: "An error message title")
                            message = NSLocalizedString("Check username and password.", comment: "An error message")
                        case 404:
                            title = NSLocalizedString("Server not found", comment: "An error message title")
                            message = NSLocalizedString("A server installation could not be found. Check the server address.", comment: "An error message")
                        default:
                            title = NSLocalizedString("Connection failure", comment: "An error message title")
                            message = error.localizedDescription
                        }
                    } else {
                        title = NSLocalizedString("Connection failure", comment: "An error message title")
                        message = error.localizedDescription
                    }
                    if let title = title, let body = message {
                        NotesManager.shared.showErrorMessage(message: ErrorMessage(title: title, body: body))
                    }
                }
                self?.connectionActivityIndicator.stopAnimating()
        }
    }
    
    @IBAction func onClose(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onCertificateSwitch(_ sender: Any) {
        KeychainHelper.allowUntrustedCertificate = certificateSwitch.isOn
    }
    
    func pickServer() {
        let alert = UIAlertController(title: NSLocalizedString("Server", comment: "Alert title for selecting server brand"),
                                      message: NSLocalizedString("Unable to automatically detect type of server.\nPlease select:", comment: "Alert message for selecting server brand"),
                                      preferredStyle: .alert)
        let nextCloudAction = UIAlertAction(title: "NextCloud", style: .default) { [weak self] (_) in
            KeychainHelper.isNextCloud = true
            self?.showSyncMessage()
        }
        let ownCloudAction = UIAlertAction(title: "ownCloud", style: .default) { [weak self] (_) in
            KeychainHelper.isNextCloud = false
            self?.showSyncMessage()
        }
        alert.addAction(nextCloudAction)
        alert.addAction(ownCloudAction)
        self.present(alert, animated: true, completion: nil)
    }

    func showSyncMessage() {
        var config = SwiftMessages.defaultConfig
        config.duration = .forever
        config.preferredStatusBarStyle = .default
        config.presentationContext = .viewController(self)
        SwiftMessages.show(config: config, viewProvider: {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.success, iconStyle: .default)
            view.configureDropShadow()
            view.configureContent(title: NSLocalizedString("Success", comment: "A message title"),
                                  body: NSLocalizedString("You are now connected to Notes on your server", comment: "A message"),
                                  iconImage: Icon.success.image,
                                  iconText: nil,
                                  buttonImage: nil,
                                  buttonTitle: NSLocalizedString("Close & Sync", comment: "Title of a button allowing the user to close the login screen and sync with the server"),
                                  buttonTapHandler: { [weak self] _ in
                                    SwiftMessages.hide()
                                    self?.dismiss(animated: true, completion: nil)
                                    NotificationCenter.default.post(name: .syncNotes, object: nil)
            })
            return view
        })
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
                textHasChanged = !(newString == UserDefaults.standard.string(forKey: "Server"))
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
