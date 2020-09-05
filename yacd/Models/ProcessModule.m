//
//  ProcessModule.m
//  yacd
//
//  Created by Derek Selander on 9/3/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "ProcessModule.h"
#import <PsychicStapler/PsychicStapler.h>
#import <mach-o/loader.h>
@implementation ProcessModule

- (instancetype)initWithPath:(const char *)path startAddress:(uintptr_t)address task:(mach_port_t)task {
    if (self = [super init]) {
        _path = [NSString stringWithUTF8String:path];
        _address = @(address);
        
        mach_vm_size_t size = sizeof(struct mach_header_64);
        struct mach_header_64 header = {};
        if (mach_vm_read_overwrite(task, address, sizeof(struct mach_header_64), (mach_vm_address_t)&header, &size)) {
            return self;
        }
        _isSharedCache = (header.flags & MH_DYLIB_IN_CACHE) ? YES : NO;
        
    }
    return self; 
}
@end
