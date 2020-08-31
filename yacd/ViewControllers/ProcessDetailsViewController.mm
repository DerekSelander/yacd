//
//  ProcessDetailsViewController.m
//  PsychicPOC
//
//  Created by Derek Selander on 8/2/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "ProcessDetailsViewController.h"
#import <PsychicStapler/PsychicStapler.h>
#import "UIViewController+DisplayError.h"
#import "SSZipArchive.h"
#import "NSError+ErrorHelper.h"

#define YACD_DIR @"yacd"
#define ZIP_PAYLOAD @"payload.zip"

@interface ProcessDetailsViewController () <UITableViewDataSource>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSString *appPath;
@property (nonatomic, strong) NSArray<NSDictionary*> * dataSource;
@property (nonatomic, assign) mach_port_name_t externalPort;
@end

extern "C" {
int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
extern int mremap_encrypted(caddr_t addr, size_t len,
                            uint32_t cryptid, uint32_t cputype,
                            uint32_t cpusubtype);
};

@implementation ProcessDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSError *err = nil;
//    mach_port_name_t externalPort = MACH_PORT_NULL;
    self.appPath = [self.pidInfo.path
                    stringByDeletingLastPathComponent];

    if (!self.appPath) {
        err = [NSError errorWithDescription:@"Malformed process"];
        [self displayModalErrorWithMessage:@"Error" andError:err];
        return;
    }

    if (task_for_pid(mach_task_self(), self.pidInfo.pid.intValue, &_externalPort)) {
        err = [NSError errorWithDescription:@"Unable to get task_for_pid"];
        [self displayModalErrorWithMessage:@"Error" andError:err];
        return;
    }


    NSMutableArray *data = [NSMutableArray new];
    ::enumerate_encrypted_modules(_externalPort, ^(char *path,  mach_vm_address_t module_start, uint32_t cryptoff, uint32_t cryptsize) {
 
        [data addObject:@{ @"module" : [NSString stringWithUTF8String:path], @"addr" : @(module_start)}];
    });

    self.dataSource = [data copy];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}


- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    NSDictionary *dict = self.dataSource[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.minimumScaleFactor = 0.5;
    cell.textLabel.text = [dict[@"module"] lastPathComponent];
    NSNumber *addr = dict[@"addr"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"0x%012lx", [addr unsignedLongValue]];
    return cell;
}

- (IBAction)decryptApplicationTapped:(id)sender {
    NSError *err = nil;
    mach_port_name_t externalPort = MACH_PORT_NULL;
    
    if (task_for_pid(mach_task_self(), self.pidInfo.pid.intValue, &externalPort)) {
        err = [NSError errorWithDescription:@"Unable to get task_for_pid"];
        [self displayModalErrorWithMessage:@"Error" andError:err];
        return;
    }
    
    // Create the path to/from
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString* tmpDir = NSTemporaryDirectory();
    NSString *appName = [self.appPath lastPathComponent];
    NSString *copyToDir = [tmpDir stringByAppendingPathComponent:YACD_DIR];
    NSString *fullPathToDir = [copyToDir stringByAppendingPathComponent:appName];
    NSString *zippedPath = [tmpDir stringByAppendingPathComponent:ZIP_PAYLOAD];
    
    [manager removeItemAtPath:fullPathToDir error:&err];
    if (err) {
        NSLog(@"%@", err);
        err = nil;
    }
    
    [manager createDirectoryAtPath:copyToDir withIntermediateDirectories:YES attributes:nil error:&err];
    if (err) {
        NSLog(@"%@", err);
        err = nil;
    }
    
    if (![manager  copyItemAtPath:self.appPath toPath:fullPathToDir error:&err]) {
        if (err) {
            NSLog(@"%@", err);
        }
    }

    // Replica at fullPathToDir, cross reference memory in process and grab decrypted parts
    
    ::enumerate_encrypted_modules(externalPort, ^(char *path,  mach_vm_address_t module_start, uint32_t cryptoff, uint32_t cryptsize) {
        
        
        NSString *fullPath = [NSString stringWithUTF8String:path];
        NSRange range = [fullPath rangeOfString:self.appPath];
        NSString *relativePath = [fullPath substringFromIndex:range.length];
        NSString *realizedPath = [fullPathToDir stringByAppendingPathComponent:relativePath];
        
        // Grab the decrypted payload
        void* payload = calloc(cryptsize, sizeof(char));
        mach_vm_size_t outsize = cryptsize;
        kern_return_t kr = mach_vm_read_overwrite(self->_externalPort, module_start + cryptoff  + sizeof(struct mach_header_64), cryptsize, (mach_vm_address_t)payload, &outsize);
        
        if (kr != KERN_SUCCESS || outsize != cryptsize) {
            NSError *err = [NSError errorWithDescription:@"Error Patching"];
            [self displayModalErrorWithMessage:@"Error" andError:err];
            free(payload);
            return;
        }
        
        // Patch file from decrypted mem
        if (!patch_encrypted_module_with_decrypted_memory((mach_vm_address_t)payload, cryptsize, cryptoff, realizedPath.UTF8String)) {
            NSError *err = [NSError errorWithDescription:@"Error Replacing Decrypted Memory"];
            [self displayModalErrorWithMessage:@"Error" andError:err];
        }
        free(payload);
    });
    
    [self zipAndShare:zippedPath withContents:fullPathToDir];
}

- (void)zipAndShare:(NSString *)zippedPath withContents:(NSString *)contents {
    if ([SSZipArchive createZipFileAtPath:zippedPath withContentsOfDirectory:contents keepParentDirectory:YES]) {
        NSURL *url = [NSURL fileURLWithPath:zippedPath];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        [self presentViewController:activityViewController animated:YES completion:nil];
    } else {
        NSError *err = [NSError errorWithDescription:@"Zipping problem"];
        [self displayModalErrorWithMessage:@"Error" andError:err];
    }
}

@end
