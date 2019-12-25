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
#if targetEnvironment(macCatalyst)
import AppKitInterface
#endif

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
        #if targetEnvironment(macCatalyst)
        if let bundleUrl = Bundle.main.builtInPlugInsURL {
            let pluginUrl = bundleUrl.appendingPathComponent("AppKitGlue").appendingPathExtension("bundle")
            if let appKitBundle = Bundle(url: pluginUrl) {
                if let entryPoint = appKitBundle.classNamed("AppKitGlue.AppKitEntryPoint") as? AppKitInterfaceProtocol.Type {
                    let plugin = entryPoint.init()
                    print(plugin.message())
                }
            }
        }
        #else
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
//        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { (error) in
//            
//        }

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

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        builder.remove(menu: .services)
        builder.remove(menu: .format)
        builder.remove(menu: .toolbar)
        let fullScreenMenu = builder.menu(for: .fullscreen)
        builder.remove(menu: .view)

        let preferencesCommand = UIKeyCommand(input: ",", modifierFlags: [.command], action: #selector(openPreferences))
        preferencesCommand.title = "Preferences..."
        let openPreferences = UIMenu(title: "Preferences...", image: nil, identifier: UIMenu.Identifier("openPreferences"), options: .displayInline, children: [preferencesCommand])
        builder.replace(menu: .preferences, with: openPreferences)
        
        let newNoteCommand = UIKeyCommand(input: "N", modifierFlags: [.command], action: #selector(newNote))
        newNoteCommand.title = "New"
        let newNoteMenu = UIMenu(title: "New", image: nil, identifier: UIMenu.Identifier("newNote"), options: .displayInline, children: [newNoteCommand])
        builder.replace(menu: .newScene, with: newNoteMenu)

        let importCommand = UICommand(title: "Import...", action: #selector(importNote))
        let exportCommand = UICommand(title: "Export...", action: #selector(exportNote))
        let importExportMenu = UIMenu(title: "ImportExport", image: nil, identifier: UIMenu.Identifier("importExport"), options: .displayInline, children: [importCommand, exportCommand])
        builder.insertSibling(importExportMenu, afterMenu: UIMenu.Identifier("newNote"))

        let syncCommand = UIKeyCommand(input: "R", modifierFlags: [.command], action: #selector(syncNotes))
        syncCommand.title = "Sync Notes"
        let syncNotesMenu = UIMenu(title: "Sync Notes", image: nil, identifier: UIMenu.Identifier("syncNotes"), options: .displayInline, children: [syncCommand])
        let viewMenu = UIMenu(title: "View ", image: nil, identifier: UIMenu.Identifier("_view"), options: [], children: [syncNotesMenu])
        builder.insertSibling(viewMenu, afterMenu: .edit)
        if let fullScreenMenu = fullScreenMenu {
            builder.insertChild(fullScreenMenu, atEndOfMenu: UIMenu.Identifier("_view"))
        }

        let previewCommand = UICommand(title: "Preview Markup", action: #selector(previewNote))
        let categoryCommand = UICommand(title: "Change Category...", action: #selector(changeCategory))
        let deleteCommand = UIKeyCommand(input: "\u{8}", modifierFlags: [.command], action: #selector(deleteNote))
        deleteCommand.title = "Delete"

        let previewMenu = UIMenu(title: "Preview", image: nil, identifier: UIMenu.Identifier("preview"), options: .displayInline, children: [previewCommand])
        let categoryMenu = UIMenu(title: "Category", image: nil, identifier: UIMenu.Identifier("category"), options: .displayInline, children: [categoryCommand])
        let noteMenu = UIMenu(title: "Note ", image: nil, identifier: UIMenu.Identifier("note"), options: [], children: [previewMenu, categoryMenu, deleteCommand])
        builder.insertSibling(noteMenu, beforeMenu: .window)
    }
    
    override func validate(_ command: UICommand) {
        print(command.description)
    }
    
    @objc func openPreferences() {
        let userActivity = NSUserActivity(activityType: "com.peterandlinda.CloudNotes.appSettings")
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil) { (e) in
            print("error", e)
        }
    }
    
    @objc func newNote() {
        //
    }
    
    @objc func syncNotes() {
        //
    }

    @objc func importNote() {
        //
    }

    @objc func exportNote() {
        //
    }
    
    @objc func previewNote() {
        //
    }

    @objc func changeCategory() {
        let activity = NSUserActivity(activityType: "com.peterandlinda.CloudNotes.categories")
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { (error) in
            
        }
    }

    @objc func deleteNote() {
        //
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.userActivities.first?.activityType == "com.peterandlinda.CloudNotes.categories" {
            let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = CategoriesSceneDelegate.self
            configuration.storyboard = UIStoryboard(name: "Categories", bundle: Bundle.main)
            return configuration
        } else if options.userActivities.first?.activityType == "com.peterandlinda.CloudNotes.appSettings" {
            let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = SettingsSceneDelegate.self
            configuration.storyboard = UIStoryboard(name: "Settings", bundle: Bundle.main)
            return configuration
        } else {
            let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//            configuration.delegateClass = SceneDelegate.self
//            configuration.storyboard = UIStoryboard(name: "Main_iPhone", bundle: Bundle.main)
            return configuration
        }
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}
