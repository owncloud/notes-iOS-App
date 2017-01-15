//
//  OCNoteOperation.m
//  iOCNotes
//

/************************************************************************
 
 Copyright 2015 Peter Hedlund peter.hedlund@me.com
 
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


#import "OCNoteOperation.h"
#import "OCNote.h"
#import "OCAPIClient.h"
#import "NSDictionary+HandleNull.h"

@interface OCNoteOperation ()
{
    BOOL _isFinished;
    BOOL _isExecuting;
}

- (void)finish;

@end

@implementation OCNoteOperation

@synthesize note = _note;
@synthesize delegate = _delegate;
@synthesize errorMessage = _errorMessage;
@synthesize responseDictionary = _responseDictionary;

-(id)initWithNote:(OCNote *)note delegate:(id<OCNoteOperationDelegate>)theDelegate {
    if ((self = [self init])) {
        _note = note;
        _delegate = theDelegate;
        _errorMessage = nil;
        _responseDictionary = nil;
        _isExecuting = NO;
        _isFinished = NO;
        self.qualityOfService = NSQualityOfServiceUserInitiated;
    }
    return self;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start
{
//    if (![NSThread isMainThread])
//    {
//        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
//        return;
//    }
    
    if (self.isCancelled) {
        [self willChangeValueForKey:@"isFinished"];
        _isFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    [self performOperation];
}

- (void)finish {    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}

- (void)performOperation {
    NSLog(@"Should be implemented by subclasses");
}

@end
