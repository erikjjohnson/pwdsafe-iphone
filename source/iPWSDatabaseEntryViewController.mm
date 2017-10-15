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


#import "iPWSDatabaseEntryViewController.h"
#import "iPasswordSafeAppDelegate.h"
#import "corelib/PWPolicy.h"
#import "corelib/PWSprefs.h"
#import "DismissAlertView.h"
#import "NSString+CppStringAdditions.h"


//------------------------------------------------------------------------------------
// Private implementation
@interface iPWSDatabaseEntryViewController ()
- (UIBarButtonItem *)editButton;
- (UIBarButtonItem *)doneButton;
- (UIBarButtonItem *)cancelButton;
- (UIBarButtonItem *)copyButton;
- (UIBarButtonItem *)copyAndLaunchButton;
- (UIButton *)randomPassphraseButton;

- (void)editButtonPressed;
- (void)doneButtonPressed;
- (void)cancelButtonPressed;
- (void)copyAndLaunchButtonPressed;
- (void)randomPassphraseButtonPressed;

- (void)copySelectedIndexPathToPasteboard:(NSIndexPath *)indexPath;
@end


//------------------------------------------------------------------------------------
// Class variables
static NSString *COPY_PASSPHRASE_AND_OPEN_BUTTON_STR = @"Copy passphrase & Open";
static NSString *COPY_USERNAME_AND_OPEN_BUTTON_STR   = @"Copy username & Open";
static NSString *OPEN_BUTTON_STR                     = @"Open URL";

NSString* iPWSDatabaseEntryViewControllerEditingCompleteNotification = 
    @"iPWSDatabaseEntryViewControllerEditingCompleteNotification";
NSString* iPWSDatabaseEntryViewControllerEntryUserInfoKey = 
    @"iPWSDatabaseEntryViewControllerEntryUserInfoKey";


//------------------------------------------------------------------------------------
// Class iPWSDatabaseEntryViewController
// Description
//  The EntryViewController displays a single PasswordSafe entry.  Currently this displays
//  the title, username, password, url and notes, each of which are editable.  In addition,
//  the password can be shown or hidden (i.e., secure or not) and when editing, the password
//  can be randomly generated according to system preferences.
//
//  Finally, this controller also implements a toolbar with a "copy and launch URL" operation
//  that first copies the password (or username) and the launches safari with the given URL
@implementation iPWSDatabaseEntryViewController

//------------------------------------------------------------------------------------
// Instance methods

//------------------------------------------------------------------------------------
// Accessors
@synthesize titleTextField;
@synthesize userTextField;
@synthesize passphraseTextField;
@synthesize urlTextField;
@synthesize notesTextView;

//------------------------------------------------------------------------------------
// Initializer
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil
                entry:(iPWSDatabaseEntryModel *)theEntry {
    if (!theEntry) return nil;
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        entry                     = [theEntry retain];
        self.navigationItem.title = @"Entry";
         
        // Add the toolbar
        iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        self.toolbarItems = [NSArray arrayWithObjects: appDelegate.flexibleSpaceButton,
                                                       self.copyAndLaunchButton,
                                                       appDelegate.lockAllDatabasesButton, 
                                                       nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButton;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.toolbarHidden = NO;
    self.editing = self.editing;   // Force the edit button to check its enable/disable state 
    [self titleTextChanged];
    [self urlTextChanged];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}
-(BOOL)shouldAutorotate { return YES; }
-(NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }


//------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3; // title, user/passphrase/url, notes
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Title
        case 1: return 3; // User, passphrase, url
        case 2: return 1; // notes
        default: return 0;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    switch (indexPath.section) {
        case 0: // Title
            if (!editing) self.titleTextField.text = entry.title;
            [self.titleTextField setEnabled:NO];
            cell = titleCell;
            break;
            
        case 1: // User, passphrase, url
            switch (indexPath.row) {
                case 0: // User
                    if (!editing) self.userTextField.text = entry.user;
                    [self.userTextField setEnabled:NO];
                    cell = userCell;
                    break;
                case 1: // Passphrase
                    if (!editing) self.passphraseTextField.text = entry.password;
                    [self.passphraseTextField setEnabled:NO];
                    cell = passphraseCell;
                    break;
                case 2:
                    if (!editing) self.urlTextField.text = entry.url;
                    [self.urlTextField setEnabled:NO];
                    cell = urlCell;
                    break;
            }
            break;
        case 2: // Notes
            if (!editing) self.notesTextView.text = entry.notes;
            // TextViews have a different default font than the text fields, so change that font here to
            // match the text fields in title, username, url, and password
            self.notesTextView.font = [UIFont fontWithName:self.titleTextField.font.fontName 
                                                      size:self.titleTextField.font.pointSize];
            self.notesTextView.editable = NO;
            cell = notesCell;
            break;
    }
    
    return cell;
}


//------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Table view delegate

// Some of the cells have different heights, so handle that by returning a custom height
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: return titleCell.bounds.size.height;
        case 1:
            switch (indexPath.row) {
                case 0: return userCell.bounds.size.height;
                case 1: return passphraseCell.bounds.size.height;
                case 2: return urlCell.bounds.size.height;
            }
        case 2: return notesCell.bounds.size.height;
    }
    return 50.0;
}

// Row selection causes the field to be copied to the pasteboard, unless we are editing, in which case do nothing.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) return;
    
    [self copySelectedIndexPathToPasteboard:indexPath];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"show_popup_on_copy"]) {
        ShowDismissAlertView(@"Copied to pasteboard", @"Disable these messages in the Settings application");
    }
}

// Called when the selected field should be copied into the clipboard
- (void)copySelectedIndexPathToPasteboard:(NSIndexPath *)indexPath {
    NSString *copyText = @"unknown";
    switch (indexPath.section) {
        case 0: copyText = self.titleTextField.text; break;
        case 1:
            switch (indexPath.row) {
                case 0: copyText = self.userTextField.text; break;
                case 1: copyText = self.passphraseTextField.text; break;
                case 2: copyText = self.urlTextField.text; break;
            };
            break;
        case 2: copyText = self.notesTextView.text; break;
    }
    [[UIPasteboard generalPasteboard] setValue:copyText forPasteboardType:@"public.utf8-plain-text"];
}


//------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Memory management

- (void)dealloc {
    [entry release];
    [editButton release];
    [doneButton release];
    [cancelButton release];
    [copyButton release];
    [randomPassphraseButton release];
    [super dealloc];
}


//------------------------------------------------------------------------------------
// Editing mode changes
- (BOOL)editing {
    return editing;
}

// When editing is entered, enable the editing state of the text fields, add in a random password generation
// button and disable any row selection highlight as it it annoying while editing.
- (void)setEditing:(BOOL)isEditing {
    editing = isEditing;
    [self.titleTextField setEnabled:editing];
    [self.userTextField setEnabled:editing];
    [self.passphraseTextField setEnabled:editing];
    [self.urlTextField setEnabled:editing];
    self.notesTextView.editable = editing;
    
    // Don't allow the rows to be highlighted in editing mode
    UITableViewCellSelectionStyle style = editing ? UITableViewCellSelectionStyleNone : 
                                                    UITableViewCellSelectionStyleGray;
    titleCell.selectionStyle      = style;
    userCell.selectionStyle       = style;
    passphraseCell.selectionStyle = style;
    urlCell.selectionStyle        = style;
    notesCell.selectionStyle      = style;

    
    if (editing) {
        [self.titleTextField becomeFirstResponder];
        self.navigationItem.leftBarButtonItem  = self.cancelButton;
        self.navigationItem.rightBarButtonItem = self.doneButton; 
        passphraseCell.accessoryView           = self.randomPassphraseButton;
    } else {
        [self.titleTextField resignFirstResponder];
        self.titleTextField.text               = entry.title;
        self.userTextField.text                = entry.user;
        self.passphraseTextField.text          = entry.password;
        self.urlTextField.text                 = entry.url;
        self.notesTextView.text                = entry.notes;
        self.navigationItem.leftBarButtonItem  = nil;
        self.navigationItem.rightBarButtonItem = self.editButton;  
        passphraseCell.accessoryView           = nil;
    }
}

// Editing notifications
- (IBAction)titleTextChanged {
    // Enable the done button only if the title is not empty and contains at least one non-whitepsace character
    NSString *noWhitespace = [self.titleTextField.text stringByTrimmingCharactersInSet: 
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.navigationItem.rightBarButtonItem setEnabled:(0 != [noWhitespace length])];
}

- (IBAction)urlTextChanged {
    // Enable the copyAndLaunch button is only enabled when the URL is a valid http URL
    BOOL isValid = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlTextField.text]];
    [self.copyAndLaunchButton setEnabled:isValid];
}

- (IBAction)toggleShowHidePassphrase {
    BOOL hidePassphrase;
    if ([passphraseShowHideButton.currentTitle isEqualToString:@"Show"]) {
        [passphraseShowHideButton setTitle: @"Hide" forState:UIControlStateNormal];
        hidePassphrase = NO;
    } else {
        [passphraseShowHideButton setTitle: @"Show" forState:UIControlStateNormal];
        hidePassphrase = YES;
    }
    [self.passphraseTextField setSecureTextEntry:hidePassphrase];
}


//------------------------------------------------------------------------------------
// Private interface

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

- (UIBarButtonItem *)doneButton {
    if (!doneButton) {
        doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                      style:UIBarButtonItemStyleDone
                                                     target:self
                                                     action:@selector(doneButtonPressed)];
    }
    return doneButton;
}

- (UIBarButtonItem *)cancelButton {
    if (!cancelButton) {
        cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                        style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(cancelButtonPressed)];
    }
    return cancelButton;
}

- (UIBarButtonItem *)copyButton {
    if (!copyButton) {
       copyButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                   target:self
                                                                   action:@selector(copyButtonPressed)];
    }
    return copyButton;
}

- (UIBarButtonItem *)copyAndLaunchButton {
    if (!copyAndLaunchButton) {
        copyAndLaunchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                   target:self 
                                                                   action:@selector(copyAndLaunchButtonPressed)];
    }
    return copyAndLaunchButton;
}

- (UIButton *)randomPassphraseButton {
    if (!randomPassphraseButton) {
        randomPassphraseButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        randomPassphraseButton.frame = CGRectMake(0, 0, 32, 32);
        [randomPassphraseButton setImage:[UIImage imageNamed:@"diceicon.png"] forState:UIControlStateNormal];
        [randomPassphraseButton addTarget:self
                                    action:@selector(randomPassphraseButtonPressed)
                         forControlEvents:UIControlEventTouchUpInside];
    }
    return randomPassphraseButton;
}


- (void)editButtonPressed {
    self.editing = YES;
}

- (void)doneButtonPressed {
    entry.title    = self.titleTextField.text;
    entry.user     = self.userTextField.text;
    entry.password = self.passphraseTextField.text;
    entry.url      = self.urlTextField.text;
    entry.notes    = self.notesTextView.text;
    
    self.editing = NO;

    // Notify editing is complete
    [[NSNotificationCenter defaultCenter] 
        postNotificationName:iPWSDatabaseEntryViewControllerEditingCompleteNotification 
                      object:self
                    userInfo:[NSDictionary dictionaryWithObject:entry 
                                                         forKey:iPWSDatabaseEntryViewControllerEntryUserInfoKey]];
}

- (void)cancelButtonPressed {
    self.editing = NO;
}

- (void)randomPassphraseButtonPressed {
    PWPolicy policy;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    policy.length = [[defaults stringForKey:@"password_generator_length"] intValue];
	if (!policy.length) policy.length = 8;
    if ([defaults boolForKey:@"password_generator_use_lowercase"]) policy.flags |= PWPolicy::UseLowercase;
    if ([defaults boolForKey:@"password_generator_use_uppercase"]) policy.flags |= PWPolicy::UseUppercase;
    if ([defaults boolForKey:@"password_generator_use_digits"])    policy.flags |= PWPolicy::UseDigits;
    if ([defaults boolForKey:@"password_generator_use_symbols"])   policy.flags |= PWPolicy::UseSymbols;
    
    if (0 == policy.flags) {
        UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Cannot generate password"
                                                    message:@"The settings indicate no letters, digits, or symbols can be used in password generation.  Change the system preferences and try again."
                                                   delegate:nil
                                          cancelButtonTitle:@"Leave password unchanged"
                                          otherButtonTitles:nil];
        [v show];
        [v release];
    } else {
        StringX retval = policy.MakeRandomPassword();
        passphraseTextField.text = [[[NSString alloc] initWithBytes: retval.c_str()
                                                             length: retval.length()*sizeof(wchar_t)
                                                           encoding: kEncoding_wchar_t] autorelease];
    }
}


//------------------------------------------------------------------------------------
// Paste and Launch
- (void)copyAndLaunchButtonPressed {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Copy and Launch"
                                                             delegate:self 
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:COPY_PASSPHRASE_AND_OPEN_BUTTON_STR, 
                                                                      COPY_USERNAME_AND_OPEN_BUTTON_STR,
                                                                      OPEN_BUTTON_STR,
                                                                      nil];
    [actionSheet showInView:[self view]];    
}


// Called when the Add button action sheet is finished - either Create or Import
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == [actionSheet cancelButtonIndex]) return;
 
    NSString *buttonText = [actionSheet buttonTitleAtIndex:buttonIndex];
    if ([buttonText isEqualToString:COPY_PASSPHRASE_AND_OPEN_BUTTON_STR]) {
        [[UIPasteboard generalPasteboard] setValue:passphraseTextField.text
                                 forPasteboardType:@"public.utf8-plain-text"];
    }
    
    if ([buttonText isEqualToString:COPY_USERNAME_AND_OPEN_BUTTON_STR]) {
        [[UIPasteboard generalPasteboard] setValue:userTextField.text
                                 forPasteboardType:@"public.utf8-plain-text"];
    }
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlTextField.text]];
}


@end

