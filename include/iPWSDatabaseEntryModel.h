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

#import "corelib/ItemData.h"
#import "corelib/PWSfile.h"

//------------------------------------------------------------------------------------
// Notifications
//  iPWSDatabaseEntryModelChangedNotification
//    Whenever the entry changes it sends a notification on the default notification center with the
//    name iPWSDatabaseEntryModelChangedNotification, with the object being the instance of the model
//    and an empty user info dictionary
extern NSString *iPWSDatabaseEntryModelChangedNotification;

//------------------------------------------------------------------------------------
// Class: iPWSDatabaseEntryModel
// Description:
//  Represents a single entry in the password safe database.  This is backed by the C-library version which
//  stores the data encrypted in memory.  The entry is capable of writing itself to a given file.
@interface iPWSDatabaseEntryModel : NSObject {
    CItemData data;
}

// Accessors
@property (copy)     NSString* title;
@property (copy)     NSString* user;
@property (copy)     NSString* password;
@property (copy)     NSString* url;
@property (copy)     NSString* notes;
@property (readonly) NSString* accessTime;
@property (readonly) NSString* creationTime;
@property (readonly) NSString* passwordExpiryTime;

+ (id)entryModelWithItemData:(const CItemData *)theData;
- (id)initWithItemData:(const CItemData *)theData;
- (BOOL)writeToPWSfile:(PWSfile *)pwsFileHandle;

@end
