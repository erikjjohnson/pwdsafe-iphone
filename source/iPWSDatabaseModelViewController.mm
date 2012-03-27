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
#import "iPWSDatabaseDetailViewController.h"
#import "iPWSDatabaseFactory.h"
#import "iPWSDropBoxPreferences.h"
#import "iPasswordSafeAppDelegate.h"
#import "iPWSDropBoxSynchronizer.h"

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDatabaseModelViewController ()
- (void)startDropBoxSynchronizer;
- (void)stopDropBoxSyncrhonizer;

- (void)initSectionDataWithModel:(iPWSDatabaseModel *)model;
- (void)addEntryToSection:(iPWSDatabaseEntryModel *)entry;
- (void)removeEntryFromSectionAtIndexPath:(NSIndexPath *)indexPath;
- (void)removeEntryFromSection:(iPWSDatabaseEntryModel *)entry;
- (iPWSDatabaseEntryModel *)entryAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)allEntriesInSection:(NSInteger)section;

- (int)letterToSection:(char)c;
- (char)sectionToLetter:(int)i;
- (NSString *)sectionToString:(int)i;

- (void)updateSearchResults;
- (ActivityOverlayViewController *)searchOverlayController;

- (UIBarButtonItem *)addButton;
- (UIBarButtonItem *)synchronizeButton;
- (UIBarButtonItem *)searchDoneButton;
- (UIBarButtonItem *)detailsButton;

- (void)addButtonPressed;
- (void)synchronizeButtonPressed;
- (void)searchDoneButtonPressed;
- (void)detailsButtonPressed;
- (void)updateEditButton;

- (void)modelChangedNotification:(NSNotification *)notification;
- (void)entryAddedNotification:(NSNotification *)notification;
@end


//------------------------------------------------------------------------------------
// Class: iPWSDatabaseModelViewController
// Description:
//  Represents a simple table view controller displaying the entries of a database model.  When an entry is
//  selected push an EntryViewController to display that entry
@implementation iPWSDatabaseModelViewController

//------------------------------------------------------------------------------------
// Initializer
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil model:(iPWSDatabaseModel *)theModel {
    if (!theModel) return nil;
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        model                     = [theModel retain];
        self.navigationItem.title = @"Safe entries";

        // Watch for changes in the model
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(modelChangedNotification:)
                                                     name:iPWSDatabaseModelChangedNotification 
                                                   object:model];

        // Map the model to the section data
        [self initSectionDataWithModel:model];
        
        // Add the toolbar
        iPasswordSafeAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        self.toolbarItems = [NSArray arrayWithObjects: self.addButton, 
                                                       appDelegate.flexibleSpaceButton,
                                                       self.synchronizeButton,
                                                       appDelegate.lockAllDatabasesButton, 
                                                       self.detailsButton,
                                                       nil];
        // Initialize the search results
        searchResults = [[NSMutableArray alloc] init];
        isSearching   = showSearchResults = NO;
        [self updateSearchResults];
     }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopDropBoxSyncrhonizer];
    [addButton release];
    [synchronizeButton release];
    [searchDoneButton release];
    [model release];
    [sectionData release];
    [searchResults release];
	[searchOverlayController release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// View loading and unloading
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;

    // Setup the search bar
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    
}

- (void)viewDidUnload {
    if ([[iPWSDropBoxPreferences sharedPreferences] isModelSynchronizedWithDropBox:model]) {
        [self stopDropBoxSyncrhonizer];
    }    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = NO;  
    self.synchronizeButton.enabled = [[iPWSDropBoxPreferences sharedPreferences] isModelSynchronizedWithDropBox:model];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[iPWSDropBoxPreferences sharedPreferences] isModelSynchronizedWithDropBox:model]) {
        [self startDropBoxSynchronizer];
    } else {
        [self stopDropBoxSyncrhonizer];
    }
}

//------------------------------------------------------------------------------------
// Dropbox handling
- (void)startDropBoxSynchronizer {
    if (!dropBoxSynchronizer) {
        dropBoxSynchronizer = [[iPWSDropBoxSynchronizer alloc] initWithModel:model];
    }
}

- (void)stopDropBoxSyncrhonizer {
    if (dropBoxSynchronizer) {
        [dropBoxSynchronizer cancelSynchronization];
        [dropBoxSynchronizer release];
        dropBoxSynchronizer = nil;
    }
}

- (void)synchronizeButtonPressed {
    [self startDropBoxSynchronizer];
    [self.navigationController pushViewController:dropBoxSynchronizer animated:YES];    
}

//------------------------------------------------------------------------------------
// Accessors
- (UIBarButtonItem *)addButton {
    // Lazy initialize an add button
    if (!addButton) {
        addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                  target:self
                                                                  action:@selector(addButtonPressed)];        
    }
    return addButton;
}

- (UIBarButtonItem *)synchronizeButton {
    // Lazy initialize an synchronize button
    if (!synchronizeButton) {
        synchronizeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                          target:self
                                                                          action:@selector(synchronizeButtonPressed)];        
    }
    return synchronizeButton;
}

- (UIBarButtonItem *)searchDoneButton {
    // Lazy initialize a search done button
    if (!searchDoneButton) {
        searchDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                         target:self
                                                                         action:@selector(searchDoneButtonPressed)];        
    }
    return searchDoneButton;    
}

- (UIBarButtonItem *)detailsButton {
    // Lazy initialize a page curl button
    if (!detailsButton) {
        detailsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPageCurl
                                                                      target:self
                                                                      action:@selector(detailsButtonPressed)];
    }
    return detailsButton;
}


//------------------------------------------------------------------------------------
// Table data source
#pragma mark -
#pragma mark Table view data source

// Number of sections (26 + 1) - the alphabet plus a catch-all
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return showSearchResults ? 1 : [sectionData count];
}

// Number of entries per section
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self updateEditButton];
    return [[self allEntriesInSection:section] count];
}

// Section headings - letters A - Z, or # for the catch-all
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (showSearchResults) return nil;
    if (![[self allEntriesInSection:section] count]) return nil;
    return [self sectionToString:section];
}

// Index (bar on the right side) with the letters A - Z and #
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    static NSMutableArray *indexTitles = nil;
    if (nil == indexTitles) {
        indexTitles = [[NSMutableArray alloc] init];
        [indexTitles addObject:UITableViewIndexSearch];
        int numSections = [sectionData count];
        for (int s = 0; s < numSections; ++s) {
            [indexTitles addObject:[self sectionToString:s]];
        }
    }
    return isSearching ? nil : indexTitles;
}

// When the index bar is pressed, return the right section to scroll to
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (index == 0) {
        [tableView setContentOffset:CGPointZero animated:NO];
        return NSNotFound;
    }
    return index - 1;
}

// Cell data for a particular section and row
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] 
                autorelease];
    }

    iPWSDatabaseEntryModel *entry = [self entryAtIndexPath:indexPath];
    cell.textLabel.text = entry.title;
    
    return cell;
}

//------------------------------------------------------------------------------------
// Searching
// Add a grey overlay to show the original list and allow for cancelling
- (ActivityOverlayViewController *)searchOverlayController {
	if (!searchOverlayController) {
		searchOverlayController = 
			[[ActivityOverlayViewController alloc] initWithNibName:@"ActivityOverlayViewController" 
                                                            bundle:[NSBundle mainBundle]
                                                            target:self
                                                          selector:@selector(searchDoneButtonPressed)];
		
	}	
    CGFloat yaxis  = self.navigationController.navigationBar.frame.size.height;
    CGFloat width  = self.view.frame.size.width;
    CGFloat height = self.view.frame.size.height;
    
    CGRect frame = CGRectMake(0, yaxis, width, height);
    searchOverlayController.view.frame = frame;

    [searchOverlayController hideActivityIndicator];
    return searchOverlayController;
}

// Don't allow selecting of items until the search has some specific results
- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
    isSearching = YES;
    self.navigationItem.rightBarButtonItem = [self searchDoneButton];
    [self updateSearchResults];
    [self.tableView reloadData];
}

// Cancel the search
- (void)searchDoneButtonPressed {
    isSearching    = showSearchResults = NO;
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
	[[self searchOverlayController].view removeFromSuperview];
    [self updateSearchResults];
}

// When the search text changes, clear the old results and update new ones
- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
    [self updateSearchResults];
    [self.tableView reloadData];
}

// When the user clicks the "enter" (or search) button on the keypad
-(void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    [self updateSearchResults];
}

// Fill in the search data array with the list of entries matching the current search parameters
- (void)updateSearchResults {    
    NSString                 *searchText = searchBar.text;

	// Show search results only if there is search text
	showSearchResults = isSearching && (searchText != nil) && ([searchText length] > 0);
    isSelectable      = !isSearching || showSearchResults; 
    self.tableView.scrollEnabled = isSelectable;

    [searchResults removeAllObjects];
    
    if (!isSearching) return;
    
	// If there are no search results and we are searching, use the overlay view
	ActivityOverlayViewController *overlay = [self searchOverlayController];
	if (!showSearchResults && isSearching) {
		[self.tableView insertSubview:overlay.view aboveSubview:self.parentViewController.view];
		return;
	}
	
	// If we are searching, remove the overlay and update the search data
	if (isSearching) {
		[overlay.view removeFromSuperview];    
		for (iPWSDatabaseEntryModel *entry in model.entries)
		{
			NSString *title = entry.title;
			NSRange r = [title rangeOfString:searchText options:NSCaseInsensitiveSearch];
			if (NSNotFound != r.location) {
				[searchResults addObject:entry];
			}
		}
	}
}


//------------------------------------------------------------------------------------
// Orientations
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}


//------------------------------------------------------------------------------------
// Editing and selection
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return !isSearching;
}

// Disable the edit button if there are no entries
- (void)updateEditButton {
    NSInteger count = [model.entries count];
    if (!count) {
        self.editing = NO;
    }    
    [self.editButtonItem setEnabled:(0 != count)];
}

// Disallow selections while initially searching
- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return isSelectable ? indexPath : nil;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [model removeDatabaseEntry:[self entryAtIndexPath:indexPath]];
        [self removeEntryFromSectionAtIndexPath:indexPath];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                         withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView reloadData];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Not supported
    }   
}


//------------------------------------------------------------------------------------
// Add button handling

// Adding an entry consists of pushing an entry view controller in edit mode.  When the view controller
// is done editing it will call iPWSDatabaseEntryViewController:didFinishEditingEntry:
- (void)addButtonPressed {
    CItemData data;
    iPWSDatabaseEntryModel *entry = [[[iPWSDatabaseEntryModel alloc] initWithItemData:&data] autorelease];
    iPWSDatabaseEntryViewController *vc = 
        [[iPWSDatabaseEntryViewController alloc] initWithNibName:@"iPWSDatabaseEntryViewController"
                                                          bundle:nil
                                                           entry:entry];
    
    // Listen for when editing is complete
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(entryAddedNotification:) 
                                                 name:iPWSDatabaseEntryViewControllerEditingCompleteNotification
                                               object:vc];
    
    vc.editing = YES;
    [self.navigationController pushViewController:vc animated:YES];
    [vc release];
}

// Called after Add entry is complete.  Add the entry to the model and remove ourselves as a listener on the
// entry since it is now managed by the model
- (void)entryAddedNotification:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseEntryViewControllerEditingCompleteNotification
                                                  object:notification.object];
    iPWSDatabaseEntryModel *entry = 
        [notification.userInfo objectForKey:iPWSDatabaseEntryViewControllerEntryUserInfoKey];
    [model addDatabaseEntry:entry];
}

- (void)modelChangedNotification:(NSNotification *)notification {
    iPWSDatabaseEntryModel *entry = [notification.userInfo objectForKey:iPWSDatabaseModelChangedEntryUserInfoKey];
    if (!entry) return;
    [self removeEntryFromSection:entry];
    [self addEntryToSection:entry];
    [self updateSearchResults];
    [self.tableView reloadData];
}


//------------------------------------------------------------------------------------
// Model details
- (void)detailsButtonPressed {
    iPWSDatabaseDetailViewController *vc = [[iPWSDatabaseDetailViewController alloc] 
                                            initWithNibName:@"iPWSDatabaseDetailViewController"
                                            bundle:nil
                                            model:model];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration: 1];
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight 
                           forView:self.navigationController.view 
                             cache:YES];
    [self.navigationController pushViewController:vc animated:NO];
    [UIView commitAnimations];
    [vc release];
}

//------------------------------------------------------------------------------------
// Table view delegate
#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    iPWSDatabaseEntryViewController *vc = 
        [[iPWSDatabaseEntryViewController alloc] initWithNibName:@"iPWSDatabaseEntryViewController"
                                                          bundle:nil
                                                           entry:[self entryAtIndexPath:indexPath]];
    [self.navigationController pushViewController:vc animated:YES];
    [vc release];
}


//------------------------------------------------------------------------------------
// Private interface - section handling
- (void)initSectionDataWithModel:(iPWSDatabaseModel *)m {
    // Create an array for the 26 letters plus one "catchall".  Each array
    // maps to another array which holds model entries 
    
    // First create the empty array of arrays
    int numSections = 'Z' - 'A' + 2;
    sectionData = [[NSMutableArray alloc] initWithCapacity:numSections];
    for (int s = 0; s < numSections; ++s) {
        [sectionData insertObject:[NSMutableArray arrayWithCapacity:0] atIndex:s];
    }
    
    // Now iterate the model entries and add them
    int numEntries = [m.entries count];
    for (int e = 0; e < numEntries; ++e) {
        [self addEntryToSection:[m.entries objectAtIndex:e]];
    }
}

- (void)addEntryToSection:(iPWSDatabaseEntryModel *)entry {
    // Find the index based on the first letter of the entry.  If this isn't
    // A-Z, then default to the last catchall section
    int firstLetter = toupper([entry.title characterAtIndex:0]);
    int idx = [self letterToSection:firstLetter];
    
    // Add the entry and sort the section array
    NSMutableArray *a = [sectionData objectAtIndex:idx];
    [a addObject:entry];
    NSSortDescriptor *sorter = [NSSortDescriptor sortDescriptorWithKey:@"title" 
                                                             ascending:YES];
    [a sortUsingDescriptors:[NSArray arrayWithObject:sorter]];
}

- (void)removeEntryFromSectionAtIndexPath:(NSIndexPath *)indexPath {
    [[sectionData objectAtIndex:indexPath.section] removeObjectAtIndex:indexPath.row];
}

- (void)removeEntryFromSection:(iPWSDatabaseEntryModel *)entry {
    int numSections = [sectionData count];
    for (int s = 0; s < numSections; ++s) {
        [[sectionData objectAtIndex:s] removeObjectIdenticalTo:entry];
    }
}

- (iPWSDatabaseEntryModel *)entryAtIndexPath:(NSIndexPath *)indexPath {
	return showSearchResults ? [searchResults objectAtIndex:indexPath.row] :
							   [[sectionData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
}

- (NSArray *)allEntriesInSection:(NSInteger)section {
	return showSearchResults ? searchResults : [sectionData objectAtIndex:section];
}


- (int)letterToSection:(char)c {
    int idx = [sectionData count] - 1;
    if (('A' <= c) && ('Z' >= c)) {
        idx = c - 'A';
    }
    return idx;
}

- (char)sectionToLetter:(int)i {
    if (i == ([sectionData count] - 1)) return '#';
    return i + 'A';
}

- (NSString *)sectionToString:(int)i {
    return [NSString stringWithFormat:@"%c", [self sectionToLetter:i]];
}

@end

