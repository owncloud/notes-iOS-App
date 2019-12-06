//
//  AppDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

//import AlamofireNetworkActivityIndicator
import KSCrash
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var notesTableViewController: NotesTableViewController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        #if !targetEnvironment(simulator)
        let installation = self.makeEmailInstallation()
        installation?.install()
        #endif
        
        //        NetworkActivityIndicatorManager.shared.isEnabled = true
        #if !targetEnvironment(macCatalyst)
        window?.tintColor = .ph_iconColor

        UINavigationBar.appearance().barTintColor = .ph_popoverButtonColor
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().tintColor = .ph_iconColor

        UIToolbar.appearance().barTintColor = .ph_popoverButtonColor
        UIToolbar.appearance().tintColor = .ph_iconColor

        UIBarButtonItem.appearance().tintColor = .ph_textColor

        UITableViewCell.appearance().backgroundColor = .ph_cellBackgroundColor

        let scrollViewArray = [
            NotesTableViewController.self,
            CategoryTableViewController.self,
            EditorViewController.self,
            PBHPreviewController.self,
            SettingsTableViewController.self,
            LoginTableViewController.self
        ]
        UIScrollView.appearance(whenContainedInInstancesOf: scrollViewArray).backgroundColor = .ph_cellBackgroundColor

        UISwitch.appearance().onTintColor = .ph_switchTintColor
        UISwitch.appearance().tintColor = .ph_switchTintColor

        UILabel.appearance().themeColor = .ph_textColor
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).themeColor = .ph_readTextColor

        UITextField.appearance().textColor = .ph_textColor
        #endif
        if let splitViewController = self.window?.rootViewController as? UISplitViewController {
            if let firstNavigationController = splitViewController.viewControllers.first as? UINavigationController {
                notesTableViewController = firstNavigationController.topViewController as? NotesTableViewController
            
            }
            if let secondNavigationController = splitViewController.viewControllers.last as? UINavigationController {
            #if targetEnvironment(macCatalyst)
            splitViewController.primaryBackgroundStyle = .sidebar
            #else
            secondNavigationController.topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            #endif
        }
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

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        builder.remove(menu: .newScene)
//        builder.remove(menu: .format)
//        builder.remove(menu: .toolbar)
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.userActivities.first?.activityType == "com.peterandlinda.CloudNotes.appSettings" {
            // Load our new window configuration
            return UISceneConfiguration(name: "Settings Configuration", sessionRole: connectingSceneSession.role)
        }
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
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
