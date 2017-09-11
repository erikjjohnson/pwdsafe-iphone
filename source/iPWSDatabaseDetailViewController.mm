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


#import "iPWSDatabaseDetailViewController.h"
#import "iPWSDatabaseFactory.h"
#import "iPWSDropBoxPreferences.h"
#import "DismissAlertView.h"


//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDatabaseDetailViewController ()
- (NSString *)modelFriendlyName;
- (NSString *)modelPassphrase;
- (NSString *)modelNumberOfEntries;
- (NSString *)modelVersion;
- (NSString *)modelFilePath;
- (NSString *)modelWhenLastSaved;
- (NSString *)modelLastSavedBy;
- (NSString *)modelLastSavedOn;

- (UIBarButtonItem *)editButton;
- (UIBarButtonItem *)doneEditButton;
- (UIBarButtonItem *)cancelEditButton;

- (BOOL)editing;
- (void)setEditing:(BOOL)isEditing;
- (void)editButtonPressed;
- (void)returnButtonPressed;
- (void)doneEditButtonPressed;
- (void)cancelEditButtonPressed;

- (void)duplicationAlertWithDescription:(NSString *)description success:(BOOL)success;

- (iPWSDatabaseFactory *)databaseFactory;
@end

//------------------------------------------------------------------------------------
// Class iPWSDatabaseDetailViewController
// Description
//  The DatabaseDetailViewController displays the header information about the given PasswordSafe model.  This includes
//  the number of entries in the file, the version of the file, the creation date and creation machine.  In addition,
//  the filename is displayed allowing for iTunes file sharing management.
@implementation iPWSDatabaseDetailViewController

//------------------------------------------------------------------------------------
// Public interface

// Initialization
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil
                model:(iPWSDatabaseModel *)theModel {
    if (self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        model                     = [theModel retain];
        self.navigationItem.title = @"Details";
        editing = NO;
    }
    return self;
}

// Deallocation
- (void)dealloc {
    [model release];
    [editButton release];
    [returnButton release];
    [doneEditButton release];
    [cancelEditButton release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Interface handlers
- (void)viewDidLoad {
    [super viewDidLoad];
    [(UIScrollView *)self.view setContentSize:CGSizeMake(320, 400)];
    self.navigationItem.rightBarButtonItem = self.editButton;
    self.navigationItem.leftBarButtonItem  = self.returnButton;
    
    modelNameTextField.text    = [self modelFriendlyName];
    modelNameTextField.enabled = NO;
    
    passphraseTextField.text    = [self modelPassphrase];
    passphraseTextField.enabled = NO;
    
    numberOfEntriesTextField.text = [self modelNumberOfEntries];
    versionTextField.text         = [self modelVersion];
    filenameTextField.text        = [self modelFilePath];
    lastSavedTextField.text       = [self modelWhenLastSaved];
    savedByTextField.text         = [self modelLastSavedBy];
    savedOnTextField.text         = [self modelLastSavedOn];    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = YES;   
}

- (void)viewDidAppear:(BOOL)animated {
    syncWithDropBoxSwitch.on = [[iPWSDropBoxPreferences sharedPreferences] isModelSynchronizedWithDropBox:model];   
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}
-(BOOL)shouldAutorotate { return YES; }
-(NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

- (iPWSDatabaseFactory *)databaseFactory {
    return [iPWSDatabaseFactory sharedDatabaseFactory];
}


//------------------------------------------------------------------------------------
// Editable buttons
- (IBAction)duplicateButtonPressed {
    // Get the current friendly name and append - copy (x) until we find an unused name
    NSString *newFriendlyName = [NSString stringWithFormat:@"%@ - copy", [self modelFriendlyName]];
    
    int cnt = 2;
    while ((cnt < 10) && [self.databaseFactory doesFriendlyNameExist:newFriendlyName]) {
        newFriendlyName = [NSString stringWithFormat:@"%@ - copy(%d)", [self modelFriendlyName], cnt++];
    }
    
    if ([self.databaseFactory doesFriendlyNameExist:newFriendlyName]) {
        [self duplicationAlertWithDescription:@"Too many copies already exist." success:NO];
        return;
    }
    
    if (![self.databaseFactory duplicateDatabaseNamed:[self modelFriendlyName]
                                            toNewName:newFriendlyName
                                             errorMsg:NULL]) {
        NSString *msg = @"An internal error prevented a duplicate file from being created";
        [self duplicationAlertWithDescription:msg success:NO];
        return;
    }
    
    NSString *msg = [NSString stringWithFormat:@"The new safe is named \"%@\"", newFriendlyName];
    [self duplicationAlertWithDescription:msg success:YES];
}

- (void)duplicationAlertWithDescription:(NSString *)description success:(BOOL)success {
    ShowDismissAlertView(success ? @"Safe was duplicated" : @"Failed to duplicate safe", description);
}

- (void)syncWithDropBoxChanged {
    if ([syncWithDropBoxSwitch isOn]) {
        [[iPWSDropBoxPreferences sharedPreferences] markModelForDropBox:model];
    } else {
        [[iPWSDropBoxPreferences sharedPreferences] unmarkModelForDropBox:model];
    }
}

//------------------------------------------------------------------------------------
// Private interface 
- (NSString *)modelFriendlyName {
    return model.friendlyName;
}

- (NSString *)modelPassphrase {
    return model.passphrase;
}

- (NSString *)modelNumberOfEntries {
    //  TODO: delete
    //    return [NSString stringWithFormat:@"%d", [model.entries count]];
    return [NSString stringWithFormat:@"%lu", [model.entries count]];
}

- (NSString *)modelVersion {
    return [iPWSDatabaseModel databaseVersionToString:model.version];
}

- (NSString *)modelFilePath {
    return [model.fileName lastPathComponent];
}

- (NSString *)modelWhenLastSaved {
    return [[NSDate dateWithTimeIntervalSince1970:model.headerRecord->m_whenlastsaved] description];
}

- (NSString *)modelLastSavedBy {
   return [NSString stringWithFormat:@"%ls", model.headerRecord->m_lastsavedby.c_str()];
}

- (NSString *)modelLastSavedOn {
    return [NSString stringWithFormat:@"%ls", model.headerRecord->m_lastsavedon.c_str()];
}


//------------------------------------------------------------------------------------
// Navigation buttons
- (UIBarButtonItem *)editButton {
    if (!editButton) {
        editButton = [[UIBarButtonItem alloc] initWithTitle:@"Edit"
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(editButtonPressed)];
    }
    return editButton;
}

- (UIBarButtonItem *)returnButton {
    if (!returnButton) {
        returnButton = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(returnButtonPressed)];
    }
    return returnButton;
}

- (UIBarButtonItem *)doneEditButton {
    if (!doneEditButton) {
        doneEditButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                          style:UIBarButtonItemStyleDone
                                                         target:self
                                                         action:@selector(doneEditButtonPressed)];
    }
    return doneEditButton;
}

- (UIBarButtonItem *)cancelEditButton {
    if (!cancelEditButton) {
        cancelEditButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(cancelEditButtonPressed)];
    }
    return cancelEditButton;
}


//------------------------------------------------------------------------------------
// Handle editing modes
- (BOOL)editing {
    return editing;
}

- (void)setEditing:(BOOL)isEditing {
    editing = isEditing;
    if (editing) {
        [modelNameTextField setEnabled:YES];
        [passphraseTextField setEnabled:YES];
        self.navigationItem.leftBarButtonItem  = self.cancelEditButton;
        self.navigationItem.rightBarButtonItem = self.doneEditButton;        
    } else {
        [modelNameTextField resignFirstResponder];
        [passphraseTextField resignFirstResponder];
        [modelNameTextField setEnabled:NO];
        [passphraseTextField setEnabled:NO];
        modelNameTextField.text  = [self modelFriendlyName];
        passphraseTextField.text = [self modelPassphrase];
        self.navigationItem.leftBarButtonItem  = nil;
        self.navigationItem.rightBarButtonItem = self.editButton;        
    }
}

- (void) editButtonPressed {
    self.editing = YES;
}

- (void)returnButtonPressed {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration: 1.0];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft 
                           forView:self.navigationController.view 
                             cache:NO];
    [self.navigationController popViewControllerAnimated:NO];
    [UIView commitAnimations];
}

- (void)doneEditButtonPressed {
    // Check for renaming
    NSString *origName = model.friendlyName;
    NSString *newName  = modelNameTextField.text;
    if (![origName isEqualToString:newName]) {
        NSError *errorMsg;
        iPWSDatabaseFactory *databaseFactory = [iPWSDatabaseFactory sharedDatabaseFactory];
        if (![databaseFactory renameDatabaseNamed:origName toNewName:newName errorMsg:&errorMsg]) {
            ShowDismissAlertView(@"Rename failed", [errorMsg localizedDescription]);
        }
    }
    
    // Check for new passphrase
    NSString *origPassphrase = model.passphrase;
    NSString *newPassphrase  = passphraseTextField.text;
    if (![origPassphrase isEqualToString:newPassphrase]) {
        if (![model changePassphrase:newPassphrase]) {
            ShowDismissAlertView(@"Failed to change passphrase", 
                                 @"An unexpected error prevent the passphrase from changing");
        }
    }
    
    self.editing = NO;
}

- (void)cancelEditButtonPressed {
    self.editing = NO;
}

- (IBAction)modelNameChanged {
    if (editing) {
        [self.navigationItem.rightBarButtonItem setEnabled: (0 != [modelNameTextField.text length])];
    }
}

- (IBAction)passphraseChanged {
    if (editing) {
        [self.navigationItem.rightBarButtonItem setEnabled: (0 != [passphraseTextField.text length])];
    }
}

@end

