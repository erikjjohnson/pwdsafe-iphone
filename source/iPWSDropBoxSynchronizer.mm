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


#import "iPWSDropBoxSynchronizer.h"
#import "iPWSDatabaseFactory.h"
#import "DismissAlertView.h"
#import "iPasswordSafeAppDelegate.h"
#import "DropboxSDK/DropboxSDK.h"

// DropBoxKeys.h is not open source, it contains the DropBox app key and secret
// To create your own version of this file:
// #define DROPBOX_APP_KEY_PLIST     YOUR_KEY
// #define DROPBOX_APP_KEY         @"YOUR_KEY"
// #define DROPBOX_APP_SECRET      @"YOUR_SECRET"
#import "DropBoxKeys.h" 

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxSynchronizer
// Description:
//  The DropBox synchronizer tracks a given database models and keeps it in sync with
//  DropBox.  The synchronizer watches for when the model changes and typically silently merges with the
//  same named file on DropBox.  This merge process could be transparent, or require manual intervention, depending
//  on whether or not conflicts arise.

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDropBoxSynchronizer () 
@property (retain) iPWSDatabaseModel *model;
@property (assign, getter=isViewShowing) BOOL viewShowing;

- (void)synchronizeCurrentModel;
- (void)cancelAndDisableSynchronization;

- (void)listenForModelChanges;
- (void)stopListeningForModelChanges;
- (void)modelChanged:(NSNotification *)notification;
- (void)modelClosed:(NSNotification *)notification;

- (void)showView;
- (void)hideView;
- (void)promptForAuthorization;
- (void)promptForReauthorization;
- (void)authorizationAlertWithMessage:(NSString *)message authorizeButtonTitle:(NSString *)buttonTitle;
@end

//------------------------------------------------------------------------------------
// Synchronizer implementation
@implementation iPWSDropBoxSynchronizer

@synthesize viewShowing;
@synthesize model;

// Get the singleton
+ (id)sharedDropBoxSynchronizer {
    static iPWSDropBoxSynchronizer *sharedDropBoxSynchronizer = nil;
    @synchronized(self) {
        if (nil == sharedDropBoxSynchronizer) {
            sharedDropBoxSynchronizer = [[iPWSDropBoxSynchronizer alloc] initWithNibName:@"iPWSDropBoxSynchronizerView"
                                                                                  bundle:nil];
        }
    }
    return sharedDropBoxSynchronizer;
}

// Canonical initializer
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {  
        self.viewShowing = NO;
        self.navigationItem.title = @"DropBox";
        
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
    [self cancelSynchronization];
    [DBSession sharedSession].delegate = nil;

    self.model        = nil;
    [cancelButton release];
    [super dealloc];
}

// A cancel button to stop synchronization
- (UIBarButtonItem *)cancelButton {
    if (!cancelButton) {
        cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel & Disable"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(cancelAndDisableSynchronization)];
    }
    return cancelButton;
}

// Our navigation controller is taken from our owning controller
- (UINavigationController *)navigationController {
    iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    return appDelegate.navigationController;
}

//------------------------------------------------------------------------------------
// View handling
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    self.navigationController.toolbarHidden = YES;
    self.viewShowing = YES;
    [self synchronizeCurrentModel];
}

- (void)showView {
    if (!self.isViewShowing) {
        [self.navigationController pushViewController:self animated:YES];
    }
}

- (void)hideView {
    if (self.isViewShowing) {
        [self.navigationController popViewControllerAnimated:YES];
        self.viewShowing = NO;
    }
}

- (void)promptForAuthorization {
    NSString *additionalInstructions = @"";
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"require_passphrase_on_resume"]) {
        additionalInstructions = @" Your preferences specify locking all safes on application exit.  Thus"
                                  " after DropBox authorizes this application, you will need to re-open this safe"
                                  " to resume DropBox synchronization.";
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
        [self hideView];
        if (self.model) {
            [self cancelAndDisableSynchronization];
        }
    } else {
        [[DBSession sharedSession] link];        
    }
}

//------------------------------------------------------------------------------------
// DropBox callbacks
// Invoked when DropBox is authorizing the application to have access
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            [self synchronizeCurrentModel];
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
// Start synchronization
- (BOOL)synchronizeModel:(iPWSDatabaseModel *)theModel {    
    // Only synchronize one model at a time
    if ([self.model isEqual:theModel]) return YES;
    if (self.model && ![theModel isEqual:self.model]) {
        [self cancelSynchronization];
    }
    self.model = theModel;
    [self synchronizeCurrentModel];
    [self listenForModelChanges];
    return YES;
}

- (IBAction)cancelSynchronization {
    [self hideView];
    [self stopListeningForModelChanges];
    self.model = nil;
}

- (void)cancelAndDisableSynchronization {
    [[iPWSDatabaseFactory sharedDatabaseFactory] unmarkModelNameForDropBox:self.model.friendlyName];
    [self cancelSynchronization];
}

//------------------------------------------------------------------------------------
// Private interface

//------------------------------------------------------------------------------------
// Whenver a model changes, see if we are to be synchronizing it and then do so
- (void)listenForModelChanges {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(modelChanged:)
                                                 name:iPWSDatabaseModelChangedNotification
                                               object:self.model];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(modelClosed:)
                                                 name:iPWSDatabaseFactoryModelClosedNotification 
                                               object:[iPWSDatabaseFactory sharedDatabaseFactory]];
}

- (void)stopListeningForModelChanges {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseModelChangedNotification
                                                  object:self.model];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseFactoryModelClosedNotification 
                                                  object:[iPWSDatabaseFactory sharedDatabaseFactory]];
}

- (void)modelChanged:(NSNotification *)notification {
    if (![self.model isEqual:notification.object]) {
        NSLog(@"Internal error with DropBox synchronization.  Model mistmatch, expected %@, got %@",
              self.model, notification.object);
        return;
    }
    [self synchronizeCurrentModel];
}

- (void)modelClosed:(NSNotification *)notification {
    NSString *changedModelName = [notification.userInfo objectForKey:iPWSDatabaseFactoryModelNameUserInfoKey];
    if ([self.model.friendlyName isEqual:changedModelName]) {
        [self cancelSynchronization];
    }
}

//------------------------------------------------------------------------------------
// The real synchronization work
- (void)synchronizeCurrentModel {
    if (!self.model) {
        [self cancelSynchronization];
        return;
    };
    
    // Ensure our view is up and available
    if (![self isViewShowing]) {
        [self showView];
        return;
    }
    
    // Ensure we are authorized
    if (![[DBSession sharedSession] isLinked]) {
        [self promptForAuthorization];
        return;
    }
    
    NSLog(@"Real synchronization to occur now for %@", self.model.friendlyName);
    // TODO: Call dropbox here
    
    [self hideView];  // TODO: Hide the view after dropbox calls
}

@end
