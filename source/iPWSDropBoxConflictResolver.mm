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


#import "iPWSDropBoxConflictResolver.h"
#import "iPWSDatabaseFactory.h"
#import "iPWSDropBoxPreferences.h"
#import "DropboxSDK/DropboxSDK.h"

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxConflictResolver
// Description:
//  The DropBox conflict resolver takes a given model that is synchronized with DropBox and 
//  is known to have a version conflict.  It prompts the user for the three means to resolve
//  the conflict: keep mine, keep theirs, or merge.


static NSString* USE_MINE_PROMPT_STR    = @"Use mine, replace DropBox";
static NSString* USE_DROPBOX_PROMPT_STR = @"Use DropBox, replace mine";
static NSString* MERGE_PROMPT_STR       = @"Merge the two safes";

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDropBoxConflictResolver () 
@property (retain) iPWSDatabaseModel *model;
@property (retain) DBRestClient      *dbClient;
@property (retain) NSString          *downloadedFile;
@property (retain) NSString          *downloadedFileRev;

- (iPWSDatabaseFactory *)databaseFactory;
- (iPWSDropBoxPreferences *)dropBoxPreferences;
- (NSString *)dropBoxPathForModel;

- (void)displayResolutionChoices;
- (void)restoreDropBoxToLocalVersion;
- (void)downloadAndOpenDropBoxSafe;
- (void)openDownloadedFile:(NSString *)fileName withPassphrase:(NSString *)passphrase;
- (void)replaceLocalModelWithModel:(iPWSDatabaseModel *)newModel;
- (void)mergeLocalModelWithModel:(iPWSDatabaseModel *)newModel;

- (void)updateStatus:(NSString *)status;
- (void)cancelButtonPressed;
- (void)popView;

- (void)notifyResolutionWithModel:(iPWSDatabaseModel *)theModel;
- (void)notifyFailureWithOldModel:(iPWSDatabaseModel *)oldModel newModel:(iPWSDatabaseModel *)newModel;
- (void)notifyAbandonedWithReason:(NSString *)reason;
@end

//------------------------------------------------------------------------------------
// Synchronizer implementation
@implementation iPWSDropBoxConflictResolver

@synthesize delegate;
@synthesize model;
@synthesize dbClient;
@synthesize downloadedFile;
@synthesize downloadedFileRev;

// Canonical initializer
- (id)initWithModel:(iPWSDatabaseModel *)theModel {
    if (self = [super initWithNibName:@"iPWSDropBoxConflictResolverView" bundle:nil]) {  
        self.navigationItem.title = @"DropBox Conflicts";
        self.model                = theModel;
    }
    return self;
}

// Destructor
- (void) dealloc {
    self.model              = nil;
    self.dbClient.delegate  = nil;
    self.dbClient           = nil;
    self.downloadedFile     = nil;
    self.downloadedFileRev  = nil;
    [cancelButton release];
    [super dealloc];
}

// A cancel button to stop synchronization
- (UIBarButtonItem *)cancelButton {
    if (!cancelButton) {
        cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel & Disable"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(cancelButtonPressed)];
    }
    return cancelButton;
}

- (iPWSDatabaseFactory *)databaseFactory {
    return [iPWSDatabaseFactory sharedDatabaseFactory];
}

- (iPWSDropBoxPreferences *)dropBoxPreferences {
    return [iPWSDropBoxPreferences sharedPreferences];
}

- (NSString *)dropBoxPathForModel {
    return [NSString stringWithFormat:@"/%@", [self.model.fileName lastPathComponent]];
}

//------------------------------------------------------------------------------------
// View handling
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    self.navigationController.toolbarHidden = YES;
    
    [self updateStatus:@"Determining strategy..."];
    self.dbClient          = [[[DBRestClient alloc] initWithSession:[DBSession sharedSession]] autorelease];
    self.dbClient.delegate = self;
    [self displayResolutionChoices];
}

- (void)displayResolutionChoices {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"A conflict was detected while synchonrizing with "
                                                                 "DropBox."
                                                       delegate:self
                                              cancelButtonTitle:@"Don't use DropBox"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:USE_MINE_PROMPT_STR,
                                                                USE_DROPBOX_PROMPT_STR,
                                                                MERGE_PROMPT_STR, nil];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self cancelButtonPressed];
        return;
    }
    
    NSString *buttonText = [actionSheet buttonTitleAtIndex:buttonIndex];
    if ([buttonText isEqualToString:USE_MINE_PROMPT_STR]) {
        [self updateStatus:@"Creating backup of DropBox safe..."];
        [self.dbClient copyFrom:self.dropBoxPathForModel toPath:[NSString stringWithFormat:@"%@.bak", 
                                                                 self.dropBoxPathForModel]];
    }
    
    if ([buttonText isEqualToString:USE_DROPBOX_PROMPT_STR]) {
        afterDownload = @selector(replaceLocalModelWithModel:);
        [self downloadAndOpenDropBoxSafe];
    }

    if ([buttonText isEqualToString:MERGE_PROMPT_STR]) {
        afterDownload = @selector(mergeLocalModelWithModel:);
        [self downloadAndOpenDropBoxSafe];
    }
}

- (void)updateStatus:(NSString *)status {
    statusLabel.text = status;
}

- (void)cancelButtonPressed {
    [self popView];
    [self notifyAbandonedWithReason:@"Synchronization canceled"];
}

- (void)popView {
    if (self.downloadedFile) {
        [[NSFileManager defaultManager] removeItemAtPath:self.downloadedFile error:NULL];
    }
    self.downloadedFile    = nil;
    self.dbClient.delegate = nil;
    self.dbClient          = nil;
    [self.navigationController popViewControllerAnimated:NO];    
}

//------------------------------------------------------------------------------------
// Private interface

// Both use theirs and merge require a download and then open of the safe
- (void)downloadAndOpenDropBoxSafe { 
    [self updateStatus:@"Getting DropBox file into temporary..."];
    NSString *temporary = [self.databaseFactory createUniqueFilenameWithPrefix: 
                           [self.model.fileName lastPathComponent]];
    [self.dbClient loadFile:self.dropBoxPathForModel 
                   intoPath:[self.databaseFactory.documentsDirectory stringByAppendingPathComponent:temporary]];

}

- (void)openDownloadedFile:(NSString *)fileName withPassphrase:(NSString *)passphrase {
    [self updateStatus:@"Attempting to open the DropBox file..."];
    
    NSError *errorMsg;
    iPWSDatabaseModel *newModel = [[[iPWSDatabaseModel alloc] initNamed:@"DropBox safe"
                                                              fileNamed:fileName
                                                             passphrase:passphrase
                                                               errorMsg:&errorMsg] autorelease];
    if (!newModel) {
        // Anything wrong except passphrase is irrecoverable
        if (errorMsg.code != PWSfile::WRONG_PASSWORD) {
            [self notifyAbandonedWithReason:[NSString stringWithFormat:@"Unable to open DropBox safe: %@", 
                                             [errorMsg localizedDescription]]];
            [self popView];
        } else {            
            // The password changed, prompt for it until the user gives up
            PasswordAlertView *v = [[PasswordAlertView alloc] initWithTitle:@"Password entry" 
                                                                    message:@"DropBox safe" 
                                                                   delegate:self 
                                                          cancelButtonTitle:@"Cancel" 
                                                            doneButtonTitle:@"OK"];
            [v show];
            [v release];
        }
        return;
    }
    
    // The model opened, so do whatever is next
    if ([self respondsToSelector:afterDownload]) {
        [self performSelector:afterDownload withObject:newModel];
    } else {
        [self notifyAbandonedWithReason:@"Internal error in conflict resolver"];
        [self popView];
    }
}

- (void)alertView:(UIAlertView *)theAlertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    PasswordAlertView *alertView = (PasswordAlertView *)theAlertView;
    if (buttonIndex == alertView.cancelButtonIndex) {
        [self notifyAbandonedWithReason:@"DropBox safe password was not known"];
        [self popView];
    } else {
        [self openDownloadedFile:self.downloadedFile withPassphrase:alertView.passwordTextField.text];
    }
}

- (void)restClient:(DBRestClient *)client 
        loadedFile:(NSString *)destPath 
       contentType:(NSString *)contentType 
          metadata:(DBMetadata *)metadata {
    self.downloadedFile    = destPath;
    self.downloadedFileRev = metadata.rev;
    NSLog(@"Downloaded file rev: %@", self.downloadedFileRev);
    [self openDownloadedFile:self.downloadedFile withPassphrase:self.model.passphrase];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    [self notifyAbandonedWithReason:@"Failed to get the DropBox safe"];
    [self popView];
}


// Replace mine with theirs
- (void)restoreDropBoxToLocalVersion {
    [self updateStatus:@"Restoring DropBox file from our copy..."];
    [self.dbClient restoreFile:self.dropBoxPathForModel
                         toRev:[[self dropBoxPreferences] dropBoxRevForModel:self.model]];
}

- (void)restClient:(DBRestClient *)client copiedPath:(NSString *)from_path toPath:(NSString *)to_path {
    [self restoreDropBoxToLocalVersion];
}

- (void)restClient:(DBRestClient *)client copyPathFailedWithError:(NSError *)error {
    [self restoreDropBoxToLocalVersion];
}

- (void)restClient:(DBRestClient *)client restoredFile:(DBMetadata *)fileMetadata {
    [self notifyResolutionWithModel:self.model];
    [self popView];
}

- (void)restClient:(DBRestClient *)client restoreFileFailedWithError:(NSError *)error {
    [self notifyAbandonedWithReason:@"Failed to restore safe to DropBox"];
    [self popView];
}

// Replace theirs with mine
- (void)replaceLocalModelWithModel:(iPWSDatabaseModel *)newModel {
    NSError *errorMsg;
    if (![self.databaseFactory replaceExistingModel:self.model withUnmappedModel:newModel errorMsg:&errorMsg]) {
        [self notifyFailureWithOldModel:self.model newModel:newModel];
    } else {
        [self notifyResolutionWithModel:newModel];
    }
    [self popView];
}

// Merge the two models
- (void)mergeLocalModelWithModel:(iPWSDatabaseModel *)newModel {
    iPWSDatabaseModelMerger *merger = [[iPWSDatabaseModelMerger alloc] initWithPrimaryModel:self.model
                                                                              secondaryModel:newModel];
    merger.delegate = self;
    [self.navigationController pushViewController:merger animated:YES];
    [merger release];
}

- (void)modelMerger:(iPWSDatabaseModelMerger *)merger 
 mergedPrimaryModel:(iPWSDatabaseModel *)primaryModel 
     secondaryModel:(iPWSDatabaseModel *)secondaryModel
          intoModel:(iPWSDatabaseModel *)mergedModel {
    [[iPWSDropBoxPreferences sharedPreferences] setDropBoxRev:self.downloadedFileRev forModel:self.model];
    [self replaceLocalModelWithModel:mergedModel];
}

- (void)modelMergerWasCancelled:(iPWSDatabaseModelMerger *)merger {
    [self cancelButtonPressed];
}

- (void)modelMerger:(iPWSDatabaseModelMerger *)merger failedWithError:(NSError *)errorMsg {
    [self notifyAbandonedWithReason:[errorMsg localizedDescription]];
    [self popView];
}


// Delegate notifications
- (void)notifyResolutionWithModel:(iPWSDatabaseModel *)theModel {
    if ([self.delegate respondsToSelector:@selector(dropBoxConflictResolver:resolvedConflictIntoModel:)]) {
        [self.delegate dropBoxConflictResolver:self resolvedConflictIntoModel:theModel];
    }
}

- (void)notifyFailureWithOldModel:(iPWSDatabaseModel *)oldModel newModel:(iPWSDatabaseModel *)newModel {
    if ([self.delegate respondsToSelector:@selector(dropBoxConflictResolver:failedToReplaceModel:withModel:)]) {
        [self.delegate dropBoxConflictResolver:self failedToReplaceModel:oldModel withModel:newModel];
    }
}

- (void)notifyAbandonedWithReason:(NSString *)reason {
    if ([self.delegate respondsToSelector:@selector(dropBoxConflictResolver:failedWithReason:)]) {
        [self.delegate dropBoxConflictResolver:self failedWithReason:reason];
    }
}

@end
