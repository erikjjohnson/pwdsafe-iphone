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
//f
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

#import "iPWSDropBoxPreferences.h"
#import "iPWSDatabaseFactory.h"

//------------------------------------------------------------------------------------
// Class: iPWSDropBoxPreferences
// Description:
//  The iPWSDropBoxPreferences is maintain a mapping from filename of a model to
//    1. Whether or not that file should be synchronized with Dropbox
//    2. The last known Dropbox revision of that file
//
//

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDropBoxPreferences () 
- (iPWSDatabaseFactory *)databaseFactory;
- (void)synchronizeUserDefaults;
- (void)modelRemoved:(NSNotification *)notification;

- (NSString *)modelToFile:(iPWSDatabaseModel *)model;
- (NSString *)modelNameToFile:(NSString *)friendlyName;
@end


//------------------------------------------------------------------------------------
// Class variables
// The keys placed in the UserDefaults
static NSString *kiPWSDropBoxUserDefaults    = @"kiPWSDropBoxUserDefaults";
static NSString *kiPWSDropBoxRevUserDefaults = @"kiPWSDropBoxRevUserDefaults";

//------------------------------------------------------------------------------------
// Factory implementation
@implementation iPWSDropBoxPreferences

// Get the singleton
+ (id)sharedPreferences {
    static iPWSDropBoxPreferences *sharedPreferences = nil;
    @synchronized(self) {
        if (nil == sharedPreferences) {
            sharedPreferences = [[iPWSDropBoxPreferences alloc] init];
        }
    }
    return sharedPreferences;
}

// Canonical initializer
- (id)init {
    if (self = [super init]) {        
        // Load the Dropbox synchronization information into a mutable array
        NSArray *syncs = [[NSUserDefaults standardUserDefaults] arrayForKey:kiPWSDropBoxUserDefaults];
        synchronizedFiles = [[NSMutableArray arrayWithArray:syncs] retain];
        
        // Load the Dropbox revisions information into a mutable dictionary
        NSDictionary *revs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kiPWSDropBoxRevUserDefaults];
        dropBoxRevisions = [[NSMutableDictionary dictionaryWithDictionary:revs] retain];

        [self synchronizeUserDefaults];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(modelRemoved:)
                                                     name:iPWSDatabaseFactoryModelRemovedNotification
                                                   object:[self databaseFactory]];
    }
    return self;
}

// Destructor
- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:iPWSDatabaseFactoryModelRemovedNotification
                                                  object:[self databaseFactory]];
    [synchronizedFiles release];
    [dropBoxRevisions release];
    [super dealloc];
}

- (iPWSDatabaseFactory *)databaseFactory {
    return [iPWSDatabaseFactory sharedDatabaseFactory];
}

- (BOOL)isModelSynchronizedWithDropBox:(iPWSDatabaseModel *)model {
    return [self isFileSynchronizedWithDropBox:[self modelToFile:model]];
}
- (BOOL)isModelNameSynchronizedWithDropBox:(NSString *)friendlyName {
    return [self isFileSynchronizedWithDropBox:[self modelNameToFile:friendlyName]];
}
- (BOOL)isFileSynchronizedWithDropBox:(NSString *)fileName {
    return [synchronizedFiles containsObject:fileName];
}

- (BOOL)markModelForDropBox:(iPWSDatabaseModel *)model {
    return [self markFileForDropBox:[self modelToFile:model]];
}
- (BOOL)markModelNameForDropBox:(NSString *)friendlyName {
    return [self markFileForDropBox:[self modelNameToFile:friendlyName]];
}
- (BOOL)markFileForDropBox:(NSString *)fileName {
    if ([self isFileSynchronizedWithDropBox:fileName]) return YES;
    if (![[self databaseFactory] doesFileNameExist:fileName]) return NO;
    [synchronizedFiles addObject:fileName];
    [self synchronizeUserDefaults];    
    return YES;
}

- (BOOL)unmarkModelForDropBox:(iPWSDatabaseModel *)model {
    return [self unmarkFileForDropBox:[self modelToFile:model]];
}
- (BOOL)unmarkModelNameForDropBox:(NSString *)friendlyName {
    return [self unmarkFileForDropBox:[self modelNameToFile:friendlyName]];
}
- (BOOL)unmarkFileForDropBox:(NSString *)fileName {
    if ([self isFileSynchronizedWithDropBox:fileName]) {
        [synchronizedFiles removeObject:fileName];
        [self synchronizeUserDefaults];
    }
    return YES;
}

- (NSString *)dropBoxRevForModel:(iPWSDatabaseModel *)model {
    return [self dropBoxRevForFile:[self modelToFile:model]];
}
- (NSString *)dropBoxRevForModelName:(NSString *)friendlyName {
    return [self dropBoxRevForFile:[self modelNameToFile:friendlyName]];
}
- (NSString *)dropBoxRevForFile:(NSString *)fileName {
    return [dropBoxRevisions objectForKey:fileName];
}

- (BOOL)setDropBoxRev:(NSString *)rev forModel:(iPWSDatabaseModel *)model {
    return [self setDropBoxRev:rev forFile:[self modelToFile:model]];
}
- (BOOL)setDropBoxRev:(NSString *)rev forModelName:(NSString *)friendlyName {
    return [self setDropBoxRev:rev forFile:[self modelNameToFile:friendlyName]];
}
- (BOOL)setDropBoxRev:(NSString *)rev forFile:(NSString *)fileName {
    if (![self isFileSynchronizedWithDropBox:fileName]) return NO;
    if (![[self databaseFactory] doesFileNameExist:fileName]) return NO;
    if (!rev) return NO;
    [dropBoxRevisions setObject:rev forKey:fileName];
    [self synchronizeUserDefaults];
    return YES;
}

- (void)modelRemoved:(NSNotification *)notification {
    NSString *friendlyName = [notification.userInfo objectForKey:iPWSDatabaseFactoryModelNameUserInfoKey];
    NSString *fileName     = [self modelNameToFile:friendlyName];
    BOOL preserveFiles = [[NSUserDefaults standardUserDefaults] boolForKey:@"preserve_files_on_delete"];
    if (fileName && !preserveFiles) {
        [synchronizedFiles removeObject:fileName];
        [dropBoxRevisions removeObjectForKey:fileName];
    }
}

- (NSString *)modelToFile:(iPWSDatabaseModel *)model {
    return [model.fileName lastPathComponent];
}

- (NSString *)modelNameToFile:(NSString *)friendlyName {
    return [[[self databaseFactory] databasePathForName:friendlyName] lastPathComponent];
}


// Synchronize the current in-memory list of safes with the preferences
- (void)synchronizeUserDefaults {
    [[NSUserDefaults standardUserDefaults] setObject:synchronizedFiles forKey:kiPWSDropBoxUserDefaults];
    [[NSUserDefaults standardUserDefaults] setObject:dropBoxRevisions forKey:kiPWSDropBoxRevUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize]; 
}

@end
