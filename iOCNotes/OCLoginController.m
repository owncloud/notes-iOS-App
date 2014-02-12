//
//  OCLoginController.m
//  iOCNews
//

/************************************************************************
 
 Copyright 2013 Peter Hedlund peter.hedlund@me.com
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 *************************************************************************/

#import "OCLoginController.h"
#import "OCAPIClient.h"
#import "KeychainItemWrapper.h"
#import "UILabel+VerticalAlignment.h"

static const NSString *rootPath = @"index.php/apps/notes/api/v0.2/";

@interface OCLoginController ()

@end

@implementation OCLoginController

@synthesize keychain;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    NSString *version = @"Version ";
    version = [version stringByAppendingString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    self.statusLabel.textVerticalAlignment = UITextVerticalAlignmentTop;
    self.serverTextField.delegate = self;
    self.usernameTextField.delegate = self;
    self.passwordTextField.delegate = self;
    self.certificateCell.accessoryView = self.certificateSwitch;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.serverTextField.text = [prefs stringForKey:@"Server"];
    self.usernameTextField.text = [self.keychain objectForKey:(__bridge id)(kSecAttrAccount)];
    self.passwordTextField.text = [self.keychain objectForKey:(__bridge id)(kSecValueData)];
    self.certificateSwitch.on = [prefs boolForKey:@"AllowInvalidSSLCertificate"];
    
    NSString *status;
    if ([OCAPIClient sharedClient].reachabilityManager.isReachable) {
        status = [NSString stringWithFormat:@"Connected to an ownCloud Notes server at \"%@\".", [[NSUserDefaults standardUserDefaults] stringForKey:@"Server"]];
    } else {
        status = @"Currently not connected to an ownCloud Notes server";
    }
    self.statusLabel.text = status;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:true];
        [self.connectionActivityIndicator startAnimating];
        OCAPIClient *client = [[OCAPIClient alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", self.serverTextField.text, rootPath]]];
        [client setRequestSerializer:[AFJSONRequestSerializer serializer]];
        [client.requestSerializer setAuthorizationHeaderFieldWithUsername:self.usernameTextField.text password:self.passwordTextField.text];

        BOOL allowInvalid = self.certificateSwitch.on;
        client.securityPolicy.allowInvalidCertificates = allowInvalid;
        NSDictionary *params = @{@"exclude": @"content"};
        
        [client GET:@"notes" parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
            NSLog(@"notes: %@", responseObject);
                        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
            [prefs setObject:self.serverTextField.text forKey:@"Server"];
            [self.keychain setObject:self.usernameTextField.text forKey:(__bridge id)(kSecAttrAccount)];
            [self.keychain setObject:self.passwordTextField.text forKey:(__bridge id)(kSecValueData)];
            [prefs setBool:self.certificateSwitch.on forKey:@"AllowInvalidSSLCertificate"];
            [prefs synchronize];
            [OCAPIClient setSharedClient:nil];
            int status = [[OCAPIClient sharedClient].reachabilityManager networkReachabilityStatus];
            NSLog(@"Server status: %i", status);
            self.statusLabel.text = [NSString stringWithFormat:@"Connected to an ownCloud Notes server at \"%@\".", self.serverTextField.text];
            
            [self.connectionActivityIndicator stopAnimating];

        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSLog(@"Error: %@, response: %ld", [error localizedDescription], (long)[response statusCode]);
            self.statusLabel.text = @"Failed to connect to a server. Check your settings.";
            [self.connectionActivityIndicator stopAnimating];
        }];
    }
}

- (KeychainItemWrapper *)keychain {
    if (!keychain) {
        keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"iOCNotes" accessGroup:nil];
        [keychain setObject:(__bridge id)(kSecAttrAccessibleWhenUnlocked) forKey:(__bridge id)(kSecAttrAccessible)];
    }
    return keychain;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField isEqual:self.serverTextField]) {
        [self.usernameTextField becomeFirstResponder];
    }
    if ([textField isEqual:self.usernameTextField]) {
        [self.passwordTextField becomeFirstResponder];
    }
    if ([textField isEqual:self.passwordTextField]) {
        [textField resignFirstResponder];
    }
    return YES;
}

@end
