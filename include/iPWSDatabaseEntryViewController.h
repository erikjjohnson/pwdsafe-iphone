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
#import "iPWSDatabaseEntryModel.h"
#import "iPWSDatabaseEntryViewControllerDelegate.h"

// Class iPWSDatabaseEntryViewController
// Description
//  The EntryViewController displays a single PasswordSafe entry.  Currently this displays
//  the title, username, password, url and notes, each of which are editable.  In addition,
//  the password can be shown or hidden (i.e., secure or not) and when editing, the password
//  can be randomly generated according to system preferences.
//
//  Finally, this controller also implements a toolbar with a "copy and launch URL" operation
//  that first copies the password (or username) and the launches safari with the given URL
@interface iPWSDatabaseEntryViewController : UITableViewController <UIActionSheetDelegate> {
    iPWSDatabaseEntryModel                      *entry;
    id<iPWSDatabaseEntryViewControllerDelegate>  delegate;
    BOOL                                         editing;
    
    // Connected to the cells using Interface Builder
    IBOutlet UITableViewCell *titleCell;
    IBOutlet UITableViewCell *userCell;
    IBOutlet UITableViewCell *passphraseCell;
    IBOutlet UITableViewCell *urlCell;
    IBOutlet UITableViewCell *notesCell;
    
    // Connected to the editable entries within each cell
    IBOutlet UITextField        *titleTextField;
    IBOutlet UITextField        *userTextField;
    IBOutlet UITextField        *passphraseTextField;
    IBOutlet UIButton           *passphraseShowHideButton;
    IBOutlet UITextField        *urlTextField;
    IBOutlet UITextView         *notesTextView;
     
    // The toolbar and navigation buttons
    UIBarButtonItem *editButton;
    UIBarButtonItem *doneButton;
    UIBarButtonItem *cancelButton;
    UIBarButtonItem *copyButton;
    UIBarButtonItem *copyAndLaunchButton;
    UIButton        *randomPassphraseButton;
}

// Accessors
@property (assign) id<iPWSDatabaseEntryViewControllerDelegate> delegate;
@property BOOL editing;

@property (readonly) UITextField *titleTextField;
@property (readonly) UITextField *userTextField;
@property (readonly) UITextField *passphraseTextField;
@property (readonly) UITextField *urlTextField;
@property (readonly) UITextView  *notesTextView;

// Initialization
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil 
                entry:(iPWSDatabaseEntryModel *)theEntry
             delegate:(id<iPWSDatabaseEntryViewControllerDelegate>)theDelegate;

// Editing notifications
- (IBAction)titleTextChanged;
- (IBAction)urlTextChanged;
- (IBAction)toggleShowHidePassphrase;
@end
