//
//  ApplicationTableViewCell.m
//  YACD
//
//  Created by Derek Selander on 8/29/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "ApplicationTableViewCell.h"

__attribute__((weak))
extern CGImageRef LICreateIconFromCachedBitmap(NSData* data);

@implementation ApplicationTableViewCell

- (void)setupCellWithApplicationProxy:(id <LSApplicationProxyProtocol>) applicationProxy pidInfo:(PIDInfo*)pidInfo {
    NSData *data = [applicationProxy primaryIconDataForVariant:0x22];
    CGImageRef imageRef = LICreateIconFromCachedBitmap(data);
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:2.0 orientation:UIImageOrientationUp];

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
