//
//  PIDInfo.m
//  WanaCore
//
//  Created by Derek Selander on 6/11/18.
//  Copyright © 2018 Selander. All rights reserved.
//

#import "PIDInfo.h"
@import Darwin.Mach;
@implementation PIDInfo

- (instancetype)initWithInfo:(struct proc_bsdinfo)procInfo error:(NSError **)error {
    if (self = [super init]) {
        self.info = procInfo;
//        mach_port_name_t externalTask = 0;
//        task_for_pid(mach_task_self(), procInfo.pbi_pid, &_externalTask);
        
        char buffer[PROC_PIDPATHINFO_MAXSIZE];
        int ret = proc_pidpath(procInfo.pbi_pid, buffer, PROC_PIDPATHINFO_MAXSIZE);
        
        if (ret <= 0) {
            // error
            if (error) {
                *error = [[NSError alloc] initWithDomain:NSMachErrorDomain code:ret userInfo:nil];
            }
            return nil;
        } else {
            self->_path = [NSString stringWithUTF8String:buffer];
        }
    }
    
    return self;
}

- (NSNumber *)pid {
    return @(self->_info.pbi_pid);
}

- (NSString *)name {
    return [NSString stringWithUTF8String:self->_info.pbi_name];
}

- (NSUInteger)hash {
    return self->_info.pbi_pid;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[self class]]) {
        return ((PIDInfo*)object).pid == self.pid;
    }
    return [super isEqual:object];
}

//*****************************************************************************/
#pragma mark - Flags
//*****************************************************************************/

- (BOOL)isSystemProcess {
    return _info.pbi_flags & PROC_FLAG_SYSTEM;
}

- (BOOL)isBeingTraced {
    return _info.pbi_flags & PROC_FLAG_TRACED;
}

- (BOOL)isAboutToExit {
    return _info.pbi_flags & PROC_FLAG_INEXIT;
}

- (BOOL)hasTTY {
    return _info.pbi_flags & PROC_FLAG_CTTY;
}

- (BOOL)hasTerminal {
    return _info.pbi_flags & PROC_FLAG_CONTROLT;
}

#if DEBUG
- (NSString *)debugDescription {
    NSString *description = [super debugDescription];
    NSMutableString *retString = [[NSMutableString alloc] initWithString:description];
    [retString appendString:[NSString stringWithFormat:@" %@ (%@)", [self name], [self pid]]];
    return retString;
}
#endif

@end

void machError(kern_return_t kr) {
    //  mach_print/
}



//@end
