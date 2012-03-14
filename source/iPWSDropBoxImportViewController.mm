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

#import "iPWSDropBoxImportViewController.h"
#import "iPWSDropBoxAuthenticator.h"
#import "iPWSDatabaseFactory.h"
#import "DismissAlertView.h"

//------------------------------------------------------------------------------------
// Private interface declaration
@interface iPWSDropBoxImportViewController ()
@property (retain) DBRestClient *dbClient;
@property (retain) NSString     *loadingFilename;

- (UIBarButtonItem *)cancelButton;
- (UIBarButtonItem *)doneButton;

- (void)cancelButtonPressed;
- (void)doneButtonPressed;
- (void)updateDoneButton;

- (void)startSpinner;
- (void)stopSpinner;
- (ActivityOverlayViewController *)spinningOverlayViewController;

- (void)popView;
@end

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxImportViewController
// Description:
//  Represents a view and controller for importing a PasswordSafe database from an existing file
@implementation iPWSDropBoxImportViewController

@synthesize dbClient;
@synthesize loadingFilename;

//------------------------------------------------------------------------------------
// Public interface

// Initialization
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.navigationItem.title = @"Import DropBox safe";
        psafeFiles                = [[NSMutableArray array] retain];
        dropBoxRevisions          = [[NSMutableDictionary dictionary] retain];
    }
    
    return self;
}

// Deallocation
- (void)dealloc {
    self.dbClient.delegate = nil;
    self.dbClient          = nil;
    self.loadingFilename   = nil;
    [iPWSDropBoxAuthenticator sharedDropBoxAuthenticator].delegate = nil;
    [spinningOverlayViewController release];
    [cancelButton release];
    [doneButton release];
    [psafeFiles release];
    [dropBoxRevisions release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Interface handling
- (void)viewDidLoad {
    [super viewDidLoad];
  
	scrollView.contentSize = [[UIScreen mainScreen] applicationFrame].size;

    self.navigationItem.leftBarButtonItem  = [self cancelButton];
    self.navigationItem.rightBarButtonItem = [self doneButton];
    [self updateDoneButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = YES;    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startSpinner];
    [[iPWSDropBoxAuthenticator sharedDropBoxAuthenticator] authenticateWithView:self.view
                                                                       delegate:self];
}

- (void)popView {
    if (self.loadingFilename) {
        [self.dbClient cancelFileLoad:self.loadingFilename];
        self.loadingFilename = nil;
    }
    [self.navigationController popViewControllerAnimated:NO];
}

- (IBAction)friendlyNameChanged:(id)sender {
    [self updateDoneButton];
}
 
- (IBAction)passphraseChanged:(id)sender {
    [self updateDoneButton];
}


//------------------------------------------------------------------------------------
// Authentication callbacks
- (void)dropBoxAuthenticatorSucceeded:(iPWSDropBoxAuthenticator *)authenticator {
    self.dbClient = [[[DBRestClient alloc] initWithSession:[DBSession sharedSession]] autorelease];
    self.dbClient.delegate = self;
    [self.dbClient loadMetadata:@"/" withHash:nil];
}

- (void)dropBoxAuthenticatorFailed:(iPWSDropBoxAuthenticator *)authenticator {
    [self stopSpinner];
    [self popView];
}

//------------------------------------------------------------------------------------
// DBClient delegate callbacks
- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
    [psafeFiles removeAllObjects];
    [dropBoxRevisions removeAllObjects];
    for (DBMetadata* child in metadata.contents) {
        if (!child.isDirectory && 
            ![[iPWSDatabaseFactory sharedDatabaseFactory] doesFileNameExist:child.filename] &&
            child.rev) {
            [psafeFiles addObject:child.filename];
            [dropBoxRevisions setObject:child.rev forKey:child.filename];
        }
    }
    [self stopSpinner];
    
    if ([psafeFiles count]) {
        [importFilePicker reloadAllComponents];
    } else {
        ShowDismissAlertView(@"No safes to import", 
                             @"No unmapped safes were found. Files on DropBox in Apps/PasswordSafes-iPhone with the"
                              " same name as existing files will not be imported.  Instead, locally import the file"
                              " and synchronize it with DropBox");
        [self popView];
    }
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    ShowDismissAlertView(@"DropBox unexpected failure", @"Go ahead and try again if you feel lucky.");
    [self popView];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
    ShowDismissAlertView(@"DropBox file listing failed", @"Go ahead and try again if you feel lucky.");
    [self popView];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath {
    NSError *errorMsg;
    self.loadingFilename = nil;
    [self stopSpinner];
    iPWSDatabaseFactory *databaseFactory = [iPWSDatabaseFactory sharedDatabaseFactory];
    NSString *fileName                   = [psafeFiles objectAtIndex:selectedImportFileIdx];
    if (![databaseFactory addDatabaseNamed:friendlyName.text
                             withFileNamed:fileName
                                passphrase:passphrase.text 
                                  errorMsg:&errorMsg]) {
        [[NSFileManager defaultManager] removeItemAtPath:[databaseFactory databasePathForFileName:fileName]
                                                   error:NULL];
        passphrase.text = @"";
        [passphrase becomeFirstResponder];
        ShowDismissAlertView(@"Import failed", [errorMsg localizedDescription]);
    } else {
        [databaseFactory markModelNameForDropBox:friendlyName.text];
        [databaseFactory setDropBoxRev:[dropBoxRevisions objectForKey:fileName] forModelName:friendlyName.text];
        [self popView];
    }
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    ShowDismissAlertView(@"DropBox load file failed", @"Failed to copy the safe");
    [self stopSpinner];
}

//------------------------------------------------------------------------------------
// Spinner view while work is being done
// Add a grey overlay to show the original list
- (ActivityOverlayViewController *)spinningOverlayViewController {
	if (!spinningOverlayViewController) {
		spinningOverlayViewController = 
        [[ActivityOverlayViewController alloc] initWithNibName:@"ActivityOverlayViewController" 
                                                        bundle:[NSBundle mainBundle]
                                                        target:nil
                                                      selector:nil];
		
	}	
    CGFloat width  = self.view.frame.size.width;
    CGFloat height = self.view.frame.size.height;
    
    CGRect frame = CGRectMake(0, 0, width, height);
    spinningOverlayViewController.view.frame = frame;
    [spinningOverlayViewController showActivityIndicator];
    return spinningOverlayViewController;
}

- (void)startSpinner {
    [self.view addSubview:[self spinningOverlayViewController].view];
    [doneButton setEnabled:NO];
}

- (void)stopSpinner {
    [[self spinningOverlayViewController].view removeFromSuperview];
}


//------------------------------------------------------------------------------------
// UIPickerViewDataSource and UIPickerViewDelegate
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [psafeFiles count];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    selectedImportFileIdx = row;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [psafeFiles objectAtIndex:row];
}

//------------------------------------------------------------------------------------
// Private interface 

// Lazily construct two buttons
- (UIBarButtonItem *)cancelButton {
    if (!cancelButton) {
        cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(cancelButtonPressed)];
    }
    return cancelButton;
}

- (UIBarButtonItem *)doneButton {
    if (!doneButton) {
        doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(doneButtonPressed)];
    }
    return doneButton;
}

//------------------------------------------------------------------------------------
// Event handling to enable/disable the done button
- (void)updateDoneButton {
    BOOL isFormValid = ([friendlyName.text length] != 0) && ([passphrase.text length] != 0);
    [doneButton setEnabled:isFormValid];
}

- (void)cancelButtonPressed {
    [self popView];
}

- (void)doneButtonPressed {
    [friendlyName resignFirstResponder];
    [passphrase resignFirstResponder];
    
    [self startSpinner];
    NSString *selectedFilename = [psafeFiles objectAtIndex:selectedImportFileIdx];
    self.loadingFilename       = [NSString stringWithFormat:@"/%@", selectedFilename];
    NSString *destFilename     = [[iPWSDatabaseFactory sharedDatabaseFactory].documentsDirectory 
                                  stringByAppendingPathComponent:selectedFilename];
    NSLog(@"Loading %@ into %@", self.loadingFilename, destFilename);
    [self.dbClient loadFile:[NSString stringWithFormat:self.loadingFilename] intoPath:destFilename];
}

@end
