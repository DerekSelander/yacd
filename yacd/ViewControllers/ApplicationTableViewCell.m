//
//  ApplicationTableViewCell.m
//  YACD
//
//  Created by Derek Selander on 8/29/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "ApplicationTableViewCell.h"


@implementation ApplicationTableViewCell

- (void)setupCellWithApplicationProxy:(id <LSApplicationProxyProtocol>) applicationProxy pidInfo:(PIDInfo*)pidInfo {
    NSData *data = [applicationProxy primaryIconDataForVariant:0x11];
    CGImageRef imageRef = LICreateIconFromCachedBitmap(data);
    CGFloat scale = [UIScreen mainScreen].scale;
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];

    self.appIconImageView.image = image;
    self.bundleIdentifierLabel.text = [applicationProxy bundleIdentifier];
    self.displayNameLabel.text = [applicationProxy localizedName];
    BOOL isApple = [[applicationProxy bundleIdentifier] containsString:@".apple"];
    self.contentView.backgroundColor = isApple ? [UIColor colorWithWhite:0.92 alpha:1.0] : [UIColor whiteColor];
    self.isActiveProcessView.hidden = pidInfo == nil ? YES : NO;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.isActiveProcessView.layer.cornerRadius = 10.0;
    self.isActiveProcessView.clipsToBounds = YES;
}

@end
