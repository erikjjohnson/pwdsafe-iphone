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


#import <Foundation/Foundation.h>
#import "corelib/PWSfile.h"
#import "iPWSDatabaseModel.h"
#import "iPWSDatabaseFactoryDelegate.h"

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

@interface iPWSDatabaseFactory : NSObject {
    id<iPWSDatabaseFactoryDelegate> delegate;
    NSString                       *documentsDirectory;
    NSMutableDictionary            *databaseFileNames; // { friendlyName -> fileName}
    NSMutableDictionary            *databases;         // { friendlyName -> iPWSDatabaseModel }
}

// ---- Instance methods
- (id)initWithDelegate:(id<iPWSDatabaseFactoryDelegate>)theDelegate;

// Accessors
@property (readonly) NSArray  *friendlyNames; 
@property (readonly) NSString *documentsDirectory;

// Helper methdos to check the existance of a friendlyName or mapped file name
- (BOOL)doesFriendlyNameExist:(NSString *)friendlyName;
- (BOOL)isFileNameMapped:(NSString *)fileName;
- (NSString *)databasePathForName:(NSString *)friendlyName;

// Accessing the database models
- (iPWSDatabaseModel *)databaseModelNamed:(NSString *)friendlyName errorMsg:(NSError **)errorMsg;
- (void)removeDatabaseModelNamed:(NSString *)friendlyName;
- (void)removeAllDatabaseModels;

// Modifing the known databases
- (BOOL)addDatabaseNamed:(NSString *)friendlyName 
           withFileNamed:(NSString *)fileName
              passphrase:(NSString *)passphrase
                errorMsg:(NSError **)errorMsg;
- (BOOL)renameDatabaseNamed:(NSString *)origFriendlyName 
                  toNewName:(NSString *)newFriendlyName
                   errorMsg:(NSError **)errorMsg;
- (BOOL)removeDatabaseNamed:(NSString *)friendlyName
                   errorMsg:(NSError **)errorMsg;

@end
