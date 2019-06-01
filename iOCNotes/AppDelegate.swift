//
//  AppDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        /*
 
         #if !TARGET_OS_SIMULATOR
         KSCrashInstallation* installation = [self makeEmailInstallation];
         [installation install];
         #endif
         [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
         
         [UINavigationBar appearance].barTintColor = [UIColor clearColor];
         [[UINavigationBar appearance] setBackgroundImage: [UIImage resizeableImageWithColor:[UIColor colorWithRed:0.957 green:0.957 blue:0.957 alpha:0.95]] forBarMetrics:UIBarMetricsDefault];
         [[UINavigationBar appearance] setShadowImage: [UIImage new]];
         [UINavigationBar appearance].tintColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.26 alpha:1.0];
         
         [UIToolbar appearance].barTintColor = [UIColor clearColor];
         [UIToolbar appearance].tintColor = [UIColor colorWithRed:0.12 green:0.18 blue:0.26 alpha:1.0];
         [[UIToolbar appearance] setBackgroundImage: [UIImage resizeableImageWithColor:[UIColor colorWithRed:0.957 green:0.957 blue:0.957 alpha:0.95]]
         forToolbarPosition: UIToolbarPositionAny
         barMetrics: UIBarMetricsDefault];
         
         UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
         UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
         navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
         
         [OCAPIClient sharedClient];
         [OCNotesHelper sharedHelper];
                  
         #if !TARGET_OS_SIMULATOR
         [installation sendAllReportsWithCompletion:^(NSArray* reports, BOOL completed, NSError* error) {
         if(completed) {
         //            NSLog(@"Sent %d reports", (int)[reports count]);
         } else{
         //            NSLog(@"Failed to send reports: %@", error);
         }
         }];
         #endif
         
         return YES;
 
 */
        
        NotesManager.shared.sync()
        
        return true
    }
    
}

/*
 
 
 - (BOOL)application:(UIApplication *)app openURL:(nonnull NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
 [[OCAPIClient sharedClient].reachabilityManager startMonitoring];
 __unused BOOL reachable = [[OCAPIClient sharedClient] reachabilityManager].isReachable;
 if ([url isFileURL]) {
 NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
 if (content) {
 [[OCNotesHelper sharedHelper] addNote:content];
 }
 [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
 }
 return YES;
 }
 
 - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
 [[OCAPIClient sharedClient].reachabilityManager startMonitoring];
 __unused BOOL reachable = [[OCAPIClient sharedClient] reachabilityManager].isReachable;
 if ([url isFileURL]) {
 NSURL *docDir = [[OCNotesHelper sharedHelper] documentsDirectoryURL];
 docDir = [docDir URLByAppendingPathComponent:@"Inbox/" isDirectory:YES];
 //Move files out of the Inbox and remove the Inbox folder
 NSDirectoryEnumerator *inboxEnum = [[NSFileManager defaultManager] enumeratorAtURL:docDir
 includingPropertiesForKeys:@[NSURLNameKey]
 options:NSDirectoryEnumerationSkipsHiddenFiles
 errorHandler:nil];
 
 for (NSURL *fileURL in inboxEnum) {
 
 NSString *content = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
 if (content) {
 [[OCNotesHelper sharedHelper] addNote:content];
 }
 [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
 }
 }
 return YES;
 }
 
 - (void)applicationWillResignActive:(UIApplication *)application
 {
 // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
 // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
 }
 
 - (void)applicationDidEnterBackground:(UIApplication *)application
 {
 // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
 // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
 }
 
 - (void)applicationWillEnterForeground:(UIApplication *)application
 {
 // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
 }
 
 - (void)applicationDidBecomeActive:(UIApplication *)application
 {
 // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
 }
 
 - (void)applicationWillTerminate:(UIApplication *)application
 {
 // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
 }
 
 #if !TARGET_OS_SIMULATOR
 - (KSCrashInstallation*) makeEmailInstallation {
 NSString* emailAddress = @"support@peterandlinda.com";
 
 KSCrashInstallationEmail* email = [KSCrashInstallationEmail sharedInstance];
 email.recipients = @[emailAddress];
 email.subject = NSLocalizedString(@"CloudNotes Crash Report", @"Crash report email subject");
 email.message = NSLocalizedString(@"<Please provide as much details as possible about what you were doing when the crash occurred.>", @"Crash report email body placeholder");
 email.filenameFmt = @"crash-report-%d.txt.gz";
 
 [email addConditionalAlertWithTitle:NSLocalizedString(@"Crash Detected", @"Alert view title")
 message:NSLocalizedString(@"CloudNotes crashed last time it was launched. Do you want to send a report to the developer?", nil)
 yesAnswer:NSLocalizedString(@"Yes, please!", nil)
 noAnswer:NSLocalizedString(@"No thanks", nil)];
 
 // Uncomment to send Apple style reports instead of JSON.
 [email setReportStyle:KSCrashEmailReportStyleApple useDefaultFilenameFormat:YES];
 
 return email;
 }
 #endif
 
*/
