//
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


#import "iPasswordSafeAppDelegate.h"
#import "iPWSDatabasesViewController.h"
#import "iPWSDatabaseFactory.h"
#import "iPWSDropBoxAuthenticator.h"

#import "DropboxSDK/DropboxSDK.h"

//------------------------------------------------------------------------------------
// Class iPasswordSafeAppDelegate
// Description:
//  The AppDelegate is the main point of control for the application.  It receives
//  the applicationDidFinishLoadingWithOptions: message after the runtime is established.
//  
//  This app delegate, in addition to owning the window an navigation controller as is normal
//  for navigation iPhone applications, also supplies a button and method for locking all
//  of the databases.  Locking databases consists of deleting the model from memory.
//  This locking occurs when the application enters the background state if the system preference
//  says to.

// Extend the UINavigationController to return rotation settings for iOS6
@interface UINavigationController (iPasswordSafe)
@end
@implementation UINavigationController (iPasswordSafe)
-(BOOL)shouldAutorotate { return YES; }
-(NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
@end

@implementation iPasswordSafeAppDelegate

@synthesize window;
@synthesize navigationController;

#pragma mark -
#pragma mark Application lifecycle

// The first real entry point to the application.  Set the default user defaults and add the "safes" view
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Add the default user defaults (these are used before the user ever changes the
    // system preferences and should be in sync with Settings.bundle/Root.plist)
    NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES], @"show_popup_on_copy",
                              [NSNumber numberWithBool:YES], @"require_passphrase_on_resume",
                              [NSNumber numberWithBool:YES], @"preserve_files_on_delete",
                              @"8",                          @"password_generator_length",
                              [NSNumber numberWithBool:YES], @"password_generator_use_lowercase",
                              [NSNumber numberWithBool:YES], @"password_generator_use_uppercase",
                              [NSNumber numberWithBool:YES], @"password_generator_use_digits",
                              [NSNumber numberWithBool:YES], @"password_generator_use_symbols",
                              nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    
    // Add the navigation controller's view to the window and display.
    [window setRootViewController:navigationController];
    //self.window.rootViewController = self.navigationController;
    //[window addSubview:navigationController.view];
    [window makeKeyAndVisible];
    
    // Make sure the Dropbox authenticator is alive
    [iPWSDropBoxAuthenticator sharedDropBoxAuthenticator];
    return YES;
}

// Invoked when Dropbox is authorizing the application to have access
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[iPWSDropBoxAuthenticator sharedDropBoxAuthenticator] application:application handleOpenURL:url]) return YES;
    return NO;
}

// Remove all databases from memory and display the top-level screen
- (void)lockAllDatabases {
    iPWSDatabasesViewController *vc = 
        (iPWSDatabasesViewController *)[navigationController.viewControllers objectAtIndex:0];    
    [navigationController popToViewController:vc animated:NO];
    [[iPWSDatabaseFactory sharedDatabaseFactory] closeAllDatabaseModels];
}

// All toolbars can (and should) show a lockAllDatabases button as provided here
- (UIBarButtonItem *)lockAllDatabasesButton {
    // Lazy initialize a "lock" button
    if (!lockAllDatabasesButton) {
       lockAllDatabasesButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"lockbarbutton.png"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(lockAllDatabases)];
    }
    return lockAllDatabasesButton;
}

// A helper method since most toolbars will want to add flexible (expanding) space before the lock icon
- (UIBarButtonItem *)flexibleSpaceButton {
    // Lazy initialize a "flexibleSpaceButton" button
    if (!flexibleSpaceButton) {
        flexibleSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];
    }
    return flexibleSpaceButton;
}

// Called when the application is about to terminate or go into background, if the preferences indicated, discard all
// databases from memory
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self applicationWillTerminate:application];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"require_passphrase_on_resume"]) {
        [self lockAllDatabases];
    }
}

- (void)dealloc {
	[navigationController release];
	[window release];
    [lockAllDatabasesButton release];
    [flexibleSpaceButton release];
	[super dealloc];
}

@end

