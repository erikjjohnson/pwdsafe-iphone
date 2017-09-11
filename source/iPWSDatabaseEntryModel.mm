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


#import "iPWSDatabaseEntryModel.h"
#import "NSString+CppStringAdditions.h"


NSString *iPWSDatabaseEntryModelChangedNotification = @"iPWSDatabaseEntryModelChangedNotification";

//------------------------------------------------------------------------------------
// Class: iPWSDatabaseEntryModel
// Description:
//  Represents a single entry in the password safe database.  This is backed by the C-library version which
//  stores the data encrypted in memory
 
#define SET_FIELD(f, m)                   \
  if ((f == nil) || [f isEqualToString:self.f]) return; \
  data.m ([(f) getStringX]);              \
  [self changed];

//------------------------------------------------------------------------------------
// Private interface
@interface iPWSDatabaseEntryModel () 
- (NSString *)stringForStringX:(const StringX&)stringX;
- (void)changed;
@end

//------------------------------------------------------------------------------------
// Entry implementation
@implementation iPWSDatabaseEntryModel

// Autoreleased initializer
+ (id)entryModelWithItemData:(const CItemData *)theData {
    return [[[self alloc] initWithItemData:theData] autorelease];
}

// Canonical initializer
- (id)initWithItemData:(const CItemData *)theData {
    if (self = [super init]) {
        data = *theData;
    }
    
    return self;
}

// Destructor
- (void)dealloc {
    [super dealloc];
}

//------------------------------------------------------------------------------------
// Accessors
- (NSString *)title              { return [self stringForStringX:data.GetTitle()]; }
- (NSString *)user               { return [self stringForStringX:data.GetUser()]; }
- (NSString *)password           { return [self stringForStringX:data.GetPassword()]; }
- (NSString *)url                { return [self stringForStringX:data.GetURL()]; }
- (NSString *)notes              { return [self stringForStringX:data.GetNotes()]; }
- (NSString *)accessTime         { return [self stringForStringX:data.GetATime()]; }
- (NSString *)creationTime       { return [self stringForStringX:data.GetCTime()]; }
- (NSString *)passwordExpiryTime { return [self stringForStringX:data.GetXTime()]; }

- (void)setTitle:(NSString *)title { SET_FIELD(title, SetTitle); }
- (void)setUser:(NSString *)user   { SET_FIELD(user, SetUser); }
- (void)setPassword:password       { SET_FIELD(password, SetPassword); }
- (void)setUrl:(NSString *)url     { SET_FIELD(url, SetURL); }
- (void)setNotes:(NSString *)notes { SET_FIELD(notes, SetNotes); }

- (const CItemData *)dataPtr       { return &data; }

//------------------------------------------------------------------------------------
// Instance methods
- (BOOL)writeToPWSfile:(PWSfile *)pwsFileHandle {
    return !pwsFileHandle->WriteRecord(data);
}


//------------------------------------------------------------------------------------
// Private interface
- (void)changed {
    [[NSNotificationCenter defaultCenter] postNotificationName:iPWSDatabaseEntryModelChangedNotification
                                                        object:self];
}

- (NSString *)stringForStringX:(const StringX&)stringX {
    char* d = (char*)stringX.data();
    unsigned long s = stringX.size() * sizeof(wchar_t);
    
    NSString* result = [[NSString alloc] initWithBytes:d length:s encoding:kEncoding_wchar_t];
    return result;
}

@end
