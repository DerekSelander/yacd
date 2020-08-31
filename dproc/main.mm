//
//  main.m
//  macPOC
//
//  Created by Derek Selander on 7/18/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PsychicStapler/PsychicStapler.h>
#import <unistd.h>
#import <mach-o/ldsyms.h>

static bool verbose = 0;

/////////////////////////////////////////////////

void printPIDs(void);
void printPIDInfo(pid_t pid);
void printProcessesWithName(const char *name);
void enumerateModules(const char *name);

/////////////////////////////////////////////////

int main(int argc, const char * argv[]) {
    
//    mount(<#const char *#>, <#const char *#>, MNT_UPDATE|MNT_RELOAD, <#void *#>)
    
//    FILE *fp;
//    char *command = "/bin/ps";
//
//    /* command contains the command string (a character array) */
//
//    /* If you want to read output from command */
//    char buf[1024];
//    fp = popen(command,"r");
//         /* read output from command */

//          fscanf(fp, "%s", buf);   /* or other STDIO input functions */
//
//    fclose(fp);





//    fscanf(fp, "%s", buf);   /* or other STDIO input functions */
//    
//    fclose(fp);


    
    mach_vm_address_t addr = 0;

    
    kern_return_t kr = ::find_encrypted_address(mach_task_self(), (mach_vm_address_t)&_mh_execute_header, &addr);
    int bflag, ch;

    bflag = 0;
    while ((ch = getopt(argc, (char* const*)argv, "e:Av:ap:n:")) != -1) {
            switch (ch) {
                case 'A':
                    verbose = 1;
                    // fallthrough
                case 'a':
                    printPIDs();
                    continue;
                case 'n':
                    printProcessesWithName(optarg);
                    continue;
                case 'e':
                    enumerateModules(optarg);
                case 'p': {
                    pid_t pid = atoi(optarg);
                    if (!pid) {
                        printf("Couldn't resolve %s\n", optarg);
                        exit(1);
                    }
                    printPIDInfo(pid);
                    continue;;
                }
                case 'v': {
                    printProcessesWithName(optarg);
                    break;
                }

                default:
                    break;
                    //usage();
            }
    }


    
    return 0;
}

void enumerateModules(const char *name) {
    NSError *err = nil;
    NSSet <PIDInfo*>*processSet = [[PIDManager sharedManager] procesIDsForName:name error:&err];
    if (err) {
        // handle
    }
    for (PIDInfo* pidInfo in processSet) {
        printf("%8d %s\n", pidInfo.pid.intValue, pidInfo.path.UTF8String);
        kern_return_t kr = 0;
        mach_port_name_t externalTask = 0;
        kr = task_for_pid(mach_task_self(), pidInfo.pid.intValue, &externalTask);
        
//        task_for_pid(externalTask(), <#int pid#>, <#mach_port_name_t *t#>)
        enumerate_loaded_modules(externalTask, ^(char *path, mach_vm_address_t start) {
            
            printf("%p - %s\n", start, path);
        });
//        assert(kr == KERN_SUCCESS);
//        NSError *error = NULL;
//        WAProcess *process = [[WAProcess alloc] initWithTask:externalTask error:&error];
//        for (WAModule *module in [process modules]) {
//
//
////            NSLog(@"%@", module);
//        }
    }
}


void printPIDs() {
    NSError *err = nil;
    NSSet <PIDInfo*>*pidSet = [[PIDManager sharedManager] getPIDsWithError:&err];
    for (PIDInfo* pidInfo in pidSet) {
        printf("%8d %s\n", pidInfo.pid.intValue, verbose ? pidInfo.path.UTF8String : pidInfo.name.UTF8String);
    }
}

void printPIDInfo(pid_t pid) {
    NSError *err = nil;
    NSSet <PIDInfo*>*pidSet = [[PIDManager sharedManager] getPIDsWithError:&err];
    for (PIDInfo* pidInfo in pidSet) {
        if (pid == pidInfo.pid.intValue) {
            printf("%8d %s\n", pidInfo.pid.intValue, pidInfo.path.UTF8String);
        }
    }
}

void printProcessesWithName(const char *name) {
    NSError *err = nil;
    NSSet <PIDInfo*>*processSet = [[PIDManager sharedManager] procesIDsForName:name error:&err];
    if (err) {
        // handle
    }
    for (PIDInfo* pidInfo in processSet) {
        printf("%8d %s\n", pidInfo.pid.intValue, pidInfo.path.UTF8String);
        kern_return_t kr = 0;
        mach_port_name_t externalTask = 0;
        kr = task_for_pid(mach_task_self(), pidInfo.pid.intValue, &externalTask);
        
        assert(kr == KERN_SUCCESS);
        NSError *error = NULL;
        WAProcess *process = [[WAProcess alloc] initWithTask:externalTask error:&error];
        for (WAModule *module in [process modules]) {
            
            
            NSLog(@"%@", module);
        }
    }
    
}

