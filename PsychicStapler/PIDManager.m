//
//  PIDManager.m
//  WanaCore
//
//  Created by Derek Selander on 6/14/18.
//  Copyright © 2018 Selander. All rights reserved.
//

#import "PIDManager.h"
#import "commons.h"
//#import <sys/proc_info.h>

@implementation PIDManager

+ (PIDManager *)sharedManager {
  static PIDManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[PIDManager alloc] init];
  });
  
  return manager;
}

- (NSSet <PIDInfo*> *)getPIDsWithError:(NSError **)error {
    int bufsize = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    if (bufsize == 0) {
        if (error) {
            *error = [[NSError alloc] initWithDomain:NSMachErrorDomain code:0 userInfo:@{@"com.selander" : @"proc_listpids failed. You need to be root"}];
        }
        return nil;
    }
    
    NSMutableSet *returnSet = [[NSMutableSet alloc] initWithCapacity:bufsize];
    pid_t *pids = calloc(bufsize, sizeof(pid_t));
    proc_listpids(PROC_ALL_PIDS, 0, pids, bufsize);
    size_t num_pids = bufsize / sizeof(pid_t);
    
    for (int i = 0; i < num_pids; i++) {
        struct proc_bsdinfo proc;
        __unused int st = proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &proc, PROC_PIDTBSDINFO_SIZE);
        PIDInfo *pInfo = [[PIDInfo alloc] initWithInfo:proc error:nil];
        if (pInfo) {
            [returnSet addObject:pInfo];
        }
    }
    
    free(pids);
    return returnSet;
}

- (NSSet <PIDInfo*> *)procesIDsForName:(char const *)name error:(NSError **)error {
    int bufsize = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t *pids = calloc(bufsize, sizeof(pid_t));
    proc_listpids(PROC_ALL_PIDS, 0, pids, bufsize);
    size_t num_pids = bufsize / sizeof(pid_t);
    
    NSMutableSet <PIDInfo*>* returnSet = [NSMutableSet set];
    for (int i = 0; i < num_pids; i++) {
        struct proc_bsdinfo proc;
        __unused int st = proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &proc, PROC_PIDTBSDINFO_SIZE);
        if (strcmp(proc.pbi_name, name) == 0) {
            PIDInfo *info = [[PIDInfo alloc] initWithInfo:proc error:nil];
            if (info) {
                [returnSet addObject:info];
            }
        }
    }
    
    free(pids);
    return returnSet;
}

- (NSDictionary <NSString*, PIDInfo*> *)runningProcessesWithError:(NSError **)error; {
    int bufsize = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t *pids = calloc(bufsize, sizeof(pid_t));
    proc_listpids(PROC_ALL_PIDS, 0, pids, bufsize);
    size_t num_pids = bufsize / sizeof(pid_t);
    
    NSMutableDictionary <NSString*, PIDInfo*>* returnDictionary = [NSMutableDictionary dictionary];
    for (int i = 0; i < num_pids; i++) {
        struct proc_bsdinfo proc;
        __unused int st = proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &proc, PROC_PIDTBSDINFO_SIZE);
        PIDInfo *info = [[PIDInfo alloc] initWithInfo:proc error:error];
        if (info) {
            // Resolves symlinks (i.e. /private/var -> /var)
            NSURL *url = [NSURL fileURLWithPath:info.path];
            NSString *resolvedPath =[[url URLByResolvingSymlinksInPath] path];
            [returnDictionary setObject:info forKey:resolvedPath];
        }
    }
    
    free(pids);
    return returnDictionary;
}


@end
