//
//  ApplicationTableViewCell.h
//  YACD
//
//  Created by Derek Selander on 8/29/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PsychicStapler/PsychicStapler.h>

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *appIconImageView;
@property (weak, nonatomic) IBOutlet UILabel *displayNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *bundleIdentifierLabel;
@property (weak, nonatomic) IBOutlet UIView *isActiveProcessView;


- (void)setupCellWithApplicationProxy:(id <LSApplicationProxyProtocol>) applicationProxy pidInfo:(PIDInfo*)pidInfo;
@end

NS_ASSUME_NONNULL_END
