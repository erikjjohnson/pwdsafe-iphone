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

- (iPWSDatabaseFactory *)databaseFactory;
- (iPWSDropBoxPreferences *)dropBoxPreferences;

- (void)displayResolutionChoices;
- (void)updateStatus:(NSString *)status;
- (void)cancelButtonPressed;
- (void)popView;

- (void)notifyResolutionWithModel:(iPWSDatabaseModel *)theModel;
- (void)notifyFailureWithOldModel:(iPWSDatabaseModel *)oldModel newModel:(iPWSDatabaseModel *)newModel;
- (void)notifyAbandonedWithReason:(NSString *)reason;
- (NSString *)dropBoxPathForModel;
@end

//------------------------------------------------------------------------------------
// Synchronizer implementation
@implementation iPWSDropBoxConflictResolver

@synthesize delegate;
@synthesize model;
@synthesize dbClient;

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
    self.model             = nil;
    self.dbClient.delegate = nil;
    self.dbClient          = nil;
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
    self.dbClient          = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
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
        [self updateStatus:@"Restoring DropBox file from our copy..."];
        [self.dbClient restoreFile:self.dropBoxPathForModel
                             toRev:[[self dropBoxPreferences] dropBoxRevForModel:self.model]];
    }
    
    if ([buttonText isEqualToString:USE_DROPBOX_PROMPT_STR]) {
        [self updateStatus:@"Getting DropBox file into temporary..."];
        NSString *temporary = [self.databaseFactory createUniqueFilenameWithPrefix:
                               [self.model.fileName lastPathComponent]];
        [self.dbClient loadFile:self.dropBoxPathForModel 
                       intoPath:[self.databaseFactory.documentsDirectory stringByAppendingPathComponent:temporary]];
    }

    if ([buttonText isEqualToString:MERGE_PROMPT_STR]) {
        NSLog(@"TODO: Merge");
        [self notifyResolutionWithModel:model];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)updateStatus:(NSString *)status {
    statusLabel.text = status;
}

- (void)cancelButtonPressed {
    [self popView];
}

- (void)popView {
    self.dbClient.delegate = nil;
    self.dbClient          = nil;
    [self.navigationController popViewControllerAnimated:YES];    
}

//------------------------------------------------------------------------------------
// Private interface

// Replace mine with theirs
- (void)restClient:(DBRestClient *)client restoredFile:(DBMetadata *)fileMetadata {
    [self notifyResolutionWithModel:self.model];
    [self popView];
}

- (void)restClient:(DBRestClient *)client restoreFileFailedWithError:(NSError *)error {
    [self notifyAbandonedWithReason:@"Failed to restore safe to DropBox"];
    [self popView];
}


// Replace theirs with mine
- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath contentType:(NSString *)contentType {
    // Attempt to open the downloaded model with the same passphrase
    NSError *errorMsg;
    iPWSDatabaseModel *newModel = [[[iPWSDatabaseModel alloc] initNamed:self.model.friendlyName
                                                             fileNamed:destPath
                                                            passphrase:self.model.passphrase
                                                              errorMsg:&errorMsg] autorelease];
    if (!newModel) {
        [self notifyAbandonedWithReason:[NSString stringWithFormat:@"Unable to open DropBox safe: %@", 
                                         [errorMsg localizedDescription]]];
        [self popView];
        return;
    }
    
    if (![self.databaseFactory replaceExistingModel:self.model withUnmappedModel:newModel errorMsg:&errorMsg]) {
        [self notifyFailureWithOldModel:self.model newModel:newModel];
        [self popView];
        return;
    }
    
    [self notifyResolutionWithModel:newModel];
    [self popView];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    [self notifyAbandonedWithReason:@"Failed to get the DropBox safe"];
    [self popView];
}


// TODO Merge

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
    if ([self.delegate respondsToSelector:@selector(dropBoxConflictResolverWasAbandoned:reason:)]) {
        [self.delegate dropBoxConflictResolverWasAbandoned:self reason:reason];
    }
}

@end
