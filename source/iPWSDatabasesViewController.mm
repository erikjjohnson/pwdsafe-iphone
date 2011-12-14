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
#import "iPWSDatabaseDetailViewController.h"
#import "iPWSDatabaseModelViewController.h"
#import "PasswordAlertView.h"

//------------------------------------------------------------------------------------
// Private interface declaration
@interface iPWSDatabasesViewController ()
- (void)addDatabaseButtonPressed;
- (void)updateEditButton;

- (NSString *)friendlyNameAtIndex:(NSInteger)idx;

- (void)showDatabaseDetailsForModel:(iPWSDatabaseModel *)model;
- (void)showDatabaseModel:(iPWSDatabaseModel *)model;

- (void)promptForPassphraseForName:(NSString *)friendlyName tag:(NSInteger)tag;

- (void)alertForError:(NSError *)errorMsg;
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
    PASSPHRASE_PROMPT_OPEN_DATABASE_TAG,
    PASSPHRASE_PROMPT_SHOW_DATABASE_DETAILS_TAG
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
@synthesize databaseFactory;

- (UIBarButtonItem *)addDatabaseButton {
    // Lazy initialize a "plus" button
    if (!addDatabaseButton) {
        addDatabaseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                          target:self
                                                                          action:@selector(addDatabaseButtonPressed)];
    }
    return addDatabaseButton;
}

//------------------------------------------------------------------------------------
// Interface handlers

// Update the navigation buttons and toolbar items
- (void)viewDidLoad {
    [super viewDidLoad];

    if (!passphrasePromptContext) passphrasePromptContext = [[[NSMutableDictionary alloc] init] retain];
    if (!databaseFactory)         databaseFactory         = [[iPWSDatabaseFactory alloc] initWithDelegate:self];
    
    self.navigationItem.title = @"Safes";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Set the toolbar
    iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    self.toolbarItems = [NSArray arrayWithObjects: self.addDatabaseButton, 
                                                   appDelegate.flexibleSpaceButton,
                                                   appDelegate.lockAllDatabasesButton, 
                                                   nil];
}

// Unhide the toolbar
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = NO; 
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}


//------------------------------------------------------------------------------------
// Table view data source

// Only enable the edit button if there is at least one database
- (void)updateEditButton {
    NSInteger count = [databaseFactory.friendlyNames count];
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
    return [databaseFactory.friendlyNames count];
}

// Each cell is simply the friendly name of the database
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault 
                                       reuseIdentifier:CellIdentifier] autorelease];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
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
        if (![databaseFactory removeDatabaseNamed:[self friendlyNameAtIndex:indexPath.row] errorMsg:&errorMsg]) {
            [self alertForError:errorMsg];
            return;
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
    NSString *friendlyName = [self friendlyNameAtIndex: indexPath.row];
    iPWSDatabaseModel *model = [databaseFactory databaseModelNamed:friendlyName errorMsg:NULL];
    
    // If the model exists, open the view. Otherwise, ask for the password and open it later
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
// Custom actions

// Called when a detailed view of a database is requested (i.e., edit the database friendly name)
- (void)tableView: (UITableView *)tableView accessoryButtonTappedForRowWithIndexPath: (NSIndexPath *)indexPath {
    NSString *friendlyName = [self friendlyNameAtIndex: indexPath.row];
    iPWSDatabaseModel *model = [databaseFactory databaseModelNamed:friendlyName errorMsg:NULL];
    
    // If the model exists, open the details view. Otherwise, ask for the password and open it later
    if (model) {
        [self showDatabaseDetailsForModel:model];
    } else {
        [self promptForPassphraseForName:friendlyName
                                     tag:PASSPHRASE_PROMPT_SHOW_DATABASE_DETAILS_TAG];
    }    
}


//------------------------------------------------------------------------------------
// Add operations

// The add new database either by importing or creating new
- (void)addDatabaseButtonPressed {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Create or Import Safe?"
                                                             delegate:self 
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:CREATE_DATABASE_BUTTON_STR, IMPORT_DATABASE_BUTTON_STR, nil];
    [actionSheet showInView:[self view]];    
}

// Called when the Add button action sheet is finished - either Create or Import
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == [actionSheet cancelButtonIndex]) return;
    NSString *buttonText = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    // Create a new database
    if ([buttonText isEqualToString:CREATE_DATABASE_BUTTON_STR]) {
        iPWSDatabaseAddViewController *vc = [[iPWSDatabaseAddViewController alloc] 
                                                initWithNibName:@"iPWSDatabaseAddViewController"
                                                         bundle:nil
                                                databaseFactory:databaseFactory];
        [self.navigationController pushViewController:vc animated:YES];
        [vc release];
    }
    
    // Import an existing database
    if ([buttonText isEqualToString:IMPORT_DATABASE_BUTTON_STR]) {
        iPWSDatabaseImportViewController *vc = [[iPWSDatabaseImportViewController alloc]
                                                initWithNibName:@"iPWSDatabaseImportViewController"
                                                         bundle:nil
                                                databaseFactory:databaseFactory];
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
//    v.alertViewStyle = UIAlertViewStyleSecureTextInput;
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
    if (![databaseFactory addDatabaseNamed:friendlyName
                             withFileNamed:[[databaseFactory databasePathForName:friendlyName] lastPathComponent]
                                passphrase:alertView.passwordTextField.text
                                  errorMsg:&errorMsg]) {
        [self alertForError:errorMsg];
        return;
    }
    
    // Do any final special processing    
    if (PASSPHRASE_PROMPT_OPEN_DATABASE_TAG == theAlertView.tag) {
        [self showDatabaseModel:[databaseFactory databaseModelNamed:friendlyName errorMsg:NULL]];
    }
    
    if (PASSPHRASE_PROMPT_SHOW_DATABASE_DETAILS_TAG == theAlertView.tag) {
        [self showDatabaseDetailsForModel:[databaseFactory databaseModelNamed:friendlyName errorMsg:NULL]];
    }
}

//------------------------------------------------------------------------------------
// Memory management
- (void)dealloc {
    [addDatabaseButton release];
    [databaseFactory release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Database management (iPWSDatabaseFactoryDelegate protocol implementation)

// Add a new database into the map of databases and synchronize this information with the user defaults
- (void)iPWSDatabaseFactory:(iPWSDatabaseFactory *)databaseFactory didAddModelNamed:(NSString *)friendlyName {
    [self.tableView reloadData];
}

- (void)iPWSDatabaseFactory:(iPWSDatabaseFactory *)databaseFactory 
        didRenameModelNamed:(NSString *)origFriendlyName 
                  toNewName:(NSString *)newFriendlyName {
    [self.tableView reloadData];
}

- (void)iPWSDatabaseFactory:(iPWSDatabaseFactory *)databaseFactory didRemoveModelNamed:(NSString *)friendlyName {
    [self.tableView reloadData];
}

//------------------------------------------------------------------------------------
// Private helper routines

- (NSString *)friendlyNameAtIndex:(NSInteger)idx {
    return [[databaseFactory friendlyNames] objectAtIndex:idx];
}


- (void)alertForError:(NSError *)errorMsg {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[errorMsg localizedDescription]
                                                    message:nil
                                                   delegate:nil
                                          cancelButtonTitle:@"Dismiss"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)showDatabaseDetailsForModel:(iPWSDatabaseModel *)model {
    if (!model) return;
    iPWSDatabaseDetailViewController *vc = [[iPWSDatabaseDetailViewController alloc] 
                                            initWithNibName:@"iPWSDatabaseDetailViewController"
                                                     bundle:nil
                                            databaseFactory:databaseFactory
                                                      model:model];
    [self.navigationController pushViewController:vc animated:YES];
    [vc release];
}

@end

