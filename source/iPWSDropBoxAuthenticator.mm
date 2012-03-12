// Copyright (c) 2010, Erik J. Johnson
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice, this list of 
// conditions and the following disclaimer in the documentation and/or other materials 
// provided with the distribution.
//
// Neither the name of Erik J. Johnson nor the names of its contributors may be used 
// to endorse or promote products derived from this software without specific prior 
// written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
// OF SUCH DAMAGE.

// DropBoxKeys.h is not open source, it contains the DropBox app key and secret
// To create your own version of this file:
// #define DROPBOX_APP_KEY_PLIST     YOUR_KEY
// #define DROPBOX_APP_KEY         @"YOUR_KEY"
// #define DROPBOX_APP_SECRET      @"YOUR_SECRET"
#import "DropBoxKeys.h" 

#import "iPWSDropBoxAuthenticator.h"
#import "DropboxSDK/DropboxSDK.h"

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxAuthenticator
// Description:
//  The DropBox authenticator handles the process of displaying information to the user about
//  the process of authentication.

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDropBoxAuthenticator () 
@property (retain) UIView *view;

- (void)promptForAuthorization;
- (void)promptForReauthorization;
- (void)authorizationAlertWithMessage:(NSString *)message authorizeButtonTitle:(NSString *)buttonTitle;

- (void)sendDelegateSuccess;
- (void)sendDelegateFailure;
@end

//------------------------------------------------------------------------------------
// Synchronizer implementation
@implementation iPWSDropBoxAuthenticator

@synthesize delegate;
@synthesize view;

// Get the singleton
+ (id)sharedDropBoxAuthenticator {
    static iPWSDropBoxAuthenticator *sharedAuthenticator = nil;
    @synchronized(self) {
        if (!sharedAuthenticator) {
            sharedAuthenticator = [[iPWSDropBoxAuthenticator alloc] init];
        }
    }
    return sharedAuthenticator;
}

// Canonical initializer
- (id)init {
    if (self = [super init]) {  
        // Register with DropBox
        DBSession* dbSession = [[[DBSession alloc] initWithAppKey:DROPBOX_APP_KEY
                                                        appSecret:DROPBOX_APP_SECRET
                                                             root:kDBRootAppFolder] autorelease];
        dbSession.delegate = self;
        [dbSession unlinkAll]; // TODO: Remove.  For testing only
        [DBSession setSharedSession:dbSession];
    }
    return self;
}

// Destructor
- (void) dealloc {
    [DBSession sharedSession].delegate = nil;
    self.delegate = nil;
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Authencitation
- (BOOL)isAuthenticated {
    return [[DBSession sharedSession] isLinked];
}

- (void)authenticateWithView:(UIView *)theView delegate:(id<iPWSDropBoxAuthenticatorDelegate>)theDelegate {
    if ([self isAuthenticated]) {
        [self sendDelegateSuccess];
    } else {
        self.delegate = theDelegate;
        self.view     = theView;
        [self promptForAuthorization];
    }
}

- (void)promptForAuthorization {
    NSString *additionalInstructions = @"";
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"require_passphrase_on_resume"]) {
        additionalInstructions = @" Your preferences specify locking all safes on application exit.  Thus"
                                  " after DropBox authorizes this application, you will need to re-open any"
                                  " open safes";
    }
    NSString *message = @"You will be redirected to DropBox to authorize this application.";
    [self authorizationAlertWithMessage:[NSString stringWithFormat:@"%@%@", message, additionalInstructions] 
                   authorizeButtonTitle:@"Take me to DropBox"];
}

- (void)promptForReauthorization {
    [self authorizationAlertWithMessage:@"DropBox authorization failed" 
                   authorizeButtonTitle:@"Try authorization again"];
}

// Alerting for authorization
- (void)authorizationAlertWithMessage:(NSString *)message authorizeButtonTitle:(NSString *)buttonTitle {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:message
                                                       delegate:self
                                              cancelButtonTitle:@"Don't use DropBox"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:buttonTitle, nil];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self sendDelegateFailure];
    } else {
        [[DBSession sharedSession] link];        
    }
}

//------------------------------------------------------------------------------------
// DropBox callbacks
// Invoked when DropBox is authorizing the application to have access
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([self isAuthenticated]) {
            [self sendDelegateSuccess];
        } else {
            [self promptForReauthorization];
        }
        return YES;
    }
    return NO;
}

// Drop box failed our authorization
- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId {
    [self promptForReauthorization];
}

//------------------------------------------------------------------------------------
// Delegate callbacks
- (void)sendDelegateSuccess {
    if ([self.delegate respondsToSelector:@selector(dropBoxAuthenticatorSucceeded:)]) {
        [self.delegate dropBoxAuthenticatorSucceeded:self];
    }
}

- (void)sendDelegateFailure  {
    if ([self.delegate respondsToSelector:@selector(dropBoxAuthenticatorFailed:)]) {
        [self.delegate dropBoxAuthenticatorFailed:self];
    }
}

@end
