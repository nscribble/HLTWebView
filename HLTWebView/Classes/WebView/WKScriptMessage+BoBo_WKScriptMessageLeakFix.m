//
//  WKScriptMessage+BoBo_WKScriptMessageLeakFix.m
//  Snapshot
//
//  Created by cc on 2017/6/2.
//  Copyright © 2017年 Jason. All rights reserved.
//  低版本WebKit的bug参见 `https://stackoverflow.com/questions/31094110/memory-leak-when-using-wkscriptmessagehandler`

#import "WKScriptMessage+BoBo_WKScriptMessageLeakFix.h"
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

@implementation WKScriptMessage (BoBo_WKScriptMessageLeakFix)

- (void)fixedDealloc
{
    // Compensate for the over-retain in -[WKScriptMessage _initWithBody:webView:frameInfo:name:].
    [self.body release];
    
    // Call our WKScriptMessage's superclass -dealloc implementation.
    [super dealloc];
}

+ (void)load
{
    // <https://webkit.org/b/136140> was fixed in WebKit trunk prior to the first v601 build being released.
    // Enable the workaround in WebKit versions < 601. In the unlikely event that the fix is backported, this
    // version check will need to be updated.
    int32_t version = NSVersionOfRunTimeLibrary("WebKit");
    int32_t majorVersion = version >> 16;
    if (majorVersion > 600) {
        return;
    }
    
    // Add our -dealloc to WKScriptMessage. If -[WKScriptMessage dealloc] already existed
    // we'd need to swap implementations instead.
    Method fixedDealloc = class_getInstanceMethod(self, @selector(fixedDealloc));
    IMP fixedDeallocIMP = method_getImplementation(fixedDealloc);
    class_addMethod(self, @selector(dealloc), fixedDeallocIMP, method_getTypeEncoding(fixedDealloc));
}

@end
