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

#import "PasswordAlertView.h"

#define kUITextFieldHeight   30.0
#define kUITextFieldXPadding 12.0
#define kUITextFieldYPadding 5.0

@interface PasswordAlertView ()
- (BOOL)doesRequireCustomLayout;
@end

//------------------------------------------------------------------------------------
// Class PasswordAlertView
// Description
//  Displays an alert view dialog box with a secure text entry field.  The text field can
//  be used to retrieve a passphrase/password
@implementation PasswordAlertView

@synthesize passwordTextField;

// Initializer
- (id)initWithTitle:(NSString *)title 
            message:(NSString *)message
           delegate:(id)delegate 
  cancelButtonTitle:(NSString *)cancelButtonTitle 
    doneButtonTitle:(NSString *)doneButtonTitle {
    
	self = [super initWithTitle:title 
                        message:message
                       delegate:delegate 
              cancelButtonTitle:cancelButtonTitle
              otherButtonTitles:doneButtonTitle, nil];    
	if (self) {
        if ([self doesRequireCustomLayout]) {
            // Create and add UITextField to UIAlertView
            self.passwordTextField = [[UITextField alloc] initWithFrame:CGRectZero];
            [self.passwordTextField setSecureTextEntry:YES];
            self.passwordTextField.autocorrectionType     = UITextAutocorrectionTypeNo;
            self.passwordTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            self.passwordTextField.alpha                  = 0.75;
            self.passwordTextField.borderStyle            = UITextBorderStyleRoundedRect;
            self.passwordTextField.delegate               = self;

            // insert UITextField before the first button
            BOOL inserted = NO;
            for (UIView *view in self.subviews) {
                if (!inserted && ![view isKindOfClass:[UILabel class]]) {
                    [self insertSubview:self.passwordTextField aboveSubview:view];
                }
            }
        } else {
            [self setAlertViewStyle:UIAlertViewStyleSecureTextInput];
        }
	}
	return self;
}

- (void)dealloc {
    self.passwordTextField = nil;
    [super dealloc];
}

// If our base class responds to setAlertViewStyle:, then we use our base
// class to perform all of the work, otherwise we perform a custom-layout
- (BOOL)doesRequireCustomLayout {
    return ![self respondsToSelector:@selector(setAlertViewStyle:)];
}

// The password text field is only used when a custom-layout is performed
- (UITextField *)passwordTextField {
    return ([self doesRequireCustomLayout]) ? passwordTextField : [self textFieldAtIndex:0];
}

// Make the keyboard visible within our text field
- (void) show {
	[super show];
    if ([self doesRequireCustomLayout]) {
        [self.passwordTextField becomeFirstResponder];
    }
}

// When the return key is pressed, simulate the done button being pressed
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    [self.delegate alertView:self clickedButtonAtIndex:[self firstOtherButtonIndex]];
    [self dismissWithClickedButtonIndex:[self firstOtherButtonIndex] animated:YES];
    return NO;
}


// Determine maximum y-coordinate of UILabel objects. 
- (CGFloat) maxLabelYCoordinate {
	CGFloat maxY = 0;
	for (UIView *view in self.subviews ){
		if ([view isKindOfClass:[UILabel class]]) {
			CGRect viewFrame = [view frame];
			CGFloat lowerY = viewFrame.origin.y + viewFrame.size.height;
			if(lowerY > maxY) maxY = lowerY;
		}
	}
	return maxY;
}

// Override layoutSubviews to correctly handle the UITextField
- (void)layoutSubviews {
	[super layoutSubviews];
    if (![self doesRequireCustomLayout]) return;
    
	CGRect frame       = [self frame];
    CGRect bounds      = [self bounds];
    CGFloat alertWidth = bounds.size.width;    
	CGFloat labelMaxY  = [self maxLabelYCoordinate];
        
	// Insert UITextField below labels and move other fields down accordingly
	for (UIView *view in self.subviews){
		if ([view isKindOfClass:[UITextField class]]){
			CGRect viewFrame = CGRectMake(
										kUITextFieldXPadding, 
										labelMaxY + kUITextFieldYPadding, 
										alertWidth - 2.0*kUITextFieldXPadding, 
										kUITextFieldHeight);
			[view setFrame:viewFrame];
        // Only move the other fields down if they are not the labels above
        // the text field or the outer "box" (UIImageView)
		} else if (![view isKindOfClass:[UILabel class]] &&
                   ![view isKindOfClass:[UIImageView class]]) {
			CGRect viewFrame = [view frame];
			viewFrame.origin.y += kUITextFieldHeight + kUITextFieldYPadding;
			[view setFrame:viewFrame];
		}
	}
		
	// size UIAlertView frame by height of UITextField
	frame.size.height += kUITextFieldHeight + kUITextFieldYPadding + 2.0;
	[self setFrame:frame];
}

@end