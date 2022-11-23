//
//  HLTWebProgressView.h
//  Snapshot
//
//	@version 1.0.0 2017/7/5
//
//  Created by nscribble on 2017/7/5.
//  Copyright © 2017年 Jason. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HLTWebProgressViewProtocol.h"

@interface HLTWebProgressView : UIView<HLTWebProgressView>

@property (nonatomic,readonly) UIView *indicatorView;

@end
