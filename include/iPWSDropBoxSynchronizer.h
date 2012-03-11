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
#import "DropboxSDK/DropboxSDK.h"
#import "iPWSDatabaseModel.h"

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxSynchronizer
// Description:
//  The DropBox synchronizer tracks the database models that are kept in sync with
//  DropBox.  This tracking is done via a plist file.  The synchronizer watches for when models are opened and when
//  they are, if they are DropBox "synced" watchs for changes to model.  Any changes for a merge with the
//  same named file on DropBox.  This merge process could be transparent, or require manual intervention, depending
//  on whether or not conflicts arise.

@interface iPWSDropBoxSynchronizer : UIViewController <DBSessionDelegate, UIActionSheetDelegate> {
    NSMutableDictionary *synchronizedModels; // { friendlyName -> drop box ref }
    iPWSDatabaseModel   *modelBeingSynchronized;

    IBOutlet UILabel    *statusLabel;
    BOOL                 viewShowing;
    UIBarButtonItem     *cancelButton;
}

// Access the singleton
+ (iPWSDropBoxSynchronizer *)sharedDropBoxSynchronizer;

// Event handling from the application
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url;

// Helper routines
- (BOOL)isFriendlyNameSynchronized:(NSString *)friendlyName;

// Modifing the list of synchronized models
- (BOOL)markModelNameForSynchronization:(NSString *)friendlyName;
- (BOOL)unmarkModelNameForSynchronization:(NSString *)friendlyName;

- (BOOL)synchronizeModel:(iPWSDatabaseModel *)model;
- (IBAction)cancelSynchronization;

@end
