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


#import "iPWSDatabaseAddViewController.h"

//------------------------------------------------------------------------------------
// Private interface declaration 
@interface iPWSDatabaseAddViewController ()
- (UIBarButtonItem *)cancelButton;
- (UIBarButtonItem *)doneButton;

- (void)cancelButtonPressed;
- (void)doneButtonPressed;

- (void)updateDoneButton;
- (void)updatePassphraseMismatchWarning;

- (BOOL)isPassphraseValid;

- (NSString *)createUniqueFilenameWithPrefix: (NSString *)prefix;
@end

//------------------------------------------------------------------------------------
// Class: iPWSDatabaseAddViewController
// Description:
//  Represents a view and controller for creating a new PasswordSafe database
@implementation iPWSDatabaseAddViewController

//------------------------------------------------------------------------------------
// Public interface

//------------------------------------------------------------------------------------
// Initialization
- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil 
      databaseFactory:(iPWSDatabaseFactory *)theDatabaseFactory {
    
    if (nil == theDatabaseFactory) return nil;
    
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        databaseFactory           = [theDatabaseFactory retain];
        self.navigationItem.title = @"Add safe";
    }
    return self;
}

// Deallocation
- (void)dealloc {
    [databaseFactory release];
    [cancelButton release];
    [doneButton release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Instance methods
- (void)viewDidLoad {   
    [super viewDidLoad];
	
	scrollView.contentSize = [[UIScreen mainScreen] applicationFrame].size;

    self.navigationItem.leftBarButtonItem = [self cancelButton];
    self.navigationItem.rightBarButtonItem = [self doneButton];
    [self updateDoneButton];
    [self updatePassphraseMismatchWarning];
    [friendlyName becomeFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.toolbarHidden = YES;    
}

//------------------------------------------------------------------------------------
// Interface builder events
- (IBAction)friendlyNameChanged:(id)sender {
    [self updateDoneButton];
}

- (IBAction)passphraseChanged:(id)sender {
    [self updateDoneButton];
    [self updatePassphraseMismatchWarning];
}

- (IBAction)confirmPassphraseChanged:(id)sender {
    [self updateDoneButton];
    [self updatePassphraseMismatchWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [friendlyName resignFirstResponder];
    [passphrase resignFirstResponder];
    [confirmPassphrase resignFirstResponder];    
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
// Methods to enable/disable the done button and password phrase mismatch text based on current text fields
- (BOOL)isPassphraseValid {
    return ([[passphrase text] length] && [[passphrase text] isEqualToString:[confirmPassphrase text]]);
}

- (void)updateDoneButton {
    // Enable the done button only if the friendly name is not empty and contains at least one non-whitepsace character
    NSString *noWhitespace = [friendlyName.text stringByTrimmingCharactersInSet: 
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    BOOL isFormValid = [noWhitespace length] && [self isPassphraseValid];
    [doneButton setEnabled:isFormValid];
}

- (void)updatePassphraseMismatchWarning {
    BOOL isConfirmValid = (![[confirmPassphrase text] length]) || [self isPassphraseValid];
    [confirmPassphraseMismatchLabel setHidden:isConfirmValid];
}

//------------------------------------------------------------------------------------
// Handle cancelation and completion
- (void)cancelButtonPressed {
    [self.navigationController popViewControllerAnimated:NO];
}

- (void)doneButtonPressed {
    [self.navigationController popViewControllerAnimated:NO];

    NSError *errorMsg;
    if (![databaseFactory addDatabaseNamed:friendlyName.text
                             withFileNamed:[self createUniqueFilenameWithPrefix:friendlyName.text]
                                passphrase:passphrase.text
                                  errorMsg:&errorMsg]) {
        UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Add safe failed"
                                                    message:[errorMsg localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"Dismiss"
                                          otherButtonTitles:nil];
        [v show];
        [v release];
    }
}
     
//------------------------------------------------------------------------------------
// Construct a unique filename within the documents directory
- (NSString *)createUniqueFilenameWithPrefix: (NSString *)prefix {
    // First strip all of the non-alpha/digit characters from the prefix
    NSMutableString *cleanPrefix = [NSMutableString string];
    int prefixLen = [prefix length];
    for (int i = 0; i < prefixLen; ++i) {
        char c = [prefix characterAtIndex:i];
        if (isalnum(c)) {
            [cleanPrefix appendFormat:@"%c", c];
        }
    }
    
    // Find the documents directories
    NSString *docDir = databaseFactory.documentsDirectory;
    
    // Check whether the filename is already unique
    NSString *tmpPath = [NSString stringWithFormat:@"%@/%@.psafe3", docDir, cleanPrefix];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
        // Construct a temporary filename
        char *tmp = tempnam([docDir UTF8String], [cleanPrefix UTF8String]);
        tmpPath = [NSString stringWithFormat:@"%s", tmp];
        free(tmp);
    }
    return [tmpPath lastPathComponent];
}


@end
