//
//  AppDelegate.m
//  PsychicPOC
//
//  Created by Derek Selander on 7/21/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "AppDelegate.h"
#import "SVProgressHUD.h"
@interface AppDelegate ()
@end

void SSZipArchiveProgressCallback(float progress) {
    [SVProgressHUD showProgress:progress status:@"Zipping Contents"];
}

void SSZipArchiveCompletionCallback(BOOL success) {
    [SVProgressHUD dismiss];
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeGradient];
    [SVProgressHUD setMaximumDismissTimeInterval:1.5];
    return YES;
}

@end
