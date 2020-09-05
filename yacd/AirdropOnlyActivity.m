//
//  AirdropOnlyActivity.m
//  yacd
//
//  Created by Derek Selander on 9/3/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "AirdropOnlyActivity.h"

@interface AirdropOnlyActivity ()
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, strong) UIImage *image;
@end

@implementation AirdropOnlyActivity

- (instancetype)initWithImage:(UIImage *)image appName:(NSString*)appName
{
    self = [super init];
    if (self) {
        _image = image;
        _appName = appName;
    }
    return self;
}

- (UIActivityType)activityType {
    return UIActivityTypeAirDrop;
}

- (UIActivityCategory)activityCategory {
    return UIActivityCategoryAction;
}



@end
