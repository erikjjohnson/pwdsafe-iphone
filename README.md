# PasswordSafes for the iPhone 
PasswordSafes is an iPhone/iPod wrapper around the PasswordSafe open-source code. The app is available for 
free on the Apple AppStore under the name PasswordSafes, or 
here: http://itunes.apple.com/us/app/passwordsafes/id397686739?mt=8&ls=1

No adds, no restricted features, really free.

## Sourceforge
This project has been migrated from https://sourceforge.net/projects/pwdsafe-iphone/. Same owner/maintainer, I just
like git and github better.

## Building the code

### Password Safe C Library
Get the core PasswordSafe C library source from: http://passwordsafe.sourceforge.net/
Specifically: http://sourceforge.net/projects/passwordsafe/files/passwordsafe/3.30/pwsafe-3.30-src.zip/download

Unzip the corelib and os directories into thirdpartysource/PasswordSafe.  The Xcode project in the same directory
is already set to build this library, I just didn't want to duplicate the source (and this allows one to pick there
version of the underlying crypto libraries as well).

### DropBox
Sign up for a developer account with DropBox: https://www.dropbox.com
Create a new application and get the access keys.

Add a new file: include/DropBoxKeys.h

```C
#define DROPBOX_APP_KEY_PLIST     yourappkeyunquoted
#define DROPBOX_APP_KEY         @"yourappkeyasnsstring"
#define DROPBOX_APP_SECRET      @"yourappsecretasnsstring"
```

Open the xcode project: iPasswordSafe, build and enjoy.

# Licence

Copyright (c) 2010, Erik J. Johnson                                                                                  
All rights reserved.                                                                                                 
                                                                                                                     
Redistribution and use in source and binary forms, with or without modification,                                     
are permitted provided that the following conditions are met:                                                        
                                                                                                                     
Redistributions of source code must retain the above copyright notice, this list                                     
of conditions and the following disclaimer.                                                                          
                                                                                                                     
Redistributions in binary form must reproduce the above copyright notice, this list of                               
conditions and the following disclaimer in the documentation and/or other materials                                  
provided with the distribution.                                                                                      
                                                                                                                     
Neither the name of Erik J. Johnson nor the names of its contributors may be used                                    
to endorse or promote products derived from this software without specific prior                                     
written permission.                                                                                                  
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND                                      
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED                                        
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.                                   
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,                                     
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT                                   
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR                                   
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,                                    
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)                                   
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY                               
OF SUCH DAMAGE. 

