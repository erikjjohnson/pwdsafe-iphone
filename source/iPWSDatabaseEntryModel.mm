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

// Class: iPWSDatabaseEntryModel
// Description:
//  Represents a single entry in the password safe database.  This is backed by the C-library version which
//  stores the data encrypted in memory

// ---- Private interface
@interface iPWSDatabaseEntryModel () 
- (void)changed;
@end

// ---- Entry implementation
@implementation iPWSDatabaseEntryModel

@synthesize delegate;

// Canonical initializer
- (id)initWithData:(const CItemData *)theData delegate:(id<iPWSDatabaseEntryModelDelegate>)theDelegate {
    if (self = [super init]) {
        data = *theData;
        self.delegate = theDelegate;
    }
    
    return self;
}

// Destructor
- (void)dealloc {
    self.delegate = nil;
    [super dealloc];
}

// Accessors
- (NSString *)title {
    return [NSString stringWithUTF8String:data.GetTitle().c_str()];
}

- (void)setTitle:(NSString *)title {
    if ([title isEqualToString:self.title]) return;
    
    data.SetTitle([title UTF8String]);
    [self changed];
}

- (NSString *)user {
    return [NSString stringWithUTF8String:data.GetUser().c_str()];
}

- (void)setUser:(NSString *)user {
    if ([user isEqualToString:self.user]) return;
    
    data.SetUser([user UTF8String]);
    [self changed];
}

- (NSString *)password {
    return [NSString stringWithUTF8String:data.GetPassword().c_str()];
}

- (void)setPassword:password {
    if ([password isEqualToString:self.password]) return;

    data.SetPassword([password UTF8String]);
    [self changed];
}

- (NSString *)url {
    return [NSString stringWithUTF8String:data.GetURL().c_str()];
}

- (void)setUrl:(NSString *)url {
    if ([url isEqualToString:self.url]) return;

    data.SetURL([url UTF8String]);
    [self changed];
}

- (NSString *)notes {
    return [NSString stringWithUTF8String:data.GetNotes().c_str()];
}

- (void)setNotes:(NSString *)notes {
    if ([notes isEqualToString:self.notes]) return;

    data.SetNotes([notes UTF8String]);
    [self changed];
}

- (NSString *)accessTime {
    return [NSString stringWithUTF8String:data.GetATime().c_str()];
}

- (NSString *)creationTime {
    return [NSString stringWithUTF8String:data.GetCTime().c_str()];
}

- (NSString *)passwordExpiryTime {
    return [NSString stringWithUTF8String:data.GetXTime().c_str()];
}

- (const CItemData *)dataPtr {
    return &data;
}

// ---- Instance methods
- (BOOL)writeToPWSfile:(PWSfile *)pwsFileHandle {
    return !pwsFileHandle->WriteRecord(data);
}


// ---- Private interface
- (void)changed {
    [self.delegate iPWSDatabaseEntryModelChanged:self];
}


@end
