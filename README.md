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

  #define DROPBOX_APP_KEY_PLIST     yourappkeyunquoted
  #define DROPBOX_APP_KEY         @"yourappkeyasnsstring"
  #define DROPBOX_APP_SECRET      @"yourappsecretasnsstring"


