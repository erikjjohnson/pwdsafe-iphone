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

//------------------------------------------------------------------------------------
// Notifications
//   iPWSDatabaseFactoryModelAddedNotification
//     When a new database is added to the factory a notification on the default notification center
//     is posted with the name iPWSDatabaseFactoryModelAddedNotification with the object being the database factory
//     and the user info dictionary containing a single key of value iPWSDatabaseFactoryModelNameUserInfoKey with 
//     an NSString with the friendly name of the model added
//   
//   iPWSDatabaseFactoryModelRenamedNotification
//     When a database is rename to the factory a notification on the default notification center
//     is posted with the name iPWSDatabaseFactoryModelRenamedNotification with the object being the database factory
//     and the user info dictionary containing a keys iPWSDatabaseFactoryOldModelNameUserInfoKey and 
//     iPWSDatabaseFactoryNewModelNameUserInfoKey both of which are NSStrings with the suggested values
//
//   iPWSDatabaseFactoryModelRemovedNotification
//     When a database is rename to the factory a notification on the default notification center
//     is posted with the name iPWSDatabaseFactoryModelRemovedNotification with the object being the database factory
//     and the user info dictionary containing a single key of value iPWSDatabaseFactoryModelNameUserInfoKey with 
//     an NSString with the friendly name of the model removed
extern NSString* iPWSDatabaseFactoryModelAddedNotification;
extern NSString* iPWSDatabaseFactoryModelRenamedNotification;
extern NSString* iPWSDatabaseFactoryModelRemovedNotification;
extern NSString* iPWSDatabaseFactoryModelNameUserInfoKey;
extern NSString* iPWSDatabaseFactoryOldModelNameUserInfoKey;
extern NSString* iPWSDatabaseFactoryNewModelNameUserInfoKey;


//------------------------------------------------------------------------------------
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
    NSString                       *documentsDirectory;
    NSMutableDictionary            *friendlyNameToFilename; // { friendlyName -> fileName}
    NSMutableDictionary            *openDatabaseModels;     // { friendlyName -> iPWSDatabaseModel }
}

// Access the singleton
+ (iPWSDatabaseFactory *)sharedDatabaseFactory;

// Accessors
@property (readonly) NSArray  *friendlyNames; 
@property (readonly) NSString *documentsDirectory;

// Helper methods to check the existance of a friendlyName or mapped file name
- (BOOL)doesFriendlyNameExist:(NSString *)friendlyName;
- (BOOL)isFileNameMapped:(NSString *)fileName;
- (NSString *)databasePathForName:(NSString *)friendlyName;
- (NSString *)createUniqueFilenameWithPrefix:(NSString *)prefix;

// Accessing the database models
- (iPWSDatabaseModel *)openDatabaseModelNamed:(NSString *)friendlyName 
                                   passphrase:(NSString *)passphrase
                                     errorMsg:(NSError **)errorMsg;
- (iPWSDatabaseModel *)getOpenedDatabaseModelNamed:(NSString *)friendlyName 
                                          errorMsg:(NSError **)errorMsg;
- (void)closeDatabaseModelNamed:(NSString *)friendlyName;
- (void)closeAllDatabaseModels;

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
- (BOOL)duplicateDatabaseNamed:(NSString *)origFriendlyName
                     toNewName:(NSString *)newFriendlyName
                      errorMsg:(NSError **)errorMsg;

@end
