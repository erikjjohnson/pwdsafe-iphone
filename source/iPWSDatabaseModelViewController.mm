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

#import "iPWSDatabaseModelViewController.h"
#import "iPWSDatabaseEntryViewController.h"
#import "iPasswordSafeAppDelegate.h"

// ---- Private interface
@interface iPWSDatabaseModelViewController ()
- (UIBarButtonItem *)addButton;

- (void)addButtonPressed;
- (void)updateEditButton;
@end


// Class: iPWSDatabaseModelViewController
// Description:
//  Represents a simple table view controller displaying the entries of a database model.  When an entry is
//  selected push an EntryViewController to display that entry
@implementation iPWSDatabaseModelViewController

// ---- Instance methods

// ---- Accessors
- (UIBarButtonItem *)addButton {
    // Lazy initialize an add button
    if (!addButton) {
        addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                  target:self
                                                                  action:@selector(addButtonPressed)];        
    }
    return addButton;
}

// Initializer
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil model:(iPWSDatabaseModel *)theModel {
    if (!theModel) return nil;
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        model                     = [theModel retain];
        model.delegate            = self;
        self.navigationItem.title = @"Vault entries";

        // Add the toolbar
        iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        self.toolbarItems = [NSArray arrayWithObjects: self.addButton, 
                                                       appDelegate.flexibleSpaceButton,
                                                       appDelegate.lockAllDatabasesButton, 
                                                       nil];
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = NO;  
}

// Table data source
#pragma mark -
#pragma mark Table view data source

// Disable the edit button if there are no entries
- (void)updateEditButton {
    NSInteger count = [model.entries count];
    if (!count) {
        self.editing = NO;
    }    
    [self.editButtonItem setEnabled:(0 != count)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self updateEditButton];
    return [model.entries count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] 
                autorelease];
    }

    iPWSDatabaseEntryModel *entry = [model.entries objectAtIndex:indexPath.row];
    cell.textLabel.text = entry.title;
    
    return cell;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [model removeDatabaseEntryAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Not supported
    }   
}

// ----- Button handling

// Adding an entry consists of pushing an entry view controller in edit mode.  When the view controller
// is done editing it will call iPWSDatabaseEntryViewController:didFinishEditingEntry:
- (void)addButtonPressed {
    CItemData data;
    iPWSDatabaseEntryModel *entry = [[iPWSDatabaseEntryModel alloc] initWithData:&data delegate:nil];
    iPWSDatabaseEntryViewController *vc = 
        [[iPWSDatabaseEntryViewController alloc] initWithNibName:@"iPWSDatabaseEntryViewController"
                                                          bundle:nil
                                                           entry:entry
                                                        delegate:self];
    vc.editing = YES;
    [self.navigationController pushViewController:vc animated:YES];
    [vc release];
}

// Called after Add entry is complete.  Add the entry to the model and remove ourselves as a listener on the
// entry since it is now managed by the model
- (void)iPWSDatabaseEntryViewController:(iPWSDatabaseEntryViewController *)entryViewController 
                  didFinishEditingEntry:(iPWSDatabaseEntryModel *)entry {
    [model addDatabaseEntry:entry];
    entryViewController.delegate = nil;
    [self.tableView reloadData];
}

- (void)iPWSDatabaseModel:(iPWSDatabaseModel *)model didChangeEntry:(iPWSDatabaseEntryModel *)entry {
    [self.tableView reloadData];
}


// Table view delegate
#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    iPWSDatabaseEntryViewController *vc = 
        [[iPWSDatabaseEntryViewController alloc] initWithNibName:@"iPWSDatabaseEntryViewController"
                                                          bundle:nil
                                                           entry:[model.entries objectAtIndex:indexPath.row]
                                                        delegate:nil];
    [self.navigationController pushViewController:vc animated:YES];
    [vc release];
}

// Memory management
#pragma mark -
#pragma mark Memory management

- (void)dealloc {
    [addButton release];
    [model release];
    [super dealloc];
}


@end

