//
//  HLTWebViewController.h
//  Snapshot
//
//  Created by cc on 2017/5/31.
//  Copyright © 2017年 Jason. All rights reserved.
//

/*
 WKWebView的封装：
 1、网络请求难处理被URLProtocol捕获问题
 2、网页白屏问题（内存）
 3、loadRequest的body丢失问题
 */

#import "HLTJavaScriptBridge.h"
#import "HLTWebView.h"

@import WebKit.WKWebView;

@interface HLTWebViewController : UIViewController <
HTWebViewDelegate
>

//! 默认使用BaseController的自定义导航栏样式 默认为YES
@property (nonatomic,assign) BOOL usingCustomNavBar;
//! 是否使用web标题 默认为YES
@property (nonatomic,assign) BOOL usingWebTitle;
//! 是否显示进度条 默认为NO
@property (nonatomic,assign) BOOL showProgressView;
//! 是否允许侧滑返回
@property (nonatomic,assign) BOOL allowsBackForwardNavigationGestures;

//! 是否允许重新加载 (用于登录状态是否刷新)
@property (nonatomic,assign) BOOL shouldReload;

//! js事件桥接对象（viewDidLoad/addJSBridge之后可用）
@property (nonatomic,readonly) HLTJavaScriptBridge *jsBridge;
//! 请求对象
@property (nonatomic,readonly) NSURLRequest *request;
@property (nonatomic,readonly) HLTWebView *htWebview;
//! webview
@property (nonatomic,readonly) WKWebView *webview;
//! webview是否已被加载
@property (nonatomic,readonly) BOOL isWebviewLoaded;

/**
 使用请求URL进行初始化

 @param URL 请求链接
 @return 网页控制器
 */
- (instancetype)initWithRequestURL:(NSURL *)URL;


/**
 使用请求request进行初始化

 @param request 页面请求对象
 @return 网页控制器
 */
- (instancetype)initWithRequest:(NSURLRequest *)request NS_DESIGNATED_INITIALIZER;

@end
