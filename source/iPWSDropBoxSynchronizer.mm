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
#import "iPWSDropBoxPreferences.h"
#import "iPWSDropBoxAuthenticator.h"
#import "iPasswordSafeAppDelegate.h"
#import "DismissAlertView.h"
#import "DropboxSDK/DropboxSDK.h"

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxSynchronizer
// Description:
//  The Dropbox synchronizer tracks a given database models and keeps it in sync with
//  Dropbox.  The synchronizer watches for when the model changes and typically silently merges with the
//  same named file on Dropbox.  This merge process could be transparent, or require manual intervention, depending
//  on whether or not conflicts arise.

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDropBoxSynchronizer () 
@property (retain) iPWSDatabaseModel *model;
@property (retain) DBRestClient      *dbClient;
@property (assign, getter=isViewShowing) BOOL viewShowing;
- (iPWSDatabaseFactory *)databaseFactory;

- (void)synchronizeCurrentModel;
- (void)cancelAndDisableSynchronization;
- (void)resolveConflict;

- (void)listenForModelChanges;
- (void)stopListeningForModelChanges;
- (void)modelChanged:(NSNotification *)notification;
- (void)modelClosed:(NSNotification *)notification;
- (void)closeAllSafes;

- (void)showView;
- (void)hideView;
- (void)updateStatus:(NSString *)status;
@end

//------------------------------------------------------------------------------------
// Synchronizer implementation
@implementation iPWSDropBoxSynchronizer

@synthesize viewShowing;
@synthesize model;
@synthesize dbClient;

// Canonical initializer
- (id)initWithModel:(iPWSDatabaseModel *)theModel {
    if (self = [super initWithNibName:@"iPWSDropBoxSynchronizerView" bundle:nil]) {  
        self.viewShowing          = NO;
        self.navigationItem.title = @"Dropbox Sync";
        self.model                = theModel;
        [self listenForModelChanges];
    }
    return self;
}

// Destructor
- (void) dealloc {
    [self cancelSynchronization];
    self.model             = nil;
    self.dbClient.delegate = nil;
    self.dbClient          = nil;
    [cancelButton release];
    [super dealloc];
}

// A cancel button to stop synchronization
- (UIBarButtonItem *)cancelButton {
    if (!cancelButton) {
        cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
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

- (iPWSDatabaseFactory *)databaseFactory {
    return [iPWSDatabaseFactory sharedDatabaseFactory];
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

- (void)updateStatus:(NSString *)status {
    statusLabel.text = status;
}

//------------------------------------------------------------------------------------
// Authentication callbacks
- (void)dropBoxAuthenticatorSucceeded:(iPWSDropBoxAuthenticator *)authenticator {
    [self synchronizeCurrentModel];
}

- (void)dropBoxAuthenticatorFailed:(iPWSDropBoxAuthenticator *)authenticator {
    [self cancelAndDisableSynchronization];
}

//------------------------------------------------------------------------------------
// Stopping synchronization
- (IBAction)cancelSynchronization {
    [self hideView];
    [self stopListeningForModelChanges];
    self.dbClient.delegate = nil;
    self.dbClient          = nil;
    self.model             = nil;
}

- (void)cancelAndDisableSynchronization {
    [[iPWSDropBoxPreferences sharedPreferences] unmarkModelForDropBox:self.model];
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
                                               object:self.databaseFactory];
}

- (void)stopListeningForModelChanges {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseModelChangedNotification
                                                  object:self.model];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseFactoryModelClosedNotification 
                                                  object:self.databaseFactory];
}

- (void)modelChanged:(NSNotification *)notification {
    if (![self.model isEqual:notification.object]) {
        NSLog(@"Internal error with Dropbox synchronization.  Model mistmatch, expected %@, got %@",
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
    [self updateStatus:@"Authorizing..."];
    iPWSDropBoxAuthenticator *authenticator = [iPWSDropBoxAuthenticator sharedDropBoxAuthenticator];
    if (![authenticator isAuthenticated]) {
        [authenticator authenticateWithView:self.view delegate:self];
        return;
    }
    
    [self updateStatus:@"Uploading file to Dropbox..."];
    self.dbClient = [[[DBRestClient alloc] initWithSession:[DBSession sharedSession]] autorelease];
    self.dbClient.delegate = self;
    [self.dbClient uploadFile:[self.model.fileName lastPathComponent]
                       toPath:@"/"
                withParentRev:[[iPWSDropBoxPreferences sharedPreferences] dropBoxRevForModel:self.model]
                     fromPath:self.model.fileName];
}

- (void)resolveConflict {
    iPWSDropBoxConflictResolver *resolver = [[iPWSDropBoxConflictResolver alloc] initWithModel:self.model];
    resolver.delegate = self;
    [self.navigationController pushViewController:resolver animated:YES];
}

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath 
          metadata:(DBMetadata*)metadata {
    if ([metadata.filename isEqualToString:[self.model.fileName lastPathComponent]]) {
        [[iPWSDropBoxPreferences sharedPreferences] setDropBoxRev:metadata.rev forModel:self.model];
        [self hideView];
    } else {
        [self resolveConflict];
    }
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error {
    [self resolveConflict];
}

//------------------------------------------------------------------------------------
// Resolver delegate
- (void)closeAllSafes {
    ShowDismissAlertView(@"Closing safe", @"The conflict resolution requires safes to be closed");
    iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate lockAllDatabases];    
}

- (void)dropBoxConflictResolver:(iPWSDropBoxConflictResolver *)resolver 
      resolvedConflictIntoModel:(iPWSDatabaseModel *)theModel {
    if (![theModel isEqual:self.model]) {
        [self closeAllSafes];
    }
}

- (void)dropBoxConflictResolver:(iPWSDropBoxConflictResolver *)resolver 
           failedToReplaceModel:(iPWSDatabaseModel *)oldModel 
                      withModel:(iPWSDatabaseModel *)newModel {
    ShowDismissAlertView(@"Zoinks!", @"Something went wrong resolving the conflict.  Check iTunes and hope a backup "
                         "file is still there");
    [self closeAllSafes];
}

- (void)dropBoxConflictResolver:(iPWSDropBoxConflictResolver *)resolver failedWithReason:(NSString *)reason {
    ShowDismissAlertView(@"Failed to resolve the conflict", 
                         [NSString stringWithFormat:@"%@. Dropbox sync will be disabled. Try it again if you like.", 
                          reason]);
    [self cancelAndDisableSynchronization];
}

@end
