//
//  UIViewController+DisplayError.m
//  PsychicPOC
//
//  Created by Derek Selander on 8/7/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "UIViewController+DisplayError.h"

@implementation UIViewController (DisplayError)

- (void)displayModalErrorWithMessage:(NSString *)message andError:(NSError *)error {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:error ? error.localizedDescription : @": [" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *handler = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:handler];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
