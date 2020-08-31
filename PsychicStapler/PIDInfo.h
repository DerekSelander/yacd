//
//  PIDInfo.h
//  WanaCore
//
//  Created by Derek Selander on 6/11/18.
//  Copyright © 2018 Selander. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "commons.h"

NS_ASSUME_NONNULL_BEGIN
struct proc_bsdinfo procesIDForName(char const * name);

/// Used to represent a process on the system
@interface PIDInfo : NSObject

@property (nonatomic, assign) struct proc_bsdinfo info;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSNumber *pid;

// helpers from proc_bsdinfo's pbi_flags
@property (nonatomic, readonly) BOOL isSystemProcess;
@property (nonatomic, readonly) BOOL isBeingTraced;
@property (nonatomic, readonly) BOOL isAboutToExit;
@property (nonatomic, readonly) BOOL hasTerminal;
@property (nonatomic, readonly) BOOL hasTTY;

- (instancetype)initWithInfo:(struct proc_bsdinfo)procInfo error:(NSError**)error;

@end
NS_ASSUME_NONNULL_END
