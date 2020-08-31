//
//  TaskHelpers.cpp
//  PsychicStapler
//
//  Created by Derek Selander on 7/21/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "TaskHelpers.h"

const char *copyin_string(mach_port_t task, mach_vm_address_t address) {
    #define kCopyInStringBufferSize 2048
    kern_return_t kr = KERN_SUCCESS;
    mach_msg_type_number_t size = kCopyInStringBufferSize;
    char *externPath = NULL;
    kr = mach_vm_read(task, address, size, (vm_offset_t *)&externPath, &size);
    if (kr != KERN_SUCCESS) {
        return NULL;
    }
    
    return (const char *)strdup(externPath);
}

struct mach_header_64* copyin_mach_header(mach_port_t task, mach_vm_address_t address) {
    kern_return_t kr = KERN_SUCCESS;
    mach_vm_size_t size = sizeof(struct mach_header_64);
    struct mach_header_64 *header = (struct mach_header_64 *)malloc(sizeof(struct mach_header_64));
    kr = mach_vm_read_overwrite(task, address, size, (mach_vm_address_t)header, &size);
    if (kr != KERN_SUCCESS) {
        return NULL;
    }
    if (header->magic == MH_CIGAM || header->magic == MH_MAGIC) {
        exit(1);
    }
    
    if (header->magic == MH_CIGAM_64 || header->magic == MH_CIGAM) {
        exit(1);
    }
    
    return header;
    
}

kern_return_t find_encrypted_address(mach_port_t task, mach_vm_address_t address, mach_vm_address_t *resolvedAddress) {
    kern_return_t kr = KERN_SUCCESS;
    mach_vm_size_t size = sizeof(struct mach_header_64);
    struct mach_header_64 *header = (struct mach_header_64 *)malloc(sizeof(struct mach_header_64));
    kr = mach_vm_read_overwrite(task, address, size, (mach_vm_address_t)header, &size);
    if (kr != KERN_SUCCESS) {
        return NULL;
    }
    if (header->magic == MH_CIGAM || header->magic == MH_MAGIC) {
        // no 32 :[
        return KERN_FAILURE;
    }
    

    size = header->sizeofcmds;
    char* loadCommands = (char*)calloc(size, sizeof(char));
    kr = mach_vm_read_overwrite(task, address + sizeof(struct mach_header_64), size, (mach_vm_address_t)loadCommands, &size);
    struct load_command *cmd = NULL;
    for (uintptr_t ptr = (uintptr_t)loadCommands; ptr < (uintptr_t)loadCommands + header->sizeofcmds; ptr += cmd->cmdsize) {
        cmd = (struct load_command *)ptr;
        if (cmd->cmd == LC_ENCRYPTION_INFO_64) {
            struct encryption_info_command_64 *encryption = (struct encryption_info_command_64*)cmd;
            if (encryption->cryptid == 1) {
                printf("yay");
                
            }
        }
    }
    
    return KERN_SUCCESS;
    
}
