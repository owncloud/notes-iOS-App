//
//  OCAPIClient.m
//  iOCNews
//

/************************************************************************
 
 Copyright 2013-2016 Peter Hedlund peter.hedlund@me.com
 
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

#import "OCAPIClient.h"
#import "PDKeychainBindings.h"

//See http://twobitlabs.com/2013/01/objective-c-singleton-pattern-unit-testing/
//Being able to reinitialize a singleton is a no no, but should happen so rarely
//we can live with it?

static const NSString *rootPath = @"apps/notes/api/v0.2/";

static OCAPIClient *_sharedClient = nil;
static dispatch_once_t oncePredicate = 0;

@implementation OCAPIClient

+ (OCAPIClient *)sharedClient {
    //static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        NSString *serverURLString = [[NSUserDefaults standardUserDefaults] stringForKey:@"Server"];
        if (serverURLString.length > 0) {
            _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", serverURLString, rootPath]]];
        }
    });
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    __block BOOL allowInvalid = [[NSUserDefaults standardUserDefaults] boolForKey:@"AllowInvalidSSLCertificate"];
    self.securityPolicy.allowInvalidCertificates = allowInvalid;

    self.requestSerializer = [OCAPIClient jsonRequestSerializer];
    
    [self.reachabilityManager startMonitoring];
    
    [self setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
        if (allowInvalid) {
            *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            return NSURLSessionAuthChallengeUseCredential;
        } else {
            return NSURLSessionAuthChallengePerformDefaultHandling;
        }
     }];
    
    return self;
}

+ (AFHTTPRequestSerializer*)httpRequestSerializer
{
    AFHTTPRequestSerializer *result = [AFHTTPRequestSerializer serializer];
    [result setAuthorizationHeaderFieldWithUsername:[[PDKeychainBindings sharedKeychainBindings] objectForKey:(__bridge id)(kSecAttrAccount)]
                                           password:[[PDKeychainBindings sharedKeychainBindings] objectForKey:(__bridge id)(kSecValueData)]];
    return result;
}

+ (AFJSONRequestSerializer*)jsonRequestSerializer
{
    AFJSONRequestSerializer *result = [AFJSONRequestSerializer serializer];
    [result setAuthorizationHeaderFieldWithUsername:[[PDKeychainBindings sharedKeychainBindings] objectForKey:(__bridge id)(kSecAttrAccount)]
                                           password:[[PDKeychainBindings sharedKeychainBindings] objectForKey:(__bridge id)(kSecValueData)]];
    return result;
}

+ (void)setSharedClient:(OCAPIClient *)client {
    oncePredicate = 0; // resets the once_token so dispatch_once will run again
    _sharedClient = client;
}

@end
