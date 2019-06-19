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

class LoginTableViewController: UITableViewController {

    @IBOutlet var serverTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var certificateSwitch: UISwitch!
    @IBOutlet var certificateCell: UITableViewCell!
    @IBOutlet var connectionActivityIndicator: UIActivityIndicatorView!
    @IBOutlet var statusLabel: UILabel!

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
        let version = UserDefaults.standard.string(forKey: "version")
        self.serverTextField.text = server
        self.usernameTextField.text = KeychainHelper.username
        self.passwordTextField.text = KeychainHelper.password
//        if server == nil || server?.count == 0 {
//            self.tabView.selectLastTabViewItem(nil)
//        }
        if let version = version, version.count > 0 {
            self.statusLabel.text = "Notes version \(version) found on server"
        } else {
            self.statusLabel.text = "Not connected to Notes on a server"
        }
//        self.usernameTextField.text = [[PDKeychainBindings sharedKeychainBindings] objectForKey:(__bridge id)(kSecAttrAccount)];
//        self.passwordTextField.text = [[PDKeychainBindings sharedKeychainBindings] objectForKey:(__bridge id)(kSecValueData)];
//        self.certificateSwitch.on = [prefs boolForKey:@"AllowInvalidSSLCertificate"];
//
//        if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
//            self.connectLabel.text = NSLocalizedString(@"Reconnect", @"A button title");
//        } else {
        self.statusLabel.text = NSLocalizedString("Connect", comment: "A button title")
//        }

    }
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0001
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1,
            statusLabel.isEnabled,
            var serverAddress = serverTextField.text,
            let username = usernameTextField.text,
            let password = passwordTextField.text else {
                return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        connectionActivityIndicator.startAnimating()
        //
        //        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        //            [prefs setBool:self.certificateSwitch.on forKey:@"AllowInvalidSSLCertificate"];
        //            [prefs synchronize];
        
        serverAddress = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password
        let shouldRetry = !serverAddress.hasSuffix(".php")
        
        let router = Router.allNotes(exclude: "content")
        NoteSessionManager.shared.request(router).responseDecodable { [weak self] (response: DataResponse<[NoteStruct]>) in
            if let _ = response.value {
                //                CDNote.update(notes: notes)
                //TODO: Handle success
            } else {
                if (shouldRetry) {
                    self?.serverTextField.text = "\(serverAddress)/index.php"
                    self?.tableView(tableView, didSelectRowAt: indexPath)
                    return
                }
                KeychainHelper.server = ""
                KeychainHelper.username = ""
                KeychainHelper.password = ""
                //TODO: continue handling failure
            }
            self?.connectionActivityIndicator.stopAnimating()
        }
/*
            OCAPIClient *client = [[OCAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", serverAddress, rootPath]]];
            [client setRequestSerializer:[AFJSONRequestSerializer serializer]];
            [client.requestSerializer setAuthorizationHeaderFieldWithUsername:self.usernameTextField.text password:self.passwordTextField.text];

            BOOL allowInvalid = self.certificateSwitch.on;
            client.securityPolicy.allowInvalidCertificates = allowInvalid;
            NSDictionary *params = @{@"exclude": @"content"};

            [client GET:@"notes" parameters:params progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                //            NSLog(@"notes: %@", responseObject);
                NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
                [prefs setObject:serverAddress forKey:@"Server"];
                [[PDKeychainBindings sharedKeychainBindings] setObject:self.usernameTextField.text forKey:(__bridge id)(kSecAttrAccount)];
                [[PDKeychainBindings sharedKeychainBindings] setObject:self.passwordTextField.text forKey:(__bridge id)(kSecValueData)];
                [prefs setBool:self.certificateSwitch.on forKey:@"AllowInvalidSSLCertificate"];
                [prefs synchronize];
                [OCAPIClient setSharedClient:nil];
                #ifdef DEBUG
                int status = [[OCAPIClient sharedClient].reachabilityManager networkReachabilityStatus];
                NSLog(@"Server status: %i", status);
#endif
[self.connectionActivityIndicator stopAnimating];
//            [[SWMessage sharedInstance] showNotificationInViewControllerWithViewController:self
//                                                                   title:NSLocalizedString(@"Success", @"A message title")
//                                                                subtitle:NSLocalizedString(@"You are now connected to Notes on your server", @"A message")
//                                                                   image:nil
//                                                                    type:SWMessageNotificationTypeSuccess
//                                                                duration:SWMessageDurationAutomatic
//                                                                callback:^{
//                                                                    self.connectLabel.enabled = YES;
//                                                                    __unused BOOL success = [[SWMessage sharedInstance] dismissActiveNotification];
//                                                                }
//                                                                buttonTitle:NSLocalizedString(@"Close & Sync", @"Title of a button allowing the user to close the login screen and sync with the server")
//                                                          buttonCallback:^{
//                                                              self.connectLabel.enabled = YES;
//                                                              __unused BOOL success = [[SWMessage sharedInstance] dismissActiveNotification];
//                                                              [self dismissViewControllerAnimated:YES completion:nil];
//                                                              [[NSNotificationCenter defaultCenter] postNotificationName:@"SyncNotes" object:self];
//                                                          }
//                                             atPosition:SWMessageNotificationPositionTop
//                                   canBeDismissedByUser:YES];

} failure:^(NSURLSessionDataTask *task, NSError *error) {
    if (self->shouldRetry) {
        self.serverTextField.text = [serverAddress stringByAppendingString:@"/index.php"];
        [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    }

    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    NSString *message = @"";
    NSString *title = @"";
    //            NSLog(@"Status code: %ld", (long)response.statusCode);
    switch (response.statusCode) {
    case 200:
        title = NSLocalizedString(@"Notes not found", @"An error message title");
        message = NSLocalizedString(@"Notes could not be found on your server. Make sure it is installed and enabled", @"An error message");
        break;
    case 401:
        title = NSLocalizedString(@"Unauthorized", @"An error message title");
        message = NSLocalizedString(@"Check username and password.", @"An error message");
        break;
    case 404:
        title = NSLocalizedString(@"Server not found", @"An error message title");
        message = NSLocalizedString(@"A server installation could not be found. Check the server address.", @"An error message");
        break;
    default:
        title = NSLocalizedString(@"Connection failure", @"An error message title");
        if (error) {
            message = error.localizedDescription;
        } else {
            message = NSLocalizedString(@"Failed to connect to a server. Check your settings.", @"An error message");
        }
        break;
    }
    //            NSLog(@"Error: %@, response: %ld", [error localizedDescription], (long)[response statusCode]);
    //self.statusLabel.text = message;
    [self.connectionActivityIndicator stopAnimating];
    //            [[SWMessage sharedInstance] showNotificationInViewControllerWithViewController:self
    //                                                                   title:title
    //                                                                subtitle:message
    //                                                                   image:nil
    //                                                                    type:SWMessageNotificationTypeError
    //                                                                duration:SWMessageDurationEndless
    //                                                                callback:^{
    //                                                                    self.connectLabel.enabled = YES;
    //                                                                    __unused BOOL success = [[SWMessage sharedInstance] dismissActiveNotification];
    //                                                                }
    //                                                             buttonTitle:nil
    //                                                          buttonCallback:^{
    //                                                              //
    //                                                          }
    //                                                              atPosition:SWMessageNotificationPositionTop
    //                                                    canBeDismissedByUser:YES];
}];
}*/
    }


    @IBAction func onDone(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func onCertificateSwitch(_ sender: Any) {
//        BOOL textHasChanged = (self.certificateSwitch.on != [[NSUserDefaults standardUserDefaults] boolForKey:@"AllowInvalidSSLCertificate"]);
//        if (textHasChanged) {
//            self.connectLabel.text = NSLocalizedString(@"Connect", @"A button title");
//        } else {
//            self.connectLabel.text = NSLocalizedString(@"Reconnect", @"A button title");
//        }

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
            //        if (!textHasChanged) {
            //            textHasChanged = (self.certificateSwitch.on != [prefs boolForKey:@"AllowInvalidSSLCertificate"]);
            //        }
            if (textHasChanged) {
                labelText = NSLocalizedString("Connect", comment: "A button title")
            }
        }
        statusLabel.text = labelText;
        return true
    }

}
