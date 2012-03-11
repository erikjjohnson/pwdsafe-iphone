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
//  The DropBox synchronizer tracks the database models that are kept in sync with
//  DropBox.  This tracking is done via a plist file.  The synchronizer watches for when models are opened and when
//  they are, if they are DropBox "synced" watchs for changes to model.  Any changes for a merge with the
//  same named file on DropBox.  This merge process could be transparent, or require manual intervention, depending
//  on whether or not conflicts arise.

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDropBoxSynchronizer () 
@property (retain) iPWSDatabaseModel *modelBeingSynchronized;
@property (assign, getter=isViewShowing) BOOL viewShowing;

- (void)synchronizeUserDefaults;

- (iPWSDatabaseModel *)modelForName:(NSString *)friendlyName;

- (void)synchronizeCurrentModel;

- (void)listenForApplicationNotifications;
- (void)stopListeningForApplicationNotifications;
- (void)applicationDidEnterBackground:(NSNotification *)notification;

- (void)listenForModelChanges;
- (void)stopListeningForModelChanges;
- (void)modelChanged:(NSNotification *)notification;

- (void)showView;
- (void)hideView;
- (void)promptForAuthorization;
- (void)promptForReauthorization;
- (void)authorizationAlertWithMessage:(NSString *)message authorizeButtonTitle:(NSString *)buttonTitle;
@end

// The key placed in the UserDefaults to retrieve the DropBox synchronization information
static NSString *kiPWSDropBoxSynchronizationUserDefaults = @"kiPWSDropBoxSynchronizationUserDefaults";

//------------------------------------------------------------------------------------
// Factory implementation
@implementation iPWSDropBoxSynchronizer

@synthesize viewShowing;
@synthesize modelBeingSynchronized;

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
        
        // Load the synchronization information into a mutable dictionary
        synchronizedModels     = [[NSMutableDictionary dictionary] retain];
        NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] 
                                  dictionaryForKey:kiPWSDropBoxSynchronizationUserDefaults];
        [defaults enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [synchronizedModels setObject:obj forKey:key];
        }];
        [self synchronizeUserDefaults];

        // Register with DropBox
        DBSession* dbSession = [[[DBSession alloc] initWithAppKey:DROPBOX_APP_KEY
                                                        appSecret:DROPBOX_APP_SECRET
                                                             root:kDBRootAppFolder] autorelease];
        dbSession.delegate = self;
        [dbSession unlinkAll]; // TODO: Remove.  For testing only
        [DBSession setSharedSession:dbSession];
        
        [self listenForApplicationNotifications];
        [self listenForModelChanges];
    }
    return self;
}

// Destructor
- (void) dealloc {
    [self stopListeningForModelChanges];
    [self stopListeningForApplicationNotifications];
    self.modelBeingSynchronized        = nil;
    [DBSession sharedSession].delegate = nil;
    [synchronizedModels release];
    [cancelButton release];
    [super dealloc];
}


//------------------------------------------------------------------------------------
// Helper routines
- (iPWSDatabaseFactory *)databaseFactory {
    return [iPWSDatabaseFactory sharedDatabaseFactory];
}

- (BOOL)isFriendlyNameSynchronized:(NSString *)friendlyName {
    return [[synchronizedModels allKeys] containsObject:friendlyName];
}

- (iPWSDatabaseModel *)modelForName:(NSString *)friendlyName {
    return [self.databaseFactory getOpenedDatabaseModelNamed:friendlyName errorMsg:NULL];
}

- (UIBarButtonItem *)cancelButton {
    if (!cancelButton) {
        cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(cancelSynchronization)];
    }
    return cancelButton;
}

- (UINavigationController *)navigationController {
    iPasswordSafeAppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    return appDelegate.navigationController;
}

//------------------------------------------------------------------------------------
// View handling
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = self.cancelButton;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
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
    [self authorizationAlertWithMessage:@"You will be redirected to DropBox to authorize this application. "
                                        "If your preferences lock databases on exit, re-open this safe after "
                                        "DropBox authorization."
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
    //[sheet showFromToolbar:self.navigationController.toolbar];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self hideView];
        if (self.modelBeingSynchronized) {
            [self unmarkModelNameForSynchronization:self.modelBeingSynchronized.friendlyName];
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
// Modify the list of synchronized databases

// Add a new database for synchronization
- (BOOL)markModelNameForSynchronization:(NSString *)friendlyName {
    // Sanity checks
    if ([self isFriendlyNameSynchronized:friendlyName]) return YES;
    if (![self.databaseFactory doesFriendlyNameExist:friendlyName]) return NO;
    
    // Add the synchronization information, the reference is nil since this is the first
    // time the database has been synchronized
    [synchronizedModels setObject:@"" forKey:friendlyName];
    [self synchronizeUserDefaults];
    
    return YES;
}

// Remove a database from those that are synchronized
- (BOOL)unmarkModelNameForSynchronization:(NSString *)friendlyName {
    if ([self isFriendlyNameSynchronized:friendlyName]) {
        [synchronizedModels removeObjectForKey:friendlyName];
        [self synchronizeUserDefaults];
    }
    return YES;
}

//------------------------------------------------------------------------------------
// Start synchronization
- (BOOL)synchronizeModel:(iPWSDatabaseModel *)model {
    if (![self isFriendlyNameSynchronized:model.friendlyName]) return NO;
    
    // Only synchronize one model at a time
    if (self.modelBeingSynchronized && ![model isEqual:self.modelBeingSynchronized]) {
        ShowDismissAlertView(@"DropBox synchronization conflict", @"Another safe is being synchronized");
        return NO;
    }
    self.modelBeingSynchronized = model;
    [self synchronizeCurrentModel];
    return YES;
}

- (IBAction)cancelSynchronization {
    self.modelBeingSynchronized = nil;
    [self hideView];
}

//------------------------------------------------------------------------------------
// Private interface

//------------------------------------------------------------------------------------
// Application events
- (void)listenForApplicationNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:[UIApplication  sharedApplication]];
}

- (void)stopListeningForApplicationNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:[UIApplication sharedApplication]];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self cancelSynchronization];
}

//------------------------------------------------------------------------------------
// Whenver a model changes, see if we are to be synchronizing it and then do so
// We don't listen for opened models because of an ordering issue with the views.  We need the model
// view to open and then we will lay our view on top of that view.  Listening for model open causes
// the other order to occur, occluding our synchronization view.
- (void)listenForModelChanges {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(modelChanged:)
                                                 name:iPWSDatabaseModelChangedNotification
                                               object:nil];
}

- (void)stopListeningForModelChanges {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseModelChangedNotification
                                                  object:nil];
}

- (void)modelChanged:(NSNotification *)notification {
    [self synchronizeModel:notification.object];
}

//------------------------------------------------------------------------------------
// The real synchronization work
- (void)synchronizeCurrentModel {
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
    
    NSLog(@"Real synchronization to occur now for %@", self.modelBeingSynchronized.friendlyName);
    //self.modelBeingSynchronized = nil;  // TODO: Call dropbox here
    
    [self hideView];  // TODO: Hide the view after dropbox calls
}

// Synchronize the current in-memory list of safes with the preferences
- (void)synchronizeUserDefaults {
    [[NSUserDefaults standardUserDefaults] setObject:synchronizedModels 
                                              forKey:kiPWSDropBoxSynchronizationUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize]; 
}

@end
