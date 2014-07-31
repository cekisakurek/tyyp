//
//  RootViewController.m
//  TYYP
//
//  Created by Cihan Emre Kisakurek on 31/07/14.
//  Copyright (c) 2014 Cihan Emre Kisakurek. All rights reserved.
//

#import "RootViewController.h"
#import "TorManager.h"
#import "TYYPAddressBar.h"
@interface RootViewController ()
@property(strong)UIWebView *webView;
@property(strong)TYYPAddressBar *addressBar;
@end

@implementation RootViewController



-(void)loadView{
    [super loadView];
    self.webView=[[UIWebView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:self.webView];
    
    
    self.addressBar=[[TYYPAddressBar alloc]initWithFrame:CGRectMake(0, 0, 300, 30) webView:self.webView];
    [self.addressBar setTextFieldDelegate:self];
    [self.navigationItem setTitleView:self.addressBar];
    [self.navigationItem.titleView setUserInteractionEnabled:YES];
    
    
}


-(void)connectTorNetwork{
    [[TorManager sharedManager] connectWithHandler:^(NSError *error) {
        NSString *homePage=@"http://www.google.com";

        [self.addressBar setText:homePage];
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:homePage]]];
        
    }];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self connectTorNetwork];
}
-(void)requestAddressWithString:(NSString*)string{
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:string]]];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [self requestAddressWithString:textField.text];
    [textField resignFirstResponder];
    return YES;
}

@end
