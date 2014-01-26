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

@implementation OCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)) {

        self.dynamicsDrawerViewController = (MSDynamicsDrawerViewController *)self.window.rootViewController;
        //self.dynamicsDrawerViewController.delegate = self;
        self.dynamicsDrawerViewController.shouldAlignStatusBarToPaneView = NO;
        [self.dynamicsDrawerViewController setRevealWidth:320.0f forDirection:MSDynamicsDrawerDirectionLeft];
        [self.dynamicsDrawerViewController addStylersFromArray:@[[MSDynamicsDrawerParallaxStyler styler]] forDirection:MSDynamicsDrawerDirectionLeft];
        
        OCDrawerViewController *menuViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"Notes"];
        menuViewController.dynamicsDrawerViewController = self.dynamicsDrawerViewController;
        [self.dynamicsDrawerViewController setDrawerViewController:menuViewController forDirection:MSDynamicsDrawerDirectionLeft];
        
        OCEditorViewController *editorController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"Editor"];
        editorController.dynamicsDrawerViewController = self.dynamicsDrawerViewController;
        [self.dynamicsDrawerViewController setPaneViewController:editorController];
        // Transition to the first view controller
        //[menuViewController transitionToViewController:MSPaneViewControllerTypeStylers];
        
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.rootViewController = self.dynamicsDrawerViewController;
        [self.window makeKeyAndVisible];
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

@end
