//
//  ProcessDetailsViewController.h
//  PsychicPOC
//
//  Created by Derek Selander on 8/2/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PsychicStapler/PsychicStapler.h>
#import "PIDInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ProcessDetailsViewController : UIViewController
@property (nonatomic, strong) PIDInfo* pidInfo;
@property (nonatomic, strong) id<LSApplicationProxyProtocol> application;
@end

NS_ASSUME_NONNULL_END
