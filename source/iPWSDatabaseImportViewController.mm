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

#import "iPWSDatabaseImportViewController.h"
#import "iPWSDatabaseFactory.h"
#import "iPWSDatabaseModel.h"
#import "DismissAlertView.h"

//------------------------------------------------------------------------------------
// Private interface declaration
@interface iPWSDatabaseImportViewController ()
- (UIBarButtonItem *)cancelButton;
- (UIBarButtonItem *)doneButton;

- (void)cancelButtonPressed;
- (void)doneButtonPressed;

- (void)updateDoneButton;
@end

//------------------------------------------------------------------------------------
// Class: iPWSDatabaseImportViewController
// Description:
//  Represents a view and controller for importing a PasswordSafe database from an existing file
@implementation iPWSDatabaseImportViewController

//------------------------------------------------------------------------------------
// Public interface

// Initialization
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.navigationItem.title = @"Import safe";
        
        // Fill in the list of known passwordsafe file names
        iPWSDatabaseFactory *databaseFactory = [iPWSDatabaseFactory sharedDatabaseFactory];
        selectedImportFileIdx = 0;
        psafeFiles            = [[NSMutableArray array] retain];
        NSString *docDir      = databaseFactory.documentsDirectory;
        for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docDir error:NULL]) {
            if (![databaseFactory isFileNameMapped:file]) {
                [psafeFiles addObject: file];
            }
        }

        // If there are no files to import, display a warning and return nil
        if (![psafeFiles count]) {
            ShowDismissAlertView(@"No safes to import", 
                                 @"No unmapped safes were found.  Use iTunes file sharing to import an existing PasswordSafe file.");
            return nil;
        }      
        
    }
    
    return self;
}

// Deallocation
- (void)dealloc {
    [cancelButton release];
    [doneButton release];
    [psafeFiles release];
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

- (IBAction)friendlyNameChanged:(id)sender {
    [self updateDoneButton];
}
 
- (IBAction)passphraseChanged:(id)sender {
    [self updateDoneButton];
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
    [self.navigationController popViewControllerAnimated:NO];
}

- (void)doneButtonPressed {
    [friendlyName resignFirstResponder];
    [passphrase resignFirstResponder];

    NSError *errorMsg;
    iPWSDatabaseFactory *databaseFactory = [iPWSDatabaseFactory sharedDatabaseFactory];
    if (![databaseFactory addDatabaseNamed:friendlyName.text
                             withFileNamed:[psafeFiles objectAtIndex:selectedImportFileIdx]
                                passphrase:passphrase.text 
                                  errorMsg:&errorMsg]) {
        passphrase.text = @"";
        [passphrase becomeFirstResponder];
        ShowDismissAlertView(@"Import failed", [errorMsg localizedDescription]);
    } else {
        [self.navigationController popViewControllerAnimated:NO];
    }
}

@end
