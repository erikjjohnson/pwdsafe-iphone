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
#import "iPWSDatabaseModel.h"
#import "PasswordAlertView.h"
#import "iPWSDatabaseModelMerger.h"
#import "DropboxSDK/DropboxSDK.h"

@class iPWSDropBoxConflictResolver;

// The protocol used to indicate to the caller of the conflict resolver the results of
// the resolution
@protocol iPWSDropBoxConflictResolverDelegate <NSObject>
- (void)dropBoxConflictResolver:(iPWSDropBoxConflictResolver *)resolver 
      resolvedConflictIntoModel:(iPWSDatabaseModel *)model;

- (void)dropBoxConflictResolver:(iPWSDropBoxConflictResolver *)resolver
               failedWithReason:(NSString *)reason;

- (void)dropBoxConflictResolver:(iPWSDropBoxConflictResolver *)resolver
           failedToReplaceModel:(iPWSDatabaseModel *)oldModel 
                      withModel:(iPWSDatabaseModel *)newModel;
@end

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxConflictResolver
// Description:
//  The DropBox conflict resolver takes a given model that is synchronized with DropBox and 
//  is known to have a version conflict.  It prompts the user for the three means to resolve
//  the conflict: keep mine, keep theirs, or merge.
@interface iPWSDropBoxConflictResolver : UIViewController 
    <UIActionSheetDelegate, DBRestClientDelegate, UIAlertViewDelegate, iPWSDatabaseModelMergerDelegate> {
    id<iPWSDropBoxConflictResolverDelegate>  delegate;
    iPWSDatabaseModel                       *model;
    DBRestClient                            *dbClient;
    SEL                                      afterDownload;
    NSString                                *downloadedFile;
    NSString                                *downloadedFileRev;

    IBOutlet UILabel                        *statusLabel;
    UIBarButtonItem                         *cancelButton;
}

// Initialize the view with the model to synchronize with
- (id)initWithModel:(iPWSDatabaseModel *)model;

@property (assign) id<iPWSDropBoxConflictResolverDelegate> delegate;

@end
