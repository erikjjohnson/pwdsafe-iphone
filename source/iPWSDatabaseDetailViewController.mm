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

// ---- Private interface
@interface iPWSDatabaseDetailViewController ()
- (NSString *)modelFriendlyName;
- (NSString *)modelNumberOfEntries;
- (NSString *)modelVersion;
- (NSString *)modelFilePath;
- (NSString *)modelWhenLastSaved;
- (NSString *)modelLastSavedBy;
- (NSString *)modelLastSavedOn;

- (UIBarButtonItem *)renameButton;
- (UIBarButtonItem *)doneRenameButton;
- (UIBarButtonItem *)cancelRenameButton;

- (BOOL)renaming;
- (void)setRenaming:(BOOL)isRenaming;
- (void)renameButtonPressed;
- (void)doneRenameButtonPressed;
- (void)cancelRenameButtonPressed;
- (void)modelNameChanged:(id)sender;
@end


// Class iPWSDatabaseDetailViewController
// Description
//  The DatabaseDetailViewController displays the header information about the given PasswordSafe model.  This includes
//  the number of entries in the file, the version of the file, the creation date and creation machine.  In addition,
//  the filename is displayed allowing for iTunes file sharing management.
@implementation iPWSDatabaseDetailViewController

// The following strucutres define the sections and fields of the table view
typedef struct CellMapStruct {
    NSString*   name;
    SEL         selector;
} CellMap;

static CellMap placeholderSectionFields[] = {};

static CellMap generalSectionFields[] = {
    { @"# entries", @selector(modelNumberOfEntries) },
    { @"Version", @selector(modelVersion) },
    { @"File", @selector(modelFilePath) }
};

static CellMap modificationDetailsSectionFields [] = {
    { @"Last saved", @selector(modelWhenLastSaved) },
    { @"Saved by", @selector(modelLastSavedBy) },
    { @"Saved on", @selector(modelLastSavedOn) }
};

static struct CellMapArray {
    CellMap *cells;
    size_t   size;
    BOOL     canEdit;
} CellMappings[] = {
    { placeholderSectionFields,         sizeof(placeholderSectionFields)/sizeof(placeholderSectionFields[0]), YES },
    { generalSectionFields,             sizeof(generalSectionFields)/sizeof(generalSectionFields[0]), NO },
    { modificationDetailsSectionFields, sizeof(modificationDetailsSectionFields)/sizeof(modificationDetailsSectionFields[0]), NO }
};

// ---- Public interface

// Initialization
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil
      databaseFactory:(iPWSDatabaseFactory *)theDatabaseFactory
                model:(iPWSDatabaseModel *)theModel {
    if (!theDatabaseFactory || !theModel) return nil;
    
    if (self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        databaseFactory           = [theDatabaseFactory retain];
        model                     = [theModel retain];
        self.navigationItem.title = @"Details";
        renaming = NO;
    }
    return self;
}

// Deallocation
- (void)dealloc {
    [databaseFactory release];
    [model release];
    [renameButton release];
    [doneRenameButton release];
    [cancelRenameButton release];
    [super dealloc];
}


// Interface handlers
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.renameButton;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = YES;    
}


// Table data source 
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (sizeof(CellMappings)/sizeof(CellMappings[0]));
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (0 == section) ? 1 : CellMappings[section].size;
}

// Return the cell for a given section and row
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = (0 == indexPath.section) ? @"iPWSDatabaseEditableStyle2TableCell" : @"StandardCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (nil == cell) {
        // Return the custom cell for section 0
        if (0 == indexPath.section) {
            [[NSBundle mainBundle] loadNibNamed:@"iPWSDatabaseDetailEditableStyle2TableCell" owner:self options:nil];
            cell = modelnameTableViewCell;
            modelnameTableViewCell = nil;
        } else {
            // Otherwise, return standard cell
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 
                                           reuseIdentifier:CellIdentifier] autorelease];
        }
    }

    if (0 == indexPath.section) {
        modelNameTextField      = (UITextField *)[cell viewWithTag:1];
        modelNameTextField.text = [self modelFriendlyName];
        [modelNameTextField addTarget:self 
                               action:@selector(modelNameChanged:) 
                     forControlEvents:UIControlEventEditingChanged];
        [modelNameTextField setEnabled:NO];
        
        UILabel *l = (UILabel *)[cell viewWithTag:2];
        l.text = @"Name";
    } else {
        CellMap *cm               = &(CellMappings[indexPath.section].cells[indexPath.row]);
        cell.textLabel.text       = cm->name;
        cell.detailTextLabel.text = [self performSelector:cm->selector];            
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

// Table view delgate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (0 != indexPath.section) {
        [modelNameTextField resignFirstResponder];
    }
}

// ---- Private interface 
- (NSString *)modelFriendlyName {
    return model.friendlyName;
}

- (NSString *)modelNumberOfEntries {
    return [NSString stringWithFormat:@"%d", [model.entries count]];
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
    return [NSString stringWithFormat:@"%s", model.headerRecord->m_lastsavedby.c_str()];
}

- (NSString *)modelLastSavedOn {
    return [NSString stringWithFormat:@"%s", model.headerRecord->m_lastsavedon.c_str()];
}


// ---- Navigation buttons
- (UIBarButtonItem *)renameButton {
    if (!renameButton) {
        renameButton = [[UIBarButtonItem alloc] initWithTitle:@"Rename"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(renameButtonPressed)];
    }
    return renameButton;
}

- (UIBarButtonItem *)doneRenameButton {
    if (!doneRenameButton) {
        doneRenameButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                            style:UIBarButtonItemStyleDone
                                                           target:self
                                                           action:@selector(doneRenameButtonPressed)];
    }
    return doneRenameButton;
}

- (UIBarButtonItem *)cancelRenameButton {
    if (!cancelRenameButton) {
        cancelRenameButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(cancelRenameButtonPressed)];
    }
    return cancelRenameButton;
}

// ---- Handle renaming modes
- (BOOL)renaming {
    return renaming;
}

- (void)setRenaming:(BOOL)isRenaming {
    renaming = isRenaming;
    if (renaming) {
        [modelNameTextField setEnabled:YES];
        [modelNameTextField becomeFirstResponder];
        self.navigationItem.leftBarButtonItem  = self.cancelRenameButton;
        self.navigationItem.rightBarButtonItem = self.doneRenameButton;        
    } else {
        [modelNameTextField resignFirstResponder];
        [modelNameTextField setEnabled:NO];
        modelNameTextField.text = [self modelFriendlyName];
        self.navigationItem.leftBarButtonItem  = nil;
        self.navigationItem.rightBarButtonItem = self.renameButton;        
    }
}

- (void) renameButtonPressed {
    self.renaming = YES;
}

- (void)doneRenameButtonPressed {
    NSString *origName = model.friendlyName;
    NSString *newName = modelNameTextField.text;
    
    if (![origName isEqualToString:newName]) {
        NSError *errorMsg;
        if (![databaseFactory renameDatabaseNamed:origName toNewName:newName errorMsg:&errorMsg]) {
            UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Rename failed"
                                                        message:[errorMsg localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
            [v show];
            [v release];
        }
    }
    self.renaming = NO;
}

- (void)cancelRenameButtonPressed {
    self.renaming = NO;
}

- (void)modelNameChanged:(id)sender {
    if (self.renaming) {
        [self.navigationItem.rightBarButtonItem setEnabled: (0 != [modelNameTextField.text length])];
    }
}

@end

