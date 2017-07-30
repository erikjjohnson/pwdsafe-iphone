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


#import "iPWSDatabaseFactory.h"
#import "corelib/ItemData.h"
#import "DismissAlertView.h"
#import "iPWSMacros.h"

//------------------------------------------------------------------------------------
// Class: iPWSDatabaseFactory
// Description:
//  The iPWSDatabaseFactory is represents the list of known PasswordSafe databases.
//  Each database is represented by a friendly name, which maps to a database
//  model, a file path, and Dropbox synchronization preference.  The mapping from friendlyName to file name 
//  are maintained in the application's
//  preferences.  The mapping from friendlyName to database instance is only maintained in memory. Hence, it
//  is possible that a friendlyName exists, but the call to obtain the database for that friendly name
//  (databaseNamed:errorMsg:) fails.  In this case, one must call addDatabaseNamed:withFileNamed:passphrase:errorMsg:
//  to instantiate the database instance.
//

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDatabaseFactory () 
- (void)synchronizeUserDefaults;
- (NSError *)errorWithStr:(NSString *)errorStr;

// ---- Change management
- (void)notifyModelAdded:(NSString *)friendlyName;
- (void)notifyModelRenamedFrom:(NSString *)oldName to:(NSString *)newName;
- (void)notifyModelRemoved:(NSString *)friendlyName;
- (void)notifyModelOpened:(NSString *)friendlyName;
- (void)notifyModelClosed:(NSString *)friendlyName;
- (void)notifyWithName:(NSString *)name forModelName:(NSString *)friendlyName;
- (void)notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo;
- (NSDictionary *)notificationInfoForModelName:(NSString *)friendlyName;
@end


//------------------------------------------------------------------------------------
// Class variables

// Notification constants
NSString* iPWSDatabaseFactoryModelAddedNotification   = @"iPWSDatabaseFactoryModelAddedNotification";
NSString* iPWSDatabaseFactoryModelRenamedNotification = @"iPWSDatabaseFactoryModelRenamedNotification";
NSString* iPWSDatabaseFactoryModelRemovedNotification = @"iPWSDatabaseFactoryModelRemovedNotification";

NSString* iPWSDatabaseFactoryModelOpenedNotification  = @"iPWSDatabaseFactoryModelOpenedNotification";
NSString* iPWSDatabaseFactoryModelClosedNotification  = @"iPWSDatabaseFactoryModelClosedNotification";


NSString* iPWSDatabaseFactoryModelNameUserInfoKey     = @"iPWSDatabaseFactoryModelNameUserInfoKey";
NSString* iPWSDatabaseFactoryOldModelNameUserInfoKey  = @"iPWSDatabaseFactoryOldModelNameUserInfoKey";
NSString* iPWSDatabaseFactoryNewModelNameUserInfoKey  = @"iPWSDatabaseFactoryNewModelNameUserInfoKey";

// The keys placed in the UserDefaults
static NSString *kiPWSDatabaseFactoryUserDefaults    = @"kiPWSDatabaseFactoryUserDefaults";
//static NSString *kiPWSDatabaseDropBoxUserDefaults    = @"kiPWSDatabaseDropBoxUserDefaults";
//static NSString *kiPWSDatabaseDropBoxRevUserDefaults = @"kiPWSDatabaseDropBoxRevUserDefaults";

static NSString *PWSDatabaseFactoryMissingSafesMessage = 
@"The location of the safes is missing.  Try backing up safes with iTunes file sharing then reinstall the application.";


//------------------------------------------------------------------------------------
// Factory implementation
@implementation iPWSDatabaseFactory

@synthesize documentsDirectory;

// Get the singleton
+ (id)sharedDatabaseFactory {
    static iPWSDatabaseFactory *sharedDatabaseFactory = nil;
    @synchronized(self) {
        if (nil == sharedDatabaseFactory) {
            sharedDatabaseFactory = [[iPWSDatabaseFactory alloc] init];
        }
    }
    return sharedDatabaseFactory;
}

// Canonical initializer
- (id)init {
    if (self = [super init]) {        
        friendlyNameToFilename = [[NSMutableDictionary dictionary] retain];
        openDatabaseModels     = [[NSMutableDictionary dictionary] retain];

        // Load the  UserDefaults (preferences) file for the application        
        // In previous versions of the code, the databaseFileNames were complete file system paths.
        // It is suspected that this was a problem during upgrade and so now only relative fileNames
        // are maintained.  Fix up the databaseFileNames if they appear to be full path names
        NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] 
                                  dictionaryForKey:kiPWSDatabaseFactoryUserDefaults];
        [defaults enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSString *fileName = (NSString *)obj;
            if ([fileName isAbsolutePath]) {
                fileName = [fileName lastPathComponent];
            }
            [friendlyNameToFilename setObject:fileName forKey:key];
        }];
        
        [self synchronizeUserDefaults];
        
        // Find the documents directories and use the first one
        NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
        if (![docDirs count]) {
            ShowDismissAlertView(@"Unable to find safes", PWSDatabaseFactoryMissingSafesMessage);
            documentsDirectory = @"";
        } else {
            documentsDirectory = [[docDirs objectAtIndex:0] retain];
        }
     }
    return self;
}

// Destructor
- (void) dealloc {
    [documentsDirectory release];
    [friendlyNameToFilename release];
    [openDatabaseModels release];
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Enumerating the friendly names
- (NSArray *)friendlyNames {
    return [friendlyNameToFilename allKeys];
}

// Helper methdos to check the existance of a friendlyName or mapped file name
- (BOOL)doesFriendlyNameExist:(NSString *)friendlyName {
    return [self.friendlyNames containsObject:friendlyName];
}

// Determine if the given filename already is already in our preferences file (i.e., already in the list of safes)
- (BOOL)isFileNameMapped:(NSString *)fileName {
    NSEnumerator *etr = [friendlyNameToFilename objectEnumerator];
    NSString *name;
    while (name = [etr nextObject]) {
        if ([name isEqualToString:fileName]) return YES;
    }
    return NO;
}

// Determine if the given filename is in the Documents folder
- (BOOL)doesFileNameExist:(NSString *)fileName {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self databasePathForFileName:fileName]];
}

- (NSString *)databasePathForFileName:(NSString *)fileName {
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

// The full path, including filename, for the given friendly name
- (NSString *)databasePathForName:(NSString *)friendlyName {
    return [self databasePathForFileName:[friendlyNameToFilename objectForKey:friendlyName]];
}

//------------------------------------------------------------------------------------
// Construct a unique filename within the documents directory
- (NSString *)createUniqueFilenameWithPrefix: (NSString *)prefix {
    // First strip all of the non-alpha/digit characters from the prefix
    NSMutableString *cleanPrefix = [NSMutableString string];
    unsigned long prefixLen = [prefix length];
    for (int i = 0; i < prefixLen; ++i) {
        char c = [prefix characterAtIndex:i];
        if (isalnum(c)) {
            [cleanPrefix appendFormat:@"%c", c];
        }
    }
    
    // Find the documents directories
    NSString *docDir = self.documentsDirectory;
    
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


//------------------------------------------------------------------------------------
// Accessing the database models

// Return an already opened database model.  If the database model is not opened, nil is returned
- (iPWSDatabaseModel *)getOpenedDatabaseModelNamed:(NSString *)friendlyName errorMsg:(NSError **)errorMsg {
    iPWSDatabaseModel *model = [openDatabaseModels objectForKey:friendlyName];
    if (!model) {
        SET_ERROR(errorMsg,
                  ([self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" not opened", friendlyName]]));
    }
    return model;
}

// Open a database model already in our list of known databases
- (iPWSDatabaseModel *)openDatabaseModelNamed:(NSString *)friendlyName 
                                   passphrase:(NSString *)passphrase 
                                     errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if (![self doesFriendlyNameExist:friendlyName]) {
        SET_ERROR(errorMsg, 
                  ([self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" does not exist", friendlyName]]));
        return nil;
    }
    
    // Construct a new model
    iPWSDatabaseModel *model = 
    [iPWSDatabaseModel databaseModelNamed:friendlyName
                                fileNamed:[self databasePathForName:friendlyName]
                               passphrase:passphrase
                                 errorMsg:errorMsg];
    if (!model) {
        return nil;
    }
    
    // Add the model the map of opened models
    [openDatabaseModels setObject:model forKey:friendlyName];    
    [self notifyModelOpened:friendlyName];
    return model;
}

// Close the database model by removing it from memory.
- (void)closeDatabaseModelNamed:(NSString *)friendlyName {
    [openDatabaseModels removeObjectForKey:friendlyName];
    [self notifyModelClosed:friendlyName];
}

// Close all of the open models - useful for locking all databases
- (void)closeAllDatabaseModels {
    [[openDatabaseModels allKeys] enumerateObjectsUsingBlock:^(id name, NSUInteger idx, BOOL *stop) {
        [self notifyModelClosed:name]; 
    }];
    [openDatabaseModels removeAllObjects];
}

//------------------------------------------------------------------------------------
// Modify the list of database preferences (known database files)

// Add a new database
- (BOOL)addDatabaseNamed:(NSString *)friendlyName 
           withFileNamed:(NSString *)fileName
              passphrase:(NSString *)passphrase
                errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if ([self doesFriendlyNameExist:friendlyName]) {
        SET_ERROR(errorMsg, 
                  ([self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" already exists", friendlyName]]));
        return NO;
    }
    
    // Add the file mapping
    [friendlyNameToFilename setObject:fileName forKey:friendlyName];
    
    // Attempt to open the model
    if (nil == [self openDatabaseModelNamed:friendlyName passphrase:passphrase errorMsg:errorMsg]) {
        // Remove the mapping as the passphrase was likely wrong
        [friendlyNameToFilename removeObjectForKey:friendlyName];
        return NO;
    }
    
    // Synchronize the preferences and send a notification
    [self synchronizeUserDefaults];
    [self notifyModelAdded:friendlyName];
    return YES;
}

// Rename an existing database to a new friendly name
- (BOOL)renameDatabaseNamed:(NSString *)origFriendlyName 
                  toNewName:(NSString *)newFriendlyName
                   errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if ([self doesFriendlyNameExist:newFriendlyName]) {
        SET_ERROR(errorMsg,
                  ([self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" already exists", newFriendlyName]]));
        return NO;
    }
    if (![self doesFriendlyNameExist:origFriendlyName]) {
        SET_ERROR(errorMsg, 
                ([self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" does not exist", origFriendlyName]]));
        return NO;
    }
    
    // Copy the filePath data from old name to new name
    NSString *filePath = [friendlyNameToFilename objectForKey:origFriendlyName];
    if (filePath) {
        [friendlyNameToFilename setObject:filePath forKey:newFriendlyName];
        [friendlyNameToFilename removeObjectForKey:origFriendlyName];
    }
    
    // Copy the model from the old name to the new name
    iPWSDatabaseModel *model = [self getOpenedDatabaseModelNamed:origFriendlyName errorMsg:NULL];
    if (model) {
        model.friendlyName = newFriendlyName;
        [openDatabaseModels setObject:model forKey:newFriendlyName];
        [openDatabaseModels removeObjectForKey:origFriendlyName];
    }
    
    // Synchronize and notify
    [self synchronizeUserDefaults];
    [self notifyModelRenamedFrom:origFriendlyName to:newFriendlyName];
    return YES;
}

// Remove a database both from the in memory mapping and the list of known databases.  Might remove the file
// if the preferences indicate
- (BOOL)removeDatabaseNamed:(NSString *)friendlyName errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if (![self doesFriendlyNameExist:friendlyName]) {
        SET_ERROR(errorMsg, ([self errorWithStr:
                              [NSString stringWithFormat:@"Database \"%@\" does not exist", friendlyName]]));
        return NO;
    }

    // Remove the file and any mappings
    BOOL preserveFiles = [[NSUserDefaults standardUserDefaults] boolForKey:@"preserve_files_on_delete"];
    if (!preserveFiles) {
        [[NSFileManager defaultManager] removeItemAtPath:[self databasePathForName:friendlyName] error:NULL];
    }
    [self closeDatabaseModelNamed:friendlyName];
    [friendlyNameToFilename removeObjectForKey:friendlyName];

    // Synchronize and notify
    [self synchronizeUserDefaults];
    [self notifyModelRemoved:friendlyName];
    return YES;
}

// Duplicate the given database
- (BOOL)duplicateDatabaseNamed:(NSString *)origFriendlyName
                     toNewName:(NSString *)newFriendlyName
                      errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if ([self doesFriendlyNameExist:newFriendlyName]) {
        SET_ERROR(errorMsg, ([self errorWithStr:
                              [NSString stringWithFormat:@"Database \"%@\" already exists", newFriendlyName]]));
        return NO;
    }
    
    // Get the original database model
    iPWSDatabaseModel *origModel = [self getOpenedDatabaseModelNamed:origFriendlyName errorMsg:errorMsg];
    if (!origModel) return NO;
    
    // Copy the database file
    NSString* newFileName = [self createUniqueFilenameWithPrefix:newFriendlyName];
    if (![[NSFileManager defaultManager] copyItemAtPath:[self databasePathForName:origFriendlyName]
                                                 toPath:[self databasePathForFileName:newFileName] 
                                                  error:errorMsg]) {
        return NO;
    }
    
    // Add the new database into our map
    return [self addDatabaseNamed:newFriendlyName 
                    withFileNamed:newFileName 
                       passphrase:origModel.passphrase
                         errorMsg:errorMsg];
}

// Replace one model with another.  Renames the new model's file to the to-be-replaced model's file
- (BOOL)replaceExistingModel:(iPWSDatabaseModel *)modelToBeReplaced 
           withUnmappedModel:(iPWSDatabaseModel *)newModel 
                    errorMsg:(NSError **)errorMsg {
    // First, duplicate the to-be-replaced model into a temporary for disaster recovery
    NSString *theFilename = modelToBeReplaced.fileName;
    NSString *backupFile  = [NSString stringWithFormat:@"%@.preswap", modelToBeReplaced.fileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:backupFile error:errorMsg];
    if (![fileManager moveItemAtPath:modelToBeReplaced.fileName toPath:backupFile error:errorMsg]) {
        return NO;
    }
    modelToBeReplaced.fileName = backupFile;
    
    // Move the new model into the old model's file
    if (![fileManager moveItemAtPath:newModel.fileName toPath:theFilename error:errorMsg]) {
        // Holy crap we are in trouble now.
        return NO;
    }
    newModel.fileName = theFilename;
    
    // Update the friendlyName and settings and replace the opened model with the new one
    newModel.friendlyName = modelToBeReplaced.friendlyName;
    [openDatabaseModels setObject:newModel forKey:newModel.friendlyName];
    
    return YES;
}

//------------------------------------------------------------------------------------
// Private interface

// Event handling
- (void)notifyModelAdded:(NSString *)friendlyName {
    [self notifyWithName:iPWSDatabaseFactoryModelAddedNotification forModelName:friendlyName]; 
}

- (void)notifyModelRenamedFrom:(NSString *)oldName to:(NSString *)newName {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              oldName, iPWSDatabaseFactoryOldModelNameUserInfoKey,
                              newName, iPWSDatabaseFactoryNewModelNameUserInfoKey, nil];
    [self notifyWithName:iPWSDatabaseFactoryModelRenamedNotification userInfo:userInfo];
}

- (void)notifyModelRemoved:(NSString *)friendlyName {
    [self notifyWithName:iPWSDatabaseFactoryModelRemovedNotification forModelName:friendlyName];
}

- (void)notifyModelOpened:(NSString *)friendlyName {
    [self notifyWithName:iPWSDatabaseFactoryModelOpenedNotification forModelName:friendlyName];
}

- (void)notifyModelClosed:(NSString *)friendlyName {
    [self notifyWithName:iPWSDatabaseFactoryModelClosedNotification forModelName:friendlyName];
}
     
- (NSDictionary *)notificationInfoForModelName:(NSString *)friendlyName {
    return [NSDictionary dictionaryWithObject:friendlyName forKey:iPWSDatabaseFactoryModelNameUserInfoKey];
}

- (void)notifyWithName:(NSString *)name forModelName:(NSString *)friendlyName {
    [self notifyWithName:name userInfo:[self notificationInfoForModelName:friendlyName]];
}

- (void) notifyWithName:(NSString *)name userInfo:(NSDictionary *)userInfo {
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
}

// Synchronize the current in-memory list of safes with the preferences
- (void)synchronizeUserDefaults {
    [[NSUserDefaults standardUserDefaults] setObject:friendlyNameToFilename forKey:kiPWSDatabaseFactoryUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize]; 
}

// Build an error object for the given error string
- (NSError *)errorWithStr:(NSString *)errorStr {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorStr forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:@"iPWS" code:0 userInfo:userInfo];
}

@end
