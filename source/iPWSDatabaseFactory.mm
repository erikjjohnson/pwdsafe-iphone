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

// Class: iPWSDatabaseFactory
// Description:
//  The iPWSDatabaseFactory is represents the list of known PasswordSafe databases.
//  Each database is represented by a friendly name, which maps to a database
//  model, a file path, and version.  The mapping from friendlyName to file name is maintained in the application's
//  preferences.  The mapping from friendlyName to database instance is only maintained in memory. Hence, it
//  is possible that a friendlyName exists, but the call to obtain the database for that friendly name
//  (databaseNamed:errorMsg:) fails.  In this case, one must call addDatabaseNamed:withFileNamed:passphrase:errorMsg:
//  to instantiate the database instance.
//

// ---- Private interface
@interface iPWSDatabaseFactory () 
- (void)synchronizeUserDefaults;

- (NSError *)errorWithStr:(NSString *)errorStr;
@end


// ---- Class variables
// The key placed in the UserDefaults to retrieve the allDatabasesInfo
static NSString *kiPWSDatabaseFactoryUserDefaults = @"kiPWSDatabaseFactoryUserDefaults";


// ---- Factory implementation
@implementation iPWSDatabaseFactory

@synthesize documentsDirectory;

// Canonical initializer
- (id)initWithDelegate:(id <iPWSDatabaseFactoryDelegate>)theDelegate {
    if (self = [super init]) {
        delegate = theDelegate;
        
        databaseFileNames = [[NSMutableDictionary dictionary] retain];
        databases         = [[NSMutableDictionary dictionary] retain];

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
            [databaseFileNames setObject:fileName forKey:key];
        }];
        [self synchronizeUserDefaults];
        
        // Find the documents directories and use the first one
        NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
        if (![docDirs count]) {
            return nil;
            UIAlertView *v = [[UIAlertView alloc] initWithTitle:@"Unable to find safes"
                                                        message:@"The location of the safes is missing.  Try backing up safes with iTunes file sharing then reinstall the application."
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
            [v show];
            [v release];
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
    [databaseFileNames release];
    [databases release];
    [super dealloc];
}

// ---- Instance methods

// Enumerating the friendly names
- (NSArray *)friendlyNames {
    return [databaseFileNames allKeys];
}

// Helper methdos to check the existance of a friendlyName or mapped file name
- (BOOL)doesFriendlyNameExist:(NSString *)friendlyName {
    return [self.friendlyNames containsObject:friendlyName];
}

- (BOOL)isFileNameMapped:(NSString *)fileName {
    NSEnumerator *etr = [databaseFileNames objectEnumerator];
    NSString *name;
    while (name = [etr nextObject]) {
        if ([name isEqualToString:fileName]) return YES;
    }
    return NO;
}

// The full path, including filename, for the given friendly name
- (NSString *)databasePathForName:(NSString *)friendlyName {
    return [documentsDirectory stringByAppendingPathComponent:[databaseFileNames objectForKey:friendlyName]];
}

// Accessing the database models

// The database for a given name.  The friendlyName may exists, but the database not exist if either
// the database has never been opened or removed
- (iPWSDatabaseModel *)databaseModelNamed:(NSString *)friendlyName errorMsg:(NSError **)errorMsg {
    // Check that the friendlyName exists
    if (![self doesFriendlyNameExist:friendlyName]) {
        if (errorMsg) {
            *errorMsg = [self errorWithStr:[NSString stringWithFormat:@"Database named %@ does not exist",friendlyName]];
        }
        return nil;
    }
    
    // Get the model, if it exists
    iPWSDatabaseModel *model = [databases objectForKey:friendlyName];
    if (!model) {
        if (errorMsg) {
            *errorMsg = [self errorWithStr:[NSString stringWithFormat:@"Problem accessing \"%@\"", friendlyName]];
        }
    }
    return model;
}

// Only remove the model, not the database mapping
- (void)removeDatabaseModelNamed:(NSString *)friendlyName {
    [databases removeObjectForKey:friendlyName];
}

- (void)removeAllDatabaseModels {
    [databases removeAllObjects];
}


// Modify the known databases

- (BOOL)addDatabaseNamed:(NSString *)friendlyName 
           withFileNamed:(NSString *)fileName
              passphrase:(NSString *)passphrase
                errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if ([self databaseModelNamed:friendlyName errorMsg:NULL]) {
        if (errorMsg) {
            *errorMsg = [self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" already exists", friendlyName]];
        }
        return NO;
    }
    
    // Construct a new model
    iPWSDatabaseModel *model = [[iPWSDatabaseModel alloc] initNamed:friendlyName
                                                          fileNamed:[documentsDirectory stringByAppendingPathComponent:fileName]
                                                         passphrase:passphrase
                                                           errorMsg:errorMsg];
    if (!model) {
        return NO;
    }
    
    // Add the model to the factory
    [databaseFileNames setObject:fileName forKey:friendlyName];
    [databases setObject:model forKey:friendlyName];
    [self synchronizeUserDefaults];
    
    // Notify the delegate
    [delegate iPWSDatabaseFactory:self didAddModelNamed:friendlyName];
    return YES;
}

- (BOOL)renameDatabaseNamed:(NSString *)origFriendlyName 
                  toNewName:(NSString *)newFriendlyName
                   errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if ([self doesFriendlyNameExist:newFriendlyName]) {
        if (errorMsg) {
            *errorMsg = [self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" already exists", newFriendlyName]];
        }
        return NO;
    }
    if (![self doesFriendlyNameExist:origFriendlyName]) {
        if (errorMsg) {
            *errorMsg = [self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" does not exist", origFriendlyName]];
        }
        return NO;
    }
    
    // Copy the filePath data from old name to new name
    NSString *filePath = [self databasePathForName:origFriendlyName];
    if (filePath) {
        [databaseFileNames setObject:filePath forKey:newFriendlyName];
        [databaseFileNames removeObjectForKey:origFriendlyName];
    }
    
    // Copy the model from the old name to the new name
    iPWSDatabaseModel *model = [databases objectForKey:origFriendlyName];
    if (model) {
        model.friendlyName = newFriendlyName;
        [databases setObject:model forKey:newFriendlyName];
        [databases removeObjectForKey:origFriendlyName];
    }
    
    [self synchronizeUserDefaults];
    
    // Notify the delegate
    [delegate iPWSDatabaseFactory:self didRenameModelNamed:origFriendlyName toNewName:newFriendlyName];
    return YES;
}

- (BOOL)removeDatabaseNamed:(NSString *)friendlyName errorMsg:(NSError **)errorMsg {
    // Sanity checks
    if (![self doesFriendlyNameExist:friendlyName]) {
        if (errorMsg) {
            *errorMsg = [self errorWithStr:[NSString stringWithFormat:@"Database \"%@\" does not exist"]];
        }
        return NO;
    }

    // Remove the file and any mappings
    BOOL preserveFiles = [[NSUserDefaults standardUserDefaults] boolForKey:@"preserve_files_on_delete"];
    if (!preserveFiles) {
        [[NSFileManager defaultManager] removeItemAtPath:[self databasePathForName:friendlyName] error:NULL];
    }
    [databaseFileNames removeObjectForKey:friendlyName];
    [self removeDatabaseModelNamed:friendlyName];
    [self synchronizeUserDefaults];
    
    // Notify the delegate
    [delegate iPWSDatabaseFactory:self didRemoveModelNamed:friendlyName];
    return YES;
}


// ---- Private interface

- (void)synchronizeUserDefaults {
    [[NSUserDefaults standardUserDefaults] setObject:databaseFileNames forKey:kiPWSDatabaseFactoryUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize]; 
}

- (NSError *)errorWithStr:(NSString *)errorStr {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorStr forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"iPWS" code:0 userInfo:userInfo];
}

@end
