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
#import "iPWSMacros.h"
#import "NSString+CppStringAdditions.h"

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDatabaseModel ()
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

// ---- PWS library interfacing
- (PWSfile *)pwsFileHandle;
- (void)setPwsFileHandle:(PWSfile *)handle;

// ---- Change management
- (void)notifyChangeWithEntry:(iPWSDatabaseEntryModel *)entry;
- (void)entryChanged:(NSNotification *)notification;
- (void)watchEntryForNotifications:(iPWSDatabaseEntryModel *)entry;
- (void)stopWatchingEntryForNotifications:(iPWSDatabaseEntryModel *)entry;
@end

//------------------------------------------------------------------------------------
// Class constants

NSString* iPWSDatabaseModelChangedNotification     = @"iPWSDatabaseModelChangedNotification";
NSString* iPWSDatabaseModelChangedEntryUserInfoKey = @"iPWSDatabaseModelChangedEntryUserInfoKey";

// Maps PWSfile::VERSION constants to a string
static NSDictionary *iPWSDatabaseModelVersionMap =
[[[NSDictionary alloc] initWithObjectsAndKeys:
  @"1.7", [[[NSNumber alloc] initWithInt: PWSfile::V17] retain],
  @"2.0", [[[NSNumber alloc] initWithInt: PWSfile::V20] retain],
  @"3.0", [[[NSNumber alloc] initWithInt: PWSfile::V30] retain],
  @"4.0", [[[NSNumber alloc] initWithInt: PWSfile::V40] retain],
  @"3.0", [[[NSNumber alloc] initWithInt: PWSfile::VCURRENT] retain],
  @"New file", [[[NSNumber alloc] initWithInt: PWSfile::NEWFILE] retain],
  @"Unknown", [[[NSNumber alloc] initWithInt: PWSfile::UNKNOWN_VERSION] retain],
  nil] retain];

// Maps PWSfile::Status codes to error strings
static NSDictionary *iPWSDatabaseModelErrorCodesMap = 
[[[NSDictionary alloc] initWithObjectsAndKeys:
  @"Failed to initialize the database model", [[[NSNumber alloc] initWithInt: PWSfile::FAILURE] retain],
  @"Failed to open the database", [[[NSNumber alloc] initWithInt: PWSfile::CANT_OPEN_FILE] retain],
  @"The version of the database is not supported",[[[NSNumber alloc] initWithInt: PWSfile::UNSUPPORTED_VERSION] retain],
  @"The version of the database is not correct", [[[NSNumber alloc] initWithInt: PWSfile::WRONG_VERSION] retain],
  @"The provided file is not a PasswordSafe v3 file", [[[NSNumber alloc] initWithInt: PWSfile::NOT_PWS3_FILE] retain],
  @"The passphrase is incorrect", [[[NSNumber alloc] initWithInt: PWSfile::WRONG_PASSWORD] retain],
  @"The database file is corrupt (bad digest)", [[[NSNumber alloc] initWithInt: PWSfile::BAD_DIGEST] retain],
  @"The database file is corrupt (end of file)", [[[NSNumber alloc] initWithInt: PWSfile::END_OF_FILE] retain],
  nil] retain];


//------------------------------------------------------------------------------------
// Model implementation
@implementation iPWSDatabaseModel

@synthesize entries;
@synthesize fileName;
@synthesize friendlyName;


//------------------------------------------------------------------------------------
// Class methods
+ (NSString *)databaseVersionToString:(PWSfile::VERSION)version {
    return [iPWSDatabaseModelVersionMap objectForKey:[NSNumber numberWithInt:version]];
}

+ (id)databaseModelNamed:(NSString *)theFriendlyName 
               fileNamed:(NSString *)theFileName 
              passphrase:(NSString *)thePassphrase
                errorMsg:(NSError **)errorMsg {
    return [[[self alloc] initNamed:theFriendlyName
                         fileNamed:theFileName
                        passphrase:thePassphrase
                           errorMsg:errorMsg] autorelease];
}

//------------------------------------------------------------------------------------
// Instance methods

//------------------------------------------------------------------------------------
// Accessors
// Read the version of the model from the file (passphrase may be required)
- (PWSfile::VERSION) version {
    return PWSfile::ReadVersion([self.fileName getStringX], [self.passphrase getStringX]);
}

// Read the header from the model's file (passphrase required)
- (const PWSfileHeader *)headerRecord {
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
        self.passphrase = newPassphrase;
        [self notifyChangeWithEntry:nil];
        return [self syncToFile];
    }
    return YES;
}

// Fetch the last reported error
- (NSError *)lastError {
    return [[lastError copy] autorelease];
}

// Set the most recent error
- (void)setLastError:(NSError *)error {
    if (lastError != error) {
        [lastError release];
        lastError = [error retain];
    }
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
    
    // Sanity checks on the name, file name, and passphrase
    if (!theFriendlyName || ![theFriendlyName length] || !theFileName || ![theFileName length]) {
        SET_ERROR(errorMsg, [self errorForStatus:PWSfile::FAILURE]);
        return nil;
    }
    if (!thePassphrase || ![thePassphrase length]) {
        SET_ERROR(errorMsg, [self errorForStatus:PWSfile::WRONG_PASSWORD]);
        return nil;
    }
    
    // Initialize the instance by either creating a new file or opening an existing one
    if (self = [super init]) {
        entries           = [[NSMutableArray alloc] init];
        self.fileName     = theFileName;
        self.friendlyName = theFriendlyName;
        self.passphrase   = thePassphrase;
        
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:self.fileName];
        if (exists) {
            // The file exists, open it and read all of the entries
            if (![self openPWSfileForReading]) goto last_error;

            CItemData item;
            while (self.pwsFileHandle->ReadRecord(item) == PWSfile::SUCCESS) {
                iPWSDatabaseEntryModel *entry = [iPWSDatabaseEntryModel entryModelWithItemData:&item];
                [entries addObject:entry];
                [self watchEntryForNotifications:entry];
                item = CItemData(); // The C model does not clear all fields, so do so here
            }
        } else { 
            // The file will be newly created. 
            if (![self openPWSfileForWriting]) goto last_error;
        }
        
        [self closePWSfile];
    }
    if (!self) SET_ERROR(errorMsg, [self errorForStatus:PWSfile::FAILURE]);
    return self;
    
last_error:
    SET_ERROR(errorMsg, self.lastError);
    [self release];
    return nil;
}

// Deallocation
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.lastError     = nil;
    self.passphrase    = nil;
    self.pwsFileHandle = NULL;
    self.friendlyName  = nil;
    self.fileName      = nil;
    [entries release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Entry modifications (passphrase required)
- (BOOL)addDatabaseEntry:(iPWSDatabaseEntryModel *)entry {
    [entries addObject:entry];
    [self watchEntryForNotifications:entry];
    [self notifyChangeWithEntry:entry];
    return [self syncToFile];
}

- (BOOL)removeDatabaseEntry:(iPWSDatabaseEntryModel *)entry {
    [entries removeObjectIdenticalTo:entry];    
    [self stopWatchingEntryForNotifications:entry];
    [self notifyChangeWithEntry:entry];
    return [self syncToFile];
}

//------------------------------------------------------------------------------------
// Private interface


//------------------------------------------------------------------------------------
// Entry observer - called when the entry is changed
- (void)notifyChangeWithEntry:(iPWSDatabaseEntryModel *)entry {
    NSDictionary *userInfo = nil;
    if (entry) {
        userInfo = [NSDictionary dictionaryWithObject:entry forKey:iPWSDatabaseModelChangedEntryUserInfoKey];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:iPWSDatabaseModelChangedNotification
                                                        object:self
                                                      userInfo:userInfo];    
}

- (void)entryChanged:(NSNotification *)notification {
    [self notifyChangeWithEntry:notification.object];
    [self syncToFile]; 
}

- (void)watchEntryForNotifications:(iPWSDatabaseEntryModel *)entry {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(entryChanged:)
                                                 name:iPWSDatabaseEntryModelChangedNotification
                                               object:entry];
}

- (void)stopWatchingEntryForNotifications:(iPWSDatabaseEntryModel *)entry {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseEntryModelChangedNotification
                                                  object:entry];
}

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
    
    self.pwsFileHandle = PWSfile::MakePWSfile([self.fileName getStringX], [self.passphrase getStringX], v, mode, status, NULL, NULL);
    if ((NULL == self.pwsFileHandle) || (PWSfile::SUCCESS != status)) {
        self.lastError = [self errorForStatus:status];
        return NO;
    }
    
    // Open the file
    if (PWSfile::SUCCESS != self.pwsFileHandle->Open([self.passphrase getStringX])) {
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

@end
