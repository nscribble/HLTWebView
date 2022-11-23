//
//  HTViewController.m
//  HLTWebView
//
//  Created by nscribble on 06/15/2019.
//  Copyright (c) 2019 nscribble. All rights reserved.
//

#import "HTViewController.h"
#import <HLTWebView/HLTJavaScriptBridge.h>

@interface HTViewController ()
<
WKNavigationDelegate,
WKScriptMessageHandler
>

@property (nonatomic, strong) WKWebView *webview;
@property (nonatomic, strong) HLTJavaScriptBridge *bridge;

@end

@implementation HTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    conf.requiresUserActionForMediaPlayback = YES;
    self.webview = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:conf];
    [self.view addSubview:self.webview];
    self.bridge = [HLTJavaScriptBridge bridgeForWebView:self.webview webviewDelegate:self];
    [self registerEvent];
    NSURL *url = [[NSBundle bundleForClass:[HLTJavaScriptBridge class]] URLForResource:@"bridge" withExtension:@"html"];
    [self.webview loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)registerEvent {
    [self.bridge registerEvent:@"event-request-info" handler:^(NSString *event, NSDictionary *dataFromJS, HTJsBridgeResponseCallback responseCallback) {
        NSLog(@"接收到：%@, data：%@", event, dataFromJS);
        responseCallback(@{@"d": @"k"});
    }];
    
//    [self.bridge preparedForJSEvent];
}

#pragma mark -

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
}

@end
