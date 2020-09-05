//
//  ProcessModule.h
//  yacd
//
//  Created by Derek Selander on 9/3/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProcessModule : NSObject
@property (nonatomic, strong, readonly) NSString *path;
@property (nonatomic, strong, readonly) NSNumber *address;
@property (nonatomic, readonly, assign) BOOL isSharedCache;

- (instancetype)initWithPath:(const char *)path startAddress:(uintptr_t)address task:(mach_port_t)task;
@end

NS_ASSUME_NONNULL_END
