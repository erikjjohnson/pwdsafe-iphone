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

//------------------------------------------------------------------------------------
// Class: iPWSDatabaseModel
// Description:
//  Each iPWSDatabaseModel represents a single, password-validated PasswordSafe database.  The underlying file that
//  stores the database is opened, completely re-written, and closed each time a change is made to the database
//  due to the API exposed by the underlying C model, but that is not reflected in this class.
//

#import "iPWSDatabaseModel.h"
#import "corelib/PWScore.h"

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDatabaseModel ()
// ---- File management
+ (PWScore *)pwsCore;
- (BOOL)openPWSfileForReading;
- (BOOL)openPWSfileForWriting;
- (BOOL)openPWSfileUsingMode:(PWSfile::RWmode)mode;
- (void)closePWSfile;
- (BOOL)syncToFile;

// ---- Error reporting
- (NSError *)errorForStatus:(int)status;
- (NSError *)lastError;
- (void)setLastError:(NSError *)error;

- (PWSfile *)pwsFileHandle;
- (void)setPwsFileHandle:(PWSfile *)handle;
@end

//------------------------------------------------------------------------------------
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


//------------------------------------------------------------------------------------
// Class variables

//------------------------------------------------------------------------------------
// Model implementation
@implementation iPWSDatabaseModel

@synthesize entries;
@synthesize fileName;
@synthesize friendlyName;
@synthesize delegate;

//------------------------------------------------------------------------------------
// Class methods
+ (NSString *)databaseVersionToString:(PWSfile::VERSION)version {
    return [iPWSDatabaseModelVersionMap objectForKey:[NSNumber numberWithInt:version]];
}

+ (BOOL)isPasswordSafeFile:(NSString *)filePath {
    return (PWSfile::UNKNOWN_VERSION != PWSfile::ReadVersion([filePath UTF8String])); 
}

+ (PWScore *)pwsCore {
    static PWScore* core = NULL;
    static BOOL sessionKeyInitialized = NO;

    @synchronized(self) {
        if (!sessionKeyInitialized) {
            try {
                core = new PWScore();
            } catch(...) {
                // Once, and only once, the PasswordSafe engine needs to be established
                if (!sessionKeyInitialized) {
                    CItemData::SetSessionKey();
                }
            }
            sessionKeyInitialized = YES;
        }
    }
    return core;
}
   
//------------------------------------------------------------------------------------
// Instance methdos

//------------------------------------------------------------------------------------
// Accessors
// Read the version of the model from the file (no passphrase required)
- (PWSfile::VERSION) version {
    return PWSfile::ReadVersion([fileName UTF8String]);
}

// Read the header from the model's file (passphrase required)
- (const PWSfile::HeaderRecord *)headerRecord {
    return &headerRecord;
}

// Read and set the passphrase
- (NSString *)passphrase {
    return passphrase;
}

// Setting the passphrase (private accessor only)
- (void)setPassphrase:(NSString *)thePassphrase {
    if (passphrase != thePassphrase) {
        [passphrase release];
        passphrase = [thePassphrase copy];
    }
}

// Changing the passphrase (public)
- (BOOL)changePassphrase:(NSString *)newPassphrase {
    if (passphrase != newPassphrase) {
        try {
            PWScore *core = [[self class] pwsCore];
            if (NULL == core) return NO;
            core->SetCurFile([fileName UTF8String]);
            core->SetPassKey([newPassphrase UTF8String]);
            core->WriteCurFile();
        } catch (...) {
            return NO;
        }
        self.passphrase = newPassphrase;
    }
    return YES;
}

// Setting the internal file handle
- (PWSfile *)pwsFileHandle {
    return pwsFileHandle;
}

- (void)setPwsFileHandle:(PWSfile *)handle {
    if (pwsFileHandle != handle) {
        if (NULL != pwsFileHandle) {
            [self closePWSfile];
            delete pwsFileHandle;
        }
        pwsFileHandle = handle;
    }
}

//------------------------------------------------------------------------------------
// Initialization - if the file does not exist, a new database is created.
- (id)initNamed:(NSString *)theFriendlyName 
      fileNamed:(NSString *)theFileName 
     passphrase:(NSString *)thePassphrase
       errorMsg:(NSError **)errorMsg {
    
    // Ensure the password safe library is initialized
    [[self class] pwsCore];
    
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
        entries         = [[NSMutableArray alloc] init];
        fileName        = [theFileName retain];
        friendlyName    = [theFriendlyName retain];
        self.passphrase = thePassphrase;
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fileName];
        if (exists) {
            // The file exists, open it and read all of the entries
            if (![self openPWSfileForReading]) {
                if (errorMsg && *errorMsg) *errorMsg = [[self.lastError copy] autorelease];
                [self release];
                return nil;
            }

            CItemData item;
            while (self.pwsFileHandle->ReadRecord(item) == PWSfile::SUCCESS) {
                [entries addObject:[[[iPWSDatabaseEntryModel alloc] initWithData:&item delegate:self] autorelease]];
                item = CItemData(); // The C model does not clear all fields, so do so here
            }
        } else { 
            // The file will be newly created. 
            if (![self openPWSfileForWriting]) {
                if (errorMsg && *errorMsg) *errorMsg = [[self.lastError copy] autorelease];
                [self release];
                return nil;
            }
        }
        
        [self closePWSfile];
    }
    if (!self && errorMsg && *errorMsg) *errorMsg = [self errorForStatus:PWSfile::FAILURE];
    return self;
}

// Deallocation
- (void)dealloc {
    self.lastError  = nil;
    self.passphrase = nil;
    self.pwsFileHandle = NULL;
    [friendlyName release];
    [fileName release];
    [entries release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Entry modifications (passphrase required)
- (BOOL)addDatabaseEntry:(iPWSDatabaseEntryModel *)entry {
    [entries addObject:entry];
    entry.delegate = self;
    return [self syncToFile];
}

- (BOOL)removeDatabaseEntry:(iPWSDatabaseEntryModel *)entry {
    [entries removeObjectIdenticalTo:entry];    
    return [self syncToFile];
}

//------------------------------------------------------------------------------------
// Entry observer - called when the entry is changed
- (void)iPWSDatabaseEntryModelChanged:(iPWSDatabaseEntryModel *)entryModel {
    [delegate iPWSDatabaseModel:self didChangeEntry:entryModel];
    [self syncToFile]; 
}


//------------------------------------------------------------------------------------
// Private interface

//------------------------------------------------------------------------------------
// File management

// Open a safe file in read mode
- (BOOL)openPWSfileForReading {
    return [self openPWSfileUsingMode:PWSfile::Read];
}

// Open a safe file in write mode
- (BOOL)openPWSfileForWriting {
    return [self openPWSfileUsingMode:PWSfile::Write];
}

// Generic routine for opening a file
- (BOOL)openPWSfileUsingMode:(PWSfile::RWmode)mode {
    int status;
    
    // Read the version.  If the file does not exist and the mode is write, then set the value to VCURRENT since this
    // is a new file
    PWSfile::VERSION v = self.version;
    if ((PWSfile::UNKNOWN_VERSION == v) && (PWSfile::Write == mode)) {
        v = PWSfile::VCURRENT;
    }
    
    self.pwsFileHandle = PWSfile::MakePWSfile([fileName UTF8String], v, mode, status, NULL, NULL);
    if ((NULL == self.pwsFileHandle) || (PWSfile::SUCCESS != status)) {
        self.lastError = [self errorForStatus:status];
        return NO;
    }
    
    // Open the file
    if (PWSfile::SUCCESS != self.pwsFileHandle->Open([self.passphrase UTF8String])) {
        self.lastError = [self errorForStatus:PWSfile::WRONG_PASSWORD];
        return NO;
    }
    
    // Read in and cache the header
    headerRecord = self.pwsFileHandle->GetHeader();
    return YES;
}

// Close a safe file
- (void)closePWSfile {
    self.pwsFileHandle->Close();
}

// Synchronize the current in-memory model with the underlying file
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
            success &= [entry writeToPWSfile:self.pwsFileHandle];
        }
        
        // Read in and cache the header
        headerRecord = self.pwsFileHandle->GetHeader();
        
        [self closePWSfile];
    }
    
    // Remove the backup if the write out was successful
    if (success && duplicateFile) {
        [[NSFileManager defaultManager] removeItemAtPath:duplicateFile error:NULL];
    }
    return success;
}


//------------------------------------------------------------------------------------
// Error handling

// Construct an error object for the given status code
- (NSError *)errorForStatus:(int)status {
    NSString *errorStr = [iPWSDatabaseModelErrorCodesMap objectForKey:[NSNumber numberWithInt:status]];
    NSDictionary *info = [NSDictionary dictionaryWithObject:errorStr forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"iPWS" code:status userInfo:info];
}

// Fetch the last reported error
- (NSError *)lastError {
    return lastError;
}

// Set the most recent error
- (void)setLastError:(NSError *)error {
    if (lastError != error) {
        [lastError release];
        lastError = [error retain];
    }
}

@end
