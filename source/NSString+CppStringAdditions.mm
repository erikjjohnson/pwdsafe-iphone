//
//  iPWSNSStringAdditions.m
//  iPasswordSafe
//
//  Created by Johnson, Erik on 9/5/17.
//  Copyright © 2017 JasonJohnsonSoftware. All rights reserved.
//

#import "NSString+CppStringAdditions.h"

#if TARGET_RT_BIG_ENDIAN
const NSStringEncoding kEncoding_wchar_t = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF32BE);
#else
const NSStringEncoding kEncoding_wchar_t = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF32LE);
#endif

@implementation NSString (cppstring_additions)

+(NSString*) stringWithStringX:(const StringX&)sx
{
    char* data = (char*)sx.data();
    unsigned long size = sx.size() * sizeof(wchar_t);
    
    NSString* result = [[NSString alloc] initWithBytes:data length:size encoding:kEncoding_wchar_t];
    return result;
}
+(NSString*) stringWithwstring:(const std::wstring&)ws
{
    char* data = (char*)ws.data();
    unsigned long size = ws.size() * sizeof(wchar_t);
    
    NSString* result = [[NSString alloc] initWithBytes:data length:size encoding:kEncoding_wchar_t];
    return result;
}
+(NSString*) stringWithstring:(const std::string&)s
{
    NSString* result = [[NSString alloc] initWithUTF8String:s.c_str()];
    return result;
}

-(StringX) getStringX
{
    NSData* asData = [self dataUsingEncoding:kEncoding_wchar_t];
    return StringX((wchar_t*)[asData bytes], [asData length] / sizeof(wchar_t));
}
-(std::wstring) getwstring
{
    NSData* asData = [self dataUsingEncoding:kEncoding_wchar_t];
    return std::wstring((wchar_t*)[asData bytes], [asData length] / sizeof(wchar_t));
}
-(std::string) getstring
{
    return [self UTF8String];
}

@end
