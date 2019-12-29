//
//  SettingsSceneDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/3/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import SwiftUI

@available(iOS 13.0, *)
class SettingsSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        buildMacToolbar()
        windowScene.title = "Preferences"
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

    }

    @objc func onBackButtonAction(sender: UIBarButtonItem) {
        guard let settingsNavController = window?.rootViewController as? UINavigationController else {
            return
        }
        settingsNavController.popViewController(animated: true)
    }

    @objc func toolbarGroupSelectionChanged(sender: NSToolbarItemGroup) {
        let storyboard = UIStoryboard(name: "Settings", bundle:nil)
        var nav: UINavigationController?
        switch sender.selectedIndex {
        case 0:
            print("Selected Settings")
            if let settingsController = storyboard.instantiateViewController(withIdentifier: "SettingsTableViewController") as? SettingsTableViewController {
                nav = UINavigationController(rootViewController: settingsController)
            }
        case 1:
            print("Selected Server")
            if let loginController = storyboard.instantiateViewController(withIdentifier: "LoginTableViewController") as? LoginTableViewController {
                nav = UINavigationController(rootViewController: loginController)
            }
        default:
            break
        }
        window?.rootViewController = nav
    }

}

#if targetEnvironment(macCatalyst)
extension SettingsSceneDelegate {
  
    func buildMacToolbar() {
        guard let windowScene = window?.windowScene else {
            return
        }
        
        if let titlebar = windowScene.titlebar {
            let toolbar = NSToolbar(identifier: "SettingsToolbar")
            toolbar.centeredItemIdentifier = .segmented
            toolbar.allowsUserCustomization = false
            toolbar.delegate = self
            titlebar.toolbar = toolbar
            titlebar.titleVisibility = .hidden
        }
    }
    
}

extension SettingsSceneDelegate: NSToolbarDelegate {
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .back:
            let barButtonItem =  UIBarButtonItem(image: UIImage(systemName: "chevron.left"),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(self.onBackButtonAction(sender:)))
            barButtonItem.accessibilityIdentifier = itemIdentifier.rawValue
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
            return button
        case .segmented:
            // Create a new group item that hosts two buttons
            let group = NSToolbarItemGroup(itemIdentifier: .segmented,
                                           titles: ["Settings", "Server"],
                                           selectionMode: .selectOne,
                                           labels: ["section1", "section2"],
                                           target: self,
                                           action: #selector(toolbarGroupSelectionChanged))
            
            // Set the initial selection
            group.setSelected(true, at: 0)
            
            return group
            
            
        default:
            break
        }
        return nil
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .segmented,
            .flexibleSpace
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
}
#endif
