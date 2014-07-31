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
#import "MBProgressHUD.h"
#import "UIViewController+NJKFullScreenSupport.h"
@interface RootViewController ()
@property(strong)UIWebView *webView;
@property(strong)TYYPAddressBar *addressBar;
@property(strong)NJKScrollFullScreen *scrollProxy;
@end

@implementation RootViewController



-(void)loadView{
    [super loadView];
    self.webView=[[UIWebView alloc]initWithFrame:self.view.bounds];
    [self.webView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addSubview:self.webView];
    
//    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
//    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[webView]|" options:0 metrics:nil views:@{@"webView":self.webView}]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[webView]|" options:0 metrics:nil views:@{@"webView":self.webView}]];;
    
    self.addressBar=[[TYYPAddressBar alloc]initWithFrame:CGRectMake(0, 0, 300, 30) webView:self.webView];
    [self.addressBar setTextFieldDelegate:self];
    [self.navigationItem setTitleView:self.addressBar];
    [self.navigationItem.titleView setUserInteractionEnabled:YES];
    
    
    _scrollProxy = [[NJKScrollFullScreen alloc] initWithForwardTarget:self]; // UIScrollViewDelegate and UITableViewDelegate methods proxy to ViewController
    self.webView.scrollView.delegate = (id)_scrollProxy;

    _scrollProxy.delegate = self;
    
    
}


-(void)connectTorNetwork{
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeIndeterminate;
    hud.labelText = NSLocalizedString(@"Connecting to Tor Network", nil);

    
    [[TorManager sharedManager] connectWithHandler:^(NSError *error) {
        NSString *homePage=@"http://www.google.com";

        [self.addressBar setText:homePage];
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:homePage]]];
        [hud hide:YES];
        
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
- (void)scrollFullScreen:(NJKScrollFullScreen *)proxy scrollViewDidScrollUp:(CGFloat)deltaY
{
    [self moveNavigtionBar:deltaY animated:YES];
//    CGRect webFrame=self.webView.frame;
//    webFrame.origin.y+= deltaY;
//
//    [self.webView setFrame:webFrame];
    [self.view setNeedsUpdateConstraints];
}

- (void)scrollFullScreen:(NJKScrollFullScreen *)proxy scrollViewDidScrollDown:(CGFloat)deltaY
{
    [self moveNavigtionBar:deltaY animated:YES];
//    CGRect webFrame=self.webView.frame;
//    webFrame.origin.y+= deltaY;
//
//    [self.webView setFrame:webFrame];
    [self.view setNeedsUpdateConstraints];
}

- (void)scrollFullScreenScrollViewDidEndDraggingScrollUp:(NJKScrollFullScreen *)proxy
{
    [self hideNavigationBar:YES];
    
}

- (void)scrollFullScreenScrollViewDidEndDraggingScrollDown:(NJKScrollFullScreen *)proxy
{
    [self showNavigationBar:YES];
}

@end
