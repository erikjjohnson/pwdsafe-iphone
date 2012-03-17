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

#import "iPWSDatabaseModelMerger.h"
#import "iPWSDatabaseFactory.h"

//------------------------------------------------------------------------------------
// Private implementation
@interface iPWSDatabaseModelMerger ()
@property (retain) iPWSDatabaseModel *primaryModel;
@property (retain) iPWSDatabaseModel *secondaryModel;

- (NSMutableSet *)entryTitleSetFromModel:(iPWSDatabaseModel *)model;

- (UIBarButtonItem *)doneButton;
- (UIBarButtonItem *)cancelButton;

- (void)doneButtonPressed;
- (void)cancelButtonPressed;
@end


//------------------------------------------------------------------------------------
// Class iPWSDatabaseModelMerger
// Description
//  The merger accepts to database models, computes their differences and displays them
//  in a three section table:
//    1 - section for the entries only in the first model
//    2 - section for the entries only in the second model
//    3 - section for the common entries
//
//  Each entry contains a switch, defaulted to on, that can be used to decide which entries
//  will remain in the final model
@implementation iPWSDatabaseModelMerger

//------------------------------------------------------------------------------------
// Accessors
@synthesize primaryModel;
@synthesize secondaryModel;
@synthesize delegate;

//------------------------------------------------------------------------------------
// Initializer
- (id)initWithPrimaryModel:(iPWSDatabaseModel *)thePrimaryModel secondaryModel:(iPWSDatabaseModel *)theSecondaryModel {
    if (!thePrimaryModel || !theSecondaryModel) return nil;
    if (self = [super initWithNibName:@"iPWSDatabaseModelMerger" bundle:nil]) {
        self.primaryModel   = thePrimaryModel;
        self.secondaryModel = theSecondaryModel;
        self.navigationItem.title = @"Merge";

        // Compute the differences
        NSMutableSet *firstSet  = [self entryTitleSetFromModel:self.primaryModel];
        NSMutableSet *secondSet = [self entryTitleSetFromModel:self.secondaryModel];
        NSMutableSet *commonSet = [NSMutableSet setWithSet:firstSet];
        [commonSet intersectSet:secondSet];
        [firstSet  minusSet:commonSet];
        [secondSet minusSet:commonSet];
        
        onlyInFirst  = [[NSMutableArray arrayWithArray:[firstSet  allObjects]] retain];
        onlyInSecond = [[NSMutableArray arrayWithArray:[secondSet allObjects]] retain];
        commonInBoth = [[NSMutableArray arrayWithArray:[commonSet allObjects]] retain];
    }
    return self;
}
                        

- (void)dealloc {
    self.delegate       = nil;
    self.primaryModel   = nil;
    self.secondaryModel = nil;
    [onlyInFirst release];
    [onlyInSecond release];
    [commonInBoth release];
    [super dealloc];
}

// View loading and unloading
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem  = self.doneButton;
    self.navigationItem.leftBarButtonItem   = self.cancelButton;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.toolbarHidden = YES;
    self.editing = YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ((interfaceOrientation == UIInterfaceOrientationPortrait) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}


//------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3; // first, second, common
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return [onlyInFirst  count];
        case 1: return [onlyInSecond count];
        case 2: return [commonInBoth count];
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return [NSString stringWithFormat:@"Entries only in %@", self.primaryModel.friendlyName];
        case 1: return [NSString stringWithFormat:@"Entries only in %@", self.secondaryModel.friendlyName];
        case 2: return @"Entries common to both safes (by title).  Keep the local version.";
        default: return @"";
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return (2 != indexPath.section);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (0 == indexPath.section) {
            [onlyInFirst removeObjectAtIndex:indexPath.row];
        }
        if (1 == indexPath.section) {
            [onlyInSecond removeObjectAtIndex:indexPath.row];
        }
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                         withRowAnimation:UITableViewRowAnimationFade];
    }   
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] 
                autorelease];
    }
    
    NSString *label;
    switch (indexPath.section) {
        case 0: label = [onlyInFirst objectAtIndex:indexPath.row]; break;
        case 1: label = [onlyInSecond objectAtIndex:indexPath.row]; break;
        case 2: label = [commonInBoth objectAtIndex:indexPath.row]; break;
        default: label = nil;
    }
    cell.textLabel.text = label;
    return cell;
}


//------------------------------------------------------------------------------------
// Private interface

- (NSSet *)entryTitleSetFromModel:(iPWSDatabaseModel *)model {
    NSMutableSet *set = [NSMutableSet set];
    [model.entries enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL * stop) {
        [set addObject:[entry title]];
    }];
    return set;
}

//------------------------------------------------------------------------------------
// Navigation buttons
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

- (void)doneButtonPressed {
    [self.navigationController popViewControllerAnimated:NO];

    NSError *errorMsg;
    iPWSDatabaseFactory *databaseFactory = [iPWSDatabaseFactory sharedDatabaseFactory];
    NSString *temporary  = [databaseFactory createUniqueFilenameWithPrefix:@"merged"];
    NSString *mergedFile = [databaseFactory.documentsDirectory stringByAppendingPathComponent:temporary];
    iPWSDatabaseModel *mergedModel = [iPWSDatabaseModel databaseModelNamed:@"Merged"
                                                                 fileNamed:mergedFile
                                                                passphrase:self.primaryModel.passphrase
                                                                  errorMsg:&errorMsg];
    if (!mergedModel) {
        if ([self.delegate respondsToSelector:@selector(modelMerger:failedWithError:)]) {
            [self.delegate modelMerger:self failedWithError:errorMsg];
            return;
        }
    }
    
    // Copy the common items and primary remaining items
    [self.primaryModel.entries enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL * stop) {
        if ([commonInBoth containsObject:[entry title]] || [onlyInFirst containsObject:[entry title]]) {
            [mergedModel addDatabaseEntry:entry];
        }
    }];
    
    // Copy the items in the secondary model
    [self.secondaryModel.entries enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL * stop) {
        if ([onlyInSecond containsObject:[entry title]]) {
            [mergedModel addDatabaseEntry:entry];
        }
    }];
    
    if ([self.delegate respondsToSelector:@selector(modelMerger:mergedPrimaryModel:secondaryModel:intoModel:)]) {
        [self.delegate modelMerger:self 
                mergedPrimaryModel:self.primaryModel 
                    secondaryModel:self.secondaryModel
                         intoModel:mergedModel];
    }
}

- (void)cancelButtonPressed {
    [self.navigationController popViewControllerAnimated:NO];
    if ([self.delegate respondsToSelector:@selector(modelMergerWasCancelled:)]) {
        [self.delegate modelMergerWasCancelled:self];
    }
}

@end

