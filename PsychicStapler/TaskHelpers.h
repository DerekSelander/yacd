//
//  TaskHelpers.hpp
//  PsychicStapler
//
//  Created by Derek Selander on 7/21/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <stdio.h>

#import <mach-o/loader.h>
#import <stdlib.h>
#import "commons.h"

#ifdef __cplusplus
extern "C" {
#endif

struct mach_header_64* copyin_mach_header(mach_port_t task, mach_vm_address_t address);

const char *copyin_string(mach_port_t task, mach_vm_address_t address);

kern_return_t find_encrypted_address(mach_port_t task, mach_vm_address_t address, mach_vm_address_t *resolvedAddress);

#ifdef __cplusplus
} // extern C
#endif
