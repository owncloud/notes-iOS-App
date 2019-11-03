//
//  AppDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import AlamofireNetworkActivityIndicator
import KSCrash
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        #if !targetEnvironment(simulator)
        let installation = self.makeEmailInstallation()
            installation?.install()
        #endif

        NetworkActivityIndicatorManager.shared.isEnabled = true

        window?.tintColor = .ph_iconColor

        UINavigationBar.appearance().barTintColor = .ph_popoverButtonColor
        UINavigationBar.appearance().setBackgroundImage(UIImage.colorResizableImage(color: .ph_popoverButtonColor), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().tintColor = .ph_iconColor

        UIToolbar.appearance().barTintColor = .ph_popoverButtonColor
        UIToolbar.appearance().tintColor = .ph_iconColor
        UIToolbar.appearance().setBackgroundImage(UIImage.colorResizableImage(color: .ph_popoverButtonColor), forToolbarPosition: .top, barMetrics: .default)

        UIBarButtonItem.appearance().tintColor = .ph_textColor

        UITableViewCell.appearance().backgroundColor = .ph_cellBackgroundColor

        UIScrollView.appearance().backgroundColor = .ph_cellBackgroundColor
        UIScrollView.appearance(whenContainedInInstancesOf: [NotesTableViewController.self]).backgroundColor = .ph_cellBackgroundColor

        UISwitch.appearance().onTintColor = .ph_switchTintColor
        UISwitch.appearance().tintColor = .ph_switchTintColor

        UILabel.appearance().themeColor = .ph_textColor
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).themeColor = .ph_readTextColor
        
        UITextField.appearance().textColor = .ph_textColor
        
        if let splitViewController = self.window?.rootViewController as? UISplitViewController,
            let navigationController = splitViewController.viewControllers.last as? UINavigationController {
            navigationController.topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        }

        #if !targetEnvironment(simulator)
        installation?.sendAllReports { (reports, completed, error) -> Void in
            if completed {
                print("Sent \(reports?.count ?? 0) reports")
            } else {
                print("Failed to send reports: \(String(describing: error))")
            }
        }
        #endif
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.isFileURL {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                NotesManager.shared.add(content: content, category: "")
                try FileManager.default.removeItem(at: url)
            } catch { }
        }
        return true
    }

    #if !targetEnvironment(simulator)
    func makeEmailInstallation() -> KSCrashInstallation? {
        if let email = KSCrashInstallationEmail.sharedInstance() {
            let emailAddress = "support@pbh.dev";
            email.recipients = [emailAddress];
            email.subject = NSLocalizedString("CloudNotes Crash Report", comment: "Crash report email subject")
            email.message = NSLocalizedString("<Please provide as much details as possible about what you were doing when the crash occurred.>", comment: "Crash report email body placeholder")
            email.filenameFmt = "crash-report-%d.txt.gz"

            email.addConditionalAlert(withTitle: NSLocalizedString("Crash Detected", comment: "Alert view title"),
                                      message: NSLocalizedString("CloudNotes crashed last time it was launched. Do you want to send a report to the developer?", comment: ""),
                                      yesAnswer: NSLocalizedString("Yes, please!", comment: ""),
                                      noAnswer:NSLocalizedString("No thanks", comment: ""))

            // Uncomment to send Apple style reports instead of JSON.
            email.setReportStyle(KSCrashEmailReportStyleApple, useDefaultFilenameFormat: true)
            return email
        }
        return nil
    }
    #endif

}
