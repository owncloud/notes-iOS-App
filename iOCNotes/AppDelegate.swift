//
//  AppDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

#if !targetEnvironment(simulator)
import KSCrash
#endif
import UIKit
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
#if targetEnvironment(macCatalyst)
import AppKitInterface
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var notesTableViewController: NotesTableViewController?
    #if targetEnvironment(macCatalyst)
    var appKitPlugin: AppKitInterfaceProtocol?
    #endif
    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    private let operationQueue = OperationQueue()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        #if !targetEnvironment(simulator)
        let installation = self.makeEmailInstallation()
        installation?.install()
        #endif
        
        if #available(iOS 13.0, *) {
            _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.peterandlinda.iOCNotes.Sync", using: nil) { task in
                if let task = task as? BGAppRefreshTask {
                    print(task.description)
                    self.handleAppSync(task: task)
                }
            }
        } else {
            // Fallback on earlier versions
            // Do nothing
        }

        #if targetEnvironment(macCatalyst)
        if let bundleUrl = Bundle.main.builtInPlugInsURL {
            let pluginUrl = bundleUrl.appendingPathComponent("AppKitGlue").appendingPathExtension("bundle")
            if let appKitBundle = Bundle(url: pluginUrl) {
                if let entryPoint = appKitBundle.classNamed("AppKitGlue.AppKitEntryPoint") as? AppKitInterfaceProtocol.Type {
                    appKitPlugin = entryPoint.init()
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

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        notesTableViewController?.updateFrcDelegate(update: .disable)
        if #available(iOS 13.0, *) {
            scheduleAppSync()
        } else {
            // Fallback on earlier versions
            // Do nothing
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        notesTableViewController?.updateFrcDelegate(update: .enable(withFetch: KeychainHelper.didSyncInBackground))
        KeychainHelper.didSyncInBackground = false
    }
        
    @available(iOS 13.0, *)
    func scheduleAppSync() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        let request = BGAppRefreshTaskRequest(identifier: "com.peterandlinda.iOCNotes.Sync")
       request.earliestBeginDate = Date(timeIntervalSinceNow: 600)
       do {
          try BGTaskScheduler.shared.submit(request)
       } catch {
          print("Could not schedule app refresh: \(error)")
       }
    }
    
    @available(iOS 13.0, *)
    func handleAppSync(task: BGAppRefreshTask) {
        // Schedule a new refresh task
        scheduleAppSync()
        
        // Create an operation that performs the main part of the background task
        let operation = SyncOperation()
        
        // Provide an expiration handler for the background task
        // that cancels the operation
        task.expirationHandler = {
           operation.cancel()
        }

        // Inform the system that the background task is complete
        // when the operation completes
        operation.completionBlock = {
            KeychainHelper.didSyncInBackground = true
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        // Start the operation
        operationQueue.addOperation(operation)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if let scheme = url.scheme, scheme == "cloudnotes" {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = urlComponents?.queryItems,
                let item = queryItems.first(where: { $0.name == "note" }),
                let content = item.value {
                self.notesTableViewController?.addNote(content: content)
            }
        } else if url.isFileURL {
            do {
                _ = url.startAccessingSecurityScopedResource()
                let content = try String(contentsOf: url, encoding: .utf8)
                NoteSessionManager.shared.add(content: content, category: "")
                try FileManager.default.removeItem(at: url)
                url.stopAccessingSecurityScopedResource()
            } catch {
                print(error.localizedDescription)
            }
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

    #if targetEnvironment(macCatalyst)
    @available(iOS 13.0, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        builder.remove(menu: .services)
        builder.remove(menu: .format)
        builder.remove(menu: .toolbar)
        
        let preferencesCommand = UIKeyCommand(input: ",", modifierFlags: [.command], action: #selector(openPreferences))
        preferencesCommand.title = "Preferences..."
        let openPreferences = UIMenu(title: "Preferences...", image: nil, identifier: UIMenu.Identifier("openPreferences"), options: .displayInline, children: [preferencesCommand])
        builder.replace(menu: .preferences, with: openPreferences)
        
        if let newSceneMenuElement = builder.menu(for: .newScene)?.children.first {
            let newNoteCommand = UIKeyCommand(input: "N", modifierFlags: [.command, .shift], action: #selector(NotesTableViewController.onAdd(sender:)))
            newNoteCommand.title = "New Note"
            let newNoteMenu = UIMenu(title: "New Note", image: nil, identifier: UIMenu.Identifier("newNote"), options: .displayInline, children: [newSceneMenuElement, newNoteCommand])
            builder.replace(menu: .newScene, with: newNoteMenu)
        }
        
        let importCommand = UICommand(title: "Import...", action: #selector(importNote))
        let exportCommand = UICommand(title: "Export...", action: #selector(exportNote))
        let importExportMenu = UIMenu(title: "ImportExport", image: nil, identifier: UIMenu.Identifier("importExport"), options: .displayInline, children: [importCommand, exportCommand])
        builder.insertSibling(importExportMenu, afterMenu: UIMenu.Identifier("newNote"))
        
        let syncCommand = UIKeyCommand(input: "R", modifierFlags: [.command], action: #selector(NotesTableViewController.onRefresh(sender:)))
        syncCommand.title = "Sync Notes"
        let syncNotesMenu = UIMenu(title: "Sync Notes", image: nil, identifier: UIMenu.Identifier("syncNotes"), options: .displayInline, children: [syncCommand])
        builder.insertChild(syncNotesMenu, atStartOfMenu: .view)
        
        let previewCommand = UICommand(title: "Preview Markup", action: #selector(EditorViewController.onPreview(_:)))
        let categoryCommand = UICommand(title: "Change Category...", action: #selector(changeCategory))
        let deleteCommand = UIKeyCommand(input: "\u{8}", modifierFlags: [.command], action: #selector(EditorViewController.deleteNote(_:)))
        deleteCommand.title = "Delete"
        
        let previewMenu = UIMenu(title: "Preview", image: nil, identifier: UIMenu.Identifier("preview"), options: .displayInline, children: [previewCommand])
        let categoryMenu = UIMenu(title: "Category", image: nil, identifier: UIMenu.Identifier("category"), options: .displayInline, children: [categoryCommand])
        let noteMenu = UIMenu(title: "Note ", image: nil, identifier: UIMenu.Identifier("note"), options: [], children: [previewMenu, categoryMenu, deleteCommand])
        builder.insertSibling(noteMenu, beforeMenu: .window)
    }
    
    @available(iOS 13.0, *)
    override func validate(_ command: UICommand) {
        print(command.description)
    }
    
    @available(iOS 13.0, *)
    @objc func openPreferences() {
        let userActivity = NSUserActivity(activityType: "com.peterandlinda.CloudNotes.appSettings")
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil) { (e) in
            print("error", e)
        }
    }
    
    @objc func importNote() {
        //
    }
    
    @objc func exportNote() {
        //
    }
       
    @objc func changeCategory() {
        let activity = NSUserActivity(activityType: "com.peterandlinda.CloudNotes.categories")
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { (error) in
            
        }
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
    #endif

}

#if targetEnvironment(macCatalyst)
extension AppDelegate {
    
    func sceneDidActivate(identifier: String) {
        appKitPlugin?.sceneDidActivate(identifier: identifier)
    }
    
}
#endif

#if os(iOS)
extension UIApplication {
    
    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    
}
#endif
