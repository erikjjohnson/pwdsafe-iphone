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
#import "iPWSDatabaseAddViewController.h"
#import "iPWSDatabaseImportViewController.h"
#import "iPWSDatabaseModelViewController.h"
#import "PasswordAlertView.h"
#import "DismissAlertView.h"

//------------------------------------------------------------------------------------
// Private interface declaration
@interface iPWSDatabasesViewController ()
- (iPWSDatabaseFactory *)databaseFactory;

- (void)addDatabaseButtonPressed;
- (void)updateEditButton;

- (NSString *)friendlyNameAtIndex:(NSInteger)idx;
- (iPWSDatabaseModel *)modelForFriendlyName:(NSString *)friendlyName;
- (iPWSDatabaseModel *)modelForFriendlyNameAtIndex:(NSInteger)idx;

//- (void)showDatabaseDetailsForModel:(iPWSDatabaseModel *)model;
- (void)showDatabaseModel:(iPWSDatabaseModel *)model;

- (void)promptForPassphraseForName:(NSString *)friendlyName tag:(NSInteger)tag;

- (void)alertForError:(NSError *)errorMsg;

- (void)databasesChangedNotification:(NSNotification *)notification;
@end


//------------------------------------------------------------------------------------
// Class variables
static NSString *CREATE_DATABASE_BUTTON_STR = @"Create new safe";
static NSString *IMPORT_DATABASE_BUTTON_STR = @"Import existing safe";

// Each time we prompt for a passphrase, we have to save context regarding what the operation was that
// required the passphrase.  To this end, the passphrasePromptContext dictionary contains the following keys
// and the alertView the following tags
static NSString *kPassphrasePromptContextFriendlyName = @"kPassphrasePromptContextFriendlyName";
enum {
    PASSPHRASE_PROMPT_OPEN_DATABASE_TAG
};

//------------------------------------------------------------------------------------
// Class: iPWSDatabasesViewController
// Description:
//  The DatabasesViewController is a TableViewController that displays the list of known
//  PasswordSafe databases.  Each database is represented by a friendly name.  Internally,
//  this friendly name is mapped to a file name inside of the bundle of the application.
//  The map is persisted using the UserDefaults (i.e., "preferences") file stored with
//  the application.
@implementation iPWSDatabasesViewController

//------------------------------------------------------------------------------------
// Accessors
- (UIBarButtonItem *)addDatabaseButton {
    // Lazy initialize a "plus" button
    if (!addDatabaseButton) {
        addDatabaseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                          target:self
                                                                          action:@selector(addDatabaseButtonPressed)];
    }
    return addDatabaseButton;
}

- (iPWSDatabaseFactory *)databaseFactory {
    return [iPWSDatabaseFactory sharedDatabaseFactory];
}

//------------------------------------------------------------------------------------
// Interface handlers

// Update the navigation buttons and toolbar items
- (void)viewDidLoad {
    [super viewDidLoad];

    if (!passphrasePromptContext) passphrasePromptContext = [[NSMutableDictionary alloc] init];
    
    self.navigationItem.title = @"Safes";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Set the toolbar
    iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    self.toolbarItems = [NSArray arrayWithObjects: self.addDatabaseButton, 
                                                   appDelegate.flexibleSpaceButton,
                                                   appDelegate.lockAllDatabasesButton, 
                                                   nil];
    
    // Listen for database factory changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(databasesChangedNotification:)
                                                 name:iPWSDatabaseFactoryModelAddedNotification
                                               object:self.databaseFactory];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(databasesChangedNotification:)
                                                 name:iPWSDatabaseFactoryModelRenamedNotification
                                               object:self.databaseFactory];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(databasesChangedNotification:)
                                                 name:iPWSDatabaseFactoryModelRemovedNotification
                                               object:self.databaseFactory];
}

// Unhide the toolbar
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = NO; 
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}


//------------------------------------------------------------------------------------
// Table view data source

// Only enable the edit button if there is at least one database
- (void)updateEditButton {
    NSInteger count = [self.databaseFactory.friendlyNames count];
    if (!count) {
        self.editing = NO;
    }    
    [self.editButtonItem setEnabled:(0 != count)];
}

// Only one section - the list of friendly database names
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// The number of databases known to us
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self updateEditButton];
    return [self.databaseFactory.friendlyNames count];
}

// Each cell is simply the friendly name of the database
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault 
                                       reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.textLabel.text = [self friendlyNameAtIndex:indexPath.row];
    return cell;
}

// Yes, we can edit a database (i.e., delete it)
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// Called when a database is deleted
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
        NSError *errorMsg;
        if (![self.databaseFactory removeDatabaseNamed:[self friendlyNameAtIndex:indexPath.row] errorMsg:&errorMsg]) {
            [self alertForError:errorMsg];
        }
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        /* EMPTY */
    }   
}


//------------------------------------------------------------------------------------
// Table view delegate

// When a database is selected, prompt for the passphrase and then navigate to the model
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *friendlyName   = [self friendlyNameAtIndex:indexPath.row];
    iPWSDatabaseModel *model = [self modelForFriendlyName:friendlyName];
    if (model) {
        [self showDatabaseModel:model];
    } else {
        [self promptForPassphraseForName:friendlyName
                                     tag:PASSPHRASE_PROMPT_OPEN_DATABASE_TAG];
    }    
    
}

// Navigate to the given database model
- (void)showDatabaseModel:(iPWSDatabaseModel *)model {
    iPWSDatabaseModelViewController *vc = [[iPWSDatabaseModelViewController alloc] 
                                           initWithNibName:@"iPWSDatabaseModelViewController"
                                                    bundle:nil
                                                     model:model];
    [self.navigationController pushViewController:vc animated:YES];
    [vc release];
}


//------------------------------------------------------------------------------------
// Add operations

// The add new database either by importing or creating new
- (void)addDatabaseButtonPressed {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Create or Import Safe?"
                                                             delegate:self 
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:CREATE_DATABASE_BUTTON_STR, 
                                                                      IMPORT_DATABASE_BUTTON_STR, nil];
    [actionSheet showFromToolbar:self.navigationController.toolbar];    
}

// Called when the Add button action sheet is finished - either Create or Import
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == [actionSheet cancelButtonIndex]) return;
    NSString *buttonText = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    // Create a new database
    if ([buttonText isEqualToString:CREATE_DATABASE_BUTTON_STR]) {
        iPWSDatabaseAddViewController *vc = [[iPWSDatabaseAddViewController alloc] 
                                                initWithNibName:@"iPWSDatabaseAddViewController"
                                                         bundle:nil];
        [self.navigationController pushViewController:vc animated:YES];
        [vc release];
    }
    
    // Import an existing database
    if ([buttonText isEqualToString:IMPORT_DATABASE_BUTTON_STR]) {
        iPWSDatabaseImportViewController *vc = [[iPWSDatabaseImportViewController alloc]
                                                initWithNibName:@"iPWSDatabaseImportViewController"
                                                         bundle:nil];
        [self.navigationController pushViewController:vc animated:YES];
        [vc release];
    }
}


//------------------------------------------------------------------------------------
// Passphrase management and prompting

// Ask the user for the passphrase for a database
- (void)promptForPassphraseForName:(NSString *)friendlyName tag:(NSInteger)tag {
    // Setup the callback context
    [passphrasePromptContext setObject:friendlyName forKey:kPassphrasePromptContextFriendlyName];
    
    // Display the alert view
    PasswordAlertView *v = [[PasswordAlertView alloc] initWithTitle:@"Password entry" 
                                                            message:friendlyName 
                                                           delegate:self 
                                                  cancelButtonTitle:@"Cancel" 
                                                    doneButtonTitle:@"OK"];
    v.tag = tag;
    [v show];
    [v release];
}

// Called when the passphrase entry view is completed. Either import or open a database or show the details view
- (void)alertView:(UIAlertView *)theAlertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    PasswordAlertView *alertView = (PasswordAlertView *)theAlertView;
    if (buttonIndex == alertView.cancelButtonIndex) return;
    
    // Extract the callback context
    NSString *friendlyName = [passphrasePromptContext objectForKey:kPassphrasePromptContextFriendlyName];
    if (!friendlyName) return;

    // Add the database model
    NSError *errorMsg;
    iPWSDatabaseModel *model = [self.databaseFactory openDatabaseModelNamed:friendlyName
                                                                 passphrase:alertView.passwordTextField.text
                                                                   errorMsg:&errorMsg];
    if (!model) {
        [self alertForError:errorMsg];
        return;
    }
    
    // Do any final special processing   
    if (PASSPHRASE_PROMPT_OPEN_DATABASE_TAG == theAlertView.tag) {
        [self showDatabaseModel:model];
    }    
}

//------------------------------------------------------------------------------------
// Memory management
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [addDatabaseButton release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Database management event handling
- (void)databasesChangedNotification:(NSNotification *)notification {
    [self.tableView reloadData];
}

//------------------------------------------------------------------------------------
// Private helper routines

- (NSString *)friendlyNameAtIndex:(NSInteger)idx {
    return [[self.databaseFactory friendlyNames] objectAtIndex:idx];
}

- (iPWSDatabaseModel *)modelForFriendlyName:(NSString *)friendlyName {
    return [self.databaseFactory getOpenedDatabaseModelNamed:friendlyName errorMsg:NULL];
}

- (iPWSDatabaseModel *)modelForFriendlyNameAtIndex:(NSInteger)idx {
    return [self modelForFriendlyName:[self friendlyNameAtIndex:idx]];
}


- (void)alertForError:(NSError *)errorMsg {
    ShowDismissAlertView([errorMsg localizedDescription], nil);
}

@end

