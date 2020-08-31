//
//  UIViewController+DisplayError.h
//  PsychicPOC
//
//  Created by Derek Selander on 8/7/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (DisplayError)
- (void)displayModalErrorWithMessage:(NSString *)message andError:(NSError * _Nullable )error;
@end

NS_ASSUME_NONNULL_END
