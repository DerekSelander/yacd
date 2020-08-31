//
//  main.m
//  PsychicPOC
//
//  Created by Derek Selander on 7/21/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

/*
 
 codesign -f --entitlements /Users/lolgrep/code/PsychicStapler/PsychicPOC/evil_ent.xml   -s "Derek Selander" /Users/lolgrep/Library/Developer/Xcode/DerivedData/PsychicStapler-dlyaongotfrzvvfadpnuhmyjgajk/Build/Products/Debug-iphoneos/PsychicPOC.app/
 /Users/lolgrep/Library/Developer/Xcode/DerivedData/PsychicStapler-dlyaongotfrzvvfadpnuhmyjgajk/Build/Products/Debug-iphoneos/PsychicPOC.app/: replacing existing signature
 */
