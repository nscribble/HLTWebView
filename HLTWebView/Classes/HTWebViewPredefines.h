//
//  HTWebViewPredefines.h
//  Kernel
//
//  Created by cc on 2018/10/8.
//  Copyright © 2018 Jason. All rights reserved.
//

#ifndef HTWebViewPredefines_h
#define HTWebViewPredefines_h

#pragma mark -

#ifndef weakify
#define weakify(var) __weak typeof(var) AHKWeak_##var = var;
#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = AHKWeak_##var; \
_Pragma("clang diagnostic pop")
#endif

#pragma mark - GUARD

#ifndef HT_GUARD_CLASS
#define HT_GUARD_CLASS(obj, cls)\
if (obj && ![obj isKindOfClass:cls]) {\
    HLTLog(@"%@ is NOT %@", obj, NSStringFromClass(cls));\
    return;\
}
#endif

#ifndef HT_GUARD_NOTNIL
#define HT_GUARD_NOTNIL(obj)\
if (obj == nil) {\
    HLTLog(@"%@ SHOULD NOT BE NIL", obj);\
    return;\
}
#endif

#pragma mark - LOG

#ifndef HLTLog
#define HLTLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#endif

#pragma mark

#ifndef dispatch_queue_async_safe
#define dispatch_queue_async_safe(queue, block)\
if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(queue)) {\
    block();\
} else {\
    dispatch_async(queue, block);\
}
#endif

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) dispatch_queue_async_safe(dispatch_get_main_queue(), block)
#endif

#ifndef HTPackStr
#define HTPackStr(str) @#str
#endif

#endif /* HTPredefines_h */
