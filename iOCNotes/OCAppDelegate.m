//
//  OCAppDelegate.m
//  iOCNotes
//
//  Created by Peter Hedlund on 1/16/14.
//  Copyright (c) 2014 Peter Hedlund. All rights reserved.
//

#import "OCAppDelegate.h"
#import "OCDrawerViewController.h"
#import "OCEditorViewController.h"
#import "AFNetworkActivityIndicatorManager.h"
#import <KSCrash/KSCrash.h>
#import <KSCrash/KSCrashInstallationEmail.h>

@implementation OCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    KSCrashInstallation* installation = [self makeEmailInstallation];
    [installation install];
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    [installation sendAllReportsWithCompletion:^(NSArray* reports, BOOL completed, NSError* error) {
        if(completed) {
            NSLog(@"Sent %d reports", (int)[reports count]);
        } else{
            NSLog(@"Failed to send reports: %@", error);
        }
    }];
    
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

- (KSCrashInstallation*) makeEmailInstallation {
    NSString* emailAddress = @"support@peterandlinda.com";
    
    KSCrashInstallationEmail* email = [KSCrashInstallationEmail sharedInstance];
    email.recipients = @[emailAddress];
    email.subject = @"CloudNotes Crash Report";
    email.message = @"<Please provide as much details as possible about what you were doing when the crash occurred.>";
    email.filenameFmt = @"crash-report-%d.txt.gz";
    
    [email addConditionalAlertWithTitle:@"Crash Detected"
                                message:@"CloudNotes crashed last time it was launched. Do you want to send a report to the developer?"
                              yesAnswer:@"Yes, please!"
                               noAnswer:@"No thanks"];
    
    // Uncomment to send Apple style reports instead of JSON.
    [email setReportStyle:KSCrashEmailReportStyleApple useDefaultFilenameFormat:YES];
    
    return email;
}

@end
