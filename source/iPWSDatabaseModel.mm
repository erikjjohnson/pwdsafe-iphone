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


// Class: iPWSDatabaseModel
// Description:
//  Each iPWSDatabaseModel represents a single, password-validated PasswordSafe database.  The underlying file that
//  stores the database is opened, completely re-written, and closed each time a change is made to the database
//  due to the API exposed by the underlying C model, but that is not reflected in this class.
//

#import "iPWSDatabaseModel.h"

// ----- Private interface
@interface iPWSDatabaseModel ()
// ---- Entry management
- (void)sortEntries;

// ---- File management
- (BOOL)openPWSfileForReading;
- (BOOL)openPWSfileForWriting;
- (BOOL)openPWSfileUsingMode:(PWSfile::RWmode)mode;
- (void)closePWSfile;
- (BOOL)syncToFile;

// ---- Error reporting
- (NSError *)errorForStatus:(int)status;
- (NSError *)lastError;
- (void)setLastError:(NSError *)error;
@end


// Class constants

// Maps PWSfile::VERSION constants to a string
static NSDictionary *iPWSDatabaseModelVersionMap =
[[[NSDictionary alloc] initWithObjectsAndKeys:
  @"1.7", [[[NSNumber alloc] initWithInt: PWSfile::V17] retain],
  @"2.0", [[[NSNumber alloc] initWithInt: PWSfile::V20] retain],
  @"3.0", [[[NSNumber alloc] initWithInt: PWSfile::V30] retain],
  @"3.0", [[[NSNumber alloc] initWithInt: PWSfile::VCURRENT] retain],
  @"New file", [[[NSNumber alloc] initWithInt: PWSfile::NEWFILE] retain],
  @"Unknown", [[[NSNumber alloc] initWithInt: PWSfile::UNKNOWN_VERSION] retain],
  nil] retain];

// Maps PWSfile::Status codes to error strings
static NSDictionary *iPWSDatabaseModelErrorCodesMap = 
[[[NSDictionary alloc] initWithObjectsAndKeys:
  @"Failed to initialize the database model", [[[NSNumber alloc] initWithInt: PWSfile::FAILURE] retain],
  @"Failed to open the database", [[[NSNumber alloc] initWithInt: PWSfile::CANT_OPEN_FILE] retain],
  @"The version of the database is not supported", [[[NSNumber alloc] initWithInt: PWSfile::UNSUPPORTED_VERSION] retain],
  @"The version of the database is not correct", [[[NSNumber alloc] initWithInt: PWSfile::WRONG_VERSION] retain],
  @"The provided file is not a PasswordSafe v3 file", [[[NSNumber alloc] initWithInt: PWSfile::NOT_PWS3_FILE] retain],
  @"The passphrase is incorrect", [[[NSNumber alloc] initWithInt: PWSfile::WRONG_PASSWORD] retain],
  @"The database file is corrupt (bad digest)", [[[NSNumber alloc] initWithInt: PWSfile::BAD_DIGEST] retain],
  @"The database file is corrupt (end of file)", [[[NSNumber alloc] initWithInt: PWSfile::END_OF_FILE] retain],
  nil] retain];

// ---- Class variables

// The PWS C-library requires the session key to be initialized exactly once, this variable tracks that this is
// done the once, when the first model is created
static BOOL sessionKeyInitialized = NO;


// ----- Model implementation
@implementation iPWSDatabaseModel

@synthesize entries;
@synthesize fileName;
@synthesize friendlyName;
@synthesize delegate;

// ---- Class methods
+ (NSString *)databaseVersionToString:(PWSfile::VERSION)version {
    return [iPWSDatabaseModelVersionMap objectForKey:[NSNumber numberWithInt:version]];
}

+ (BOOL)isPasswordSafeFile:(NSString *)filePath {
    return (PWSfile::UNKNOWN_VERSION != PWSfile::ReadVersion([filePath UTF8String])); 
}
        
// ---- Instance methdos

// Accessors
// Read the version of the model from the file (no passphrase required)
- (PWSfile::VERSION) version {
    return PWSfile::ReadVersion([fileName UTF8String]);
}

// Read the header from the model's file (passphrase required)
- (const PWSfile::HeaderRecord *)headerRecord {
    return &headerRecord;
}

// Initialization - if the file does not exist, a new database is created.
- (id)initNamed:(NSString *)theFriendlyName 
      fileNamed:(NSString *)theFileName 
     passphrase:(NSString *)thePassphrase
       errorMsg:(NSError **)errorMsg {
    
    // Once, and only once, the PasswordSafe engine needs to be established
    if (!sessionKeyInitialized) {
        CItemData::SetSessionKey();
        sessionKeyInitialized = YES;
    }
    
    // Sanity checks on the name, file name, and passphrase
    if (!theFriendlyName || ![theFriendlyName length] || !theFileName || ![theFileName length]) {
        if (errorMsg && *errorMsg) *errorMsg = [self errorForStatus:PWSfile::FAILURE];
        return nil;
    }
    if (!thePassphrase || ![thePassphrase length]) {
        if (errorMsg && *errorMsg) *errorMsg = [self errorForStatus:PWSfile::WRONG_PASSWORD];
        return nil;
    }
    
    // Initialize the instance by either creating a new file or opening an existing one
    if (self = [super init]) {
        entries       = [[NSMutableArray alloc] init];
        fileName      = [theFileName retain];
        friendlyName  = [theFriendlyName retain];
        passphrase    = [thePassphrase retain];
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fileName];
        if (exists) {
            // The file exists, open it and read all of the entries
            if (![self openPWSfileForReading]) {
                if (errorMsg && *errorMsg) *errorMsg = [self.lastError copy];
                [self release];
                return nil;
            }

            CItemData item;
            while (pwsFileHandle->ReadRecord(item) == PWSfile::SUCCESS) {
                [entries addObject:[[iPWSDatabaseEntryModel alloc] initWithData:&item delegate:self]];
                item = CItemData(); // The C model does not clear all fields, so do so here
            }
            [self sortEntries];
        } else { 
            // The file will be newly created. 
            if (![self openPWSfileForWriting]) {
                if (errorMsg && *errorMsg) *errorMsg = [self.lastError copy];
                [self release];
                return nil;
            }
        }
        
        [self closePWSfile];
    }
    if (!self && errorMsg && *errorMsg) *errorMsg = [self errorForStatus:PWSfile::FAILURE];
    return self;
}

- (void)dealloc {
    self.lastError = nil;
    [passphrase release];
    [friendlyName release];
    [fileName release];
    [entries release];
    [super dealloc];
}

// Entry modifications (passphrase required)
- (BOOL)addDatabaseEntry:(iPWSDatabaseEntryModel *)entry {
    [entries addObject:entry];
    [self sortEntries];
    return [self syncToFile];
}

- (BOOL)removeDatabaseEntryAtIndex:(NSInteger)idx {
    [entries removeObjectAtIndex:idx];    
    return [self syncToFile];
}

// Entry observer - called when the entry is changed
- (void)iPWSDatabaseEntryModelChanged:(iPWSDatabaseEntryModel *)entryModel {
    [delegate iPWSDatabaseModel:self didChangeEntry:entryModel];
    [self syncToFile]; 
}


// ---- Private interface

// Entry management
- (void)sortEntries {    
    // If the preferences specify, keep the entries sorted
    BOOL sortEntries = [[NSUserDefaults standardUserDefaults] boolForKey:@"sort_entries"];
    if (sortEntries) {
        NSSortDescriptor *sorter = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
        [entries sortUsingDescriptors:[NSArray arrayWithObject:sorter]];
    }
}


// File management
- (BOOL)openPWSfileForReading {
    return [self openPWSfileUsingMode:PWSfile::Read];
}

- (BOOL)openPWSfileForWriting {
    return [self openPWSfileUsingMode:PWSfile::Write];
}

- (BOOL)openPWSfileUsingMode:(PWSfile::RWmode)mode {
    int status;
    
    // Read the version.  If the file does not exist and the mode is write, then set the value to VCURRENT since this
    // is a new file
    PWSfile::VERSION v = self.version;
    if ((PWSfile::UNKNOWN_VERSION == v) && (PWSfile::Write == mode)) {
        v = PWSfile::VCURRENT;
    }
    
    pwsFileHandle = PWSfile::MakePWSfile([fileName UTF8String], v, mode, status, NULL, NULL);
    if ((NULL == pwsFileHandle) || (PWSfile::SUCCESS != status)) {
        self.lastError = [self errorForStatus:status];
        return NO;
    }
    
    // Open the file
    if (PWSfile::SUCCESS != pwsFileHandle->Open([passphrase UTF8String])) {
        self.lastError = [self errorForStatus:PWSfile::WRONG_PASSWORD];
        return NO;
    }
    
    // Read in and cache the header
    headerRecord = pwsFileHandle->GetHeader();
    return YES;
}


- (void)closePWSfile {
    pwsFileHandle->Close();
}

- (BOOL)syncToFile {
    BOOL success = NO;
    
    // Try to duplicate the current file, any failures are ignored
    NSString *duplicateFile = nil;
    NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    if ([docDirs count]) {
        NSString *docDir = [docDirs objectAtIndex:0];
        char *tmp = tempnam([docDir UTF8String], [[self.fileName lastPathComponent] UTF8String]);
        duplicateFile = [NSString stringWithFormat:@"%s", tmp];
        free(tmp);
        
        if (![[NSFileManager defaultManager] copyItemAtPath:self.fileName toPath:duplicateFile error:NULL]) {
            duplicateFile = nil;
        }
    }

    // Write out each record
    if ([self openPWSfileForWriting]) {
        success = YES;
        NSEnumerator *etr = [entries objectEnumerator];
        iPWSDatabaseEntryModel *entry;
        while (entry = (iPWSDatabaseEntryModel *)[etr nextObject]) {
            success &= [entry writeToPWSfile:pwsFileHandle];
        }
        
        // Read in and cache the header
        headerRecord = pwsFileHandle->GetHeader();
        
        [self closePWSfile];
    }
    
    // Remove the backup if the write out was successful
    if (success && duplicateFile) {
        [[NSFileManager defaultManager] removeItemAtPath:duplicateFile error:NULL];
    }
    return success;
}


// Error handling
- (NSError *)errorForStatus:(int)status {
    NSString *errorStr = [iPWSDatabaseModelErrorCodesMap objectForKey:[NSNumber numberWithInt:status]];
    NSDictionary *info = [NSDictionary dictionaryWithObject:errorStr forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"iPWS" code:status userInfo:info];
}

- (NSError *)lastError {
    return lastError;
}

- (void)setLastError:(NSError *)error {
    [lastError release];
    lastError = [error retain];
}

@end
