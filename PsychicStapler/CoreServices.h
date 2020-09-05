//
//  LSApplicationWorkspaceProtocol.h
//  PsychicStapler
//
//  Created by Derek Selander on 7/27/20.
//  Copyright © 2020 Selander. All rights reserved.
//



#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// CoreServices framework, automatically loaded in iOS/OSX shared cache
@protocol LSApplicationProxyProtocol <NSObject>
- (NSURL*)bundleURL;
- (NSString*)applicationIdentifier;
- (NSString*)bundleIdentifier;
- (NSData*)primaryIconDataForVariant:(int)variant;
- (NSString *)localizedName;
- (NSString *)canonicalExecutablePath;
@end

@protocol LSApplicationWorkspaceProtocol <NSObject>
+ (id<LSApplicationWorkspaceProtocol>)defaultWorkspace;
-(NSArray <id<LSApplicationProxyProtocol>>*)allApplications;
@end

#ifdef __cplusplus
extern "C" {
#endif

__attribute__((weak))
 CGImageRef LICreateIconFromCachedBitmap(NSData* data);

#ifdef __cplusplus
}
#endif

