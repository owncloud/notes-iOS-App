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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.serverTextField.delegate = self
        self.usernameTextField.delegate = self
        self.passwordTextField.delegate = self
        self.tableView.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha:1.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let server = KeychainHelper.server
        self.serverTextField.text = server
        self.usernameTextField.text = KeychainHelper.username
        self.passwordTextField.text = KeychainHelper.password
        if NotesManager.isConnectedToInternet {
            self.connectLabel.text = NSLocalizedString("Reconnect", comment: "A button title")
        } else {
            self.connectLabel.text = NSLocalizedString("Connect", comment: "A button title")
        }
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 44.0
        }
        return 0.0001
    }

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
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password
        let shouldRetry = !serverAddress.hasSuffix(".php")
        
        let router = Router.allNotes(exclude: "")
        NoteSessionManager.shared.request(router).responseDecodable { [weak self] (response: DataResponse<[NoteStruct]>) in
            if let _ = response.value {
                //                CDNote.update(notes: notes)
                var config = SwiftMessages.defaultConfig
                config.duration = .forever
                config.preferredStatusBarStyle = .default
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
            } else {
                if (shouldRetry) {
                    self?.serverTextField.text = "\(serverAddress)/index.php"
                    self?.tableView(tableView, didSelectRowAt: indexPath)
                    return
                }
                KeychainHelper.server = ""
                KeychainHelper.username = ""
                KeychainHelper.password = ""
                if let urlResponse = response.response {
                    var message = ""
                    var title = ""
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
                        if let error = response.error {
                            message = error.localizedDescription
                        } else {
                            message = NSLocalizedString("Failed to connect to a server. Check your settings.", comment: "An error message")
                        }
                    }
                    var config = SwiftMessages.defaultConfig
                    config.interactiveHide = true
                    config.duration = .forever
                    config.preferredStatusBarStyle = .default
                    SwiftMessages.show(config: config, viewProvider: {
                        let view = MessageView.viewFromNib(layout: .cardView)
                        view.configureTheme(.error, iconStyle: .default)
                        view.configureDropShadow()
                        view.configureContent(title: title,
                                              body: message,
                                              iconImage: Icon.error.image,
                                              iconText: nil,
                                              buttonImage: nil,
                                              buttonTitle: nil,
                                              buttonTapHandler: nil
                        )
                        return view
                    })
                }
            }
            self?.connectionActivityIndicator.stopAnimating()
        }
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
