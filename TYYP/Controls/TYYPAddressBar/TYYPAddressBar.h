//
//  TYYPAddressBar.h
//  TYYP
//
//  Created by Cihan Emre Kisakurek on 31/07/14.
//  Copyright (c) 2014 Cihan Emre Kisakurek. All rights reserved.
//

#import <UIKit/UIKit.h>



@interface TYYPAddressBar : UIView<UIWebViewDelegate>


@property(weak,nonatomic)id<UITextFieldDelegate> textFieldDelegate;
-(id)initWithFrame:(CGRect)frame webView:(UIWebView*)webView;

-(void)setText:(NSString*)text;
@end

