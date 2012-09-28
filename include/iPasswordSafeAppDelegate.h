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


#import <UIKit/UIKit.h>

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
@interface iPasswordSafeAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow               *window;
    UINavigationController *navigationController;
    UISplitViewController  *splitViewController;
    UIBarButtonItem        *lockAllDatabasesButton;
    UIBarButtonItem        *flexibleSpaceButton;
}

@property (nonatomic, retain) IBOutlet UIWindow               *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet UISplitViewController  *splitViewController;
@property (readonly)                   UIBarButtonItem        *lockAllDatabasesButton;
@property (readonly)                   UIBarButtonItem        *flexibleSpaceButton;

- (void)lockAllDatabases;

@end

