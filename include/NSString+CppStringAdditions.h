//
//  iPWSNSStringAdditions.h
//  iPasswordSafe
//
//  Created by Johnson, Erik on 9/5/17.
//  Copyright © 2017 JasonJohnsonSoftware. All rights reserved.
//

#ifndef NSString_CppStringAdditions_h
#define NSString_CppStringAdditions_h

#import "corelib/StringX.h"
#import <string>

extern const NSStringEncoding kEncoding_wchar_t;

@interface NSString (cppstring_additions)
+(NSString*) stringWithwstring:(const std::wstring&)string;
+(NSString*) stringWithstring:(const std::string&)string;
-(StringX) getStringX;
-(std::wstring) getwstring;
-(std::string) getstring;
@end

#endif /* NSString_CppStringAdditions_h */
