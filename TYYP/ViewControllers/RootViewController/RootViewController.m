//
//  RootViewController.m
//  TYYP
//
//  Created by Cihan Emre Kisakurek on 31/07/14.
//  Copyright (c) 2014 Cihan Emre Kisakurek. All rights reserved.
//

#import "RootViewController.h"
#import "TorManager.h"

@interface RootViewController ()
@property(strong)UIWebView *webView;
@end

@implementation RootViewController



-(void)loadView{
    [super loadView];
    self.webView=[[UIWebView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:self.webView];
}


-(void)connectTorNetwork{
    [[TorManager sharedManager] connectWithHandler:^(NSError *error) {
        
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]]];
                
    }];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self connectTorNetwork];
}

@end
