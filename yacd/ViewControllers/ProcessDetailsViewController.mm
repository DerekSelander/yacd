//
//  ProcessDetailsViewController.m
//  PsychicPOC
//
//  Created by Derek Selander on 8/2/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "ProcessDetailsViewController.h"
#import "ProcessModule.h"

#define YACD_DIR @"yacd"
#define ZIP_PAYLOAD @"payload.zip"

__attribute__((weak))
extern CGImageRef LICreateIconFromCachedBitmap(NSData* data);

@interface ProcessDetailsViewController () <UITableViewDataSource>
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSString *appPath;
@property (nonatomic, strong) NSArray<ProcessModule *> * dataSource;
@property (nonatomic, strong) NSArray<ProcessModule *> * sharedDataSource;
@property (nonatomic, assign) mach_port_t externalPort;
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
    NSRange appRange = [self.pidInfo.path rangeOfString:@".app/"];
    self.appPath = [self.pidInfo.path substringToIndex:appRange.location + appRange.length];

    if (!self.appPath) {
        [SVProgressHUD showErrorWithStatus:@"Application must be launched first"];
        return;
    }

    if (task_for_pid(mach_task_self(), self.pidInfo.pid.intValue, &_externalPort)) {
        [SVProgressHUD showErrorWithStatus:@"Unable to get task for PID"];
        return;
    }


    NSMutableArray *data = [NSMutableArray new];
    NSMutableArray *sharedData = [NSMutableArray new];
    BOOL success = enumerate_loaded_modules(_externalPort, ^(char *path, mach_vm_address_t module_start) {
        ProcessModule *processModule = [[ProcessModule alloc] initWithPath:path startAddress:module_start task:self.externalPort];
        
        
        if (processModule.isSharedCache) {
            [sharedData addObject:processModule];
        } else {
            [data addObject:processModule];
        }
    });
    
    if (!success) {
        [SVProgressHUD showErrorWithStatus:@"task_info error (System App)?"];
    }

    self.dataSource = [data copy];
    self.sharedDataSource = [sharedData copy];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"NON-Shared DYLD" : @"Shared DYLD";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return  section == 0 ? self.dataSource.count : self.sharedDataSource.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    
    ProcessModule *pm = indexPath.section == 0 ? self.dataSource[indexPath.row] :  self.sharedDataSource[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.minimumScaleFactor = 0.5;
    
    cell.textLabel.text = [pm.path lastPathComponent];
    NSNumber *addr = pm.address;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"0x%012lx", [addr unsignedLongValue]];
    return cell;
}

- (IBAction)decryptApplicationTapped:(id)sender {
    mach_port_name_t externalPort = MACH_PORT_NULL;
    ((UIButton*)sender).enabled = NO;
    
    if (task_for_pid(mach_task_self(), self.pidInfo.pid.intValue, &externalPort)) {
        [SVProgressHUD showErrorWithStatus:@"Unable to get task for PID"];
        return;
    }
    
    // Create the path to/from
    [SVProgressHUD showInfoWithStatus:@"Copying .app contents"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSError *err = nil;
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString* tmpDir = NSTemporaryDirectory();
        NSString *appName = [self.appPath lastPathComponent];
        NSString *copyToDir = [tmpDir stringByAppendingPathComponent:YACD_DIR];
        NSString *fullPathToDir = [copyToDir stringByAppendingPathComponent:appName];
        NSString *zippedPath = [tmpDir stringByAppendingPathComponent:[NSString stringWithFormat:@"Payload_%@.zip", self.application.bundleIdentifier]];
        [manager removeItemAtPath:copyToDir error:&err];
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
        [SVProgressHUD showInfoWithStatus:@"Patching encrypted modules"];
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
                [SVProgressHUD showErrorWithStatus:@"Error reading encrypted module"];
                free(payload);
                return;
            }
            
            // Patch file from decrypted mem
            if (!patch_encrypted_module_with_decrypted_memory((mach_vm_address_t)payload, cryptsize, cryptoff, realizedPath.UTF8String)) {
                [SVProgressHUD showErrorWithStatus:@"Error replacing memory"];
            }
            free(payload);
        });
        
        [self zipAndShare:zippedPath withContents:fullPathToDir];
        dispatch_async(dispatch_get_main_queue(), ^{
            ((UIButton*)sender).enabled = YES;
        });
    });
}

- (void)zipAndShare:(NSString *)zippedPath withContents:(NSString *)contents  {
    [SVProgressHUD showInfoWithStatus:@"Zipping contents"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        BOOL success = [SSZipArchive createZipFileAtPath:zippedPath withContentsOfDirectory:contents keepParentDirectory:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                NSURL *url = [NSURL fileURLWithPath:zippedPath];
                
                NSData *data = [self.application primaryIconDataForVariant:0x11];
                CGImageRef imageRef = LICreateIconFromCachedBitmap(data);
                CGFloat scale = [UIScreen mainScreen].scale;
                UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
                
                UIActivity *airdropActivity = [[AirdropOnlyActivity alloc] initWithImage:image appName:self.application.bundleIdentifier];
                UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:@[airdropActivity]];
                
                [self presentViewController:activityViewController animated:YES completion:nil];
            } else {
                [SVProgressHUD showErrorWithStatus:@"Zipping problem"];
            }
            
        });
    });
}

- (NSString *)resolvePathToZippedPath:(NSString*)fullPath {
    NSRange range = [fullPath rangeOfString:self.appPath];
    NSString *relativePath = [fullPath substringFromIndex:range.length];
    NSString *realizedPath = [self.pathToDir stringByAppendingPathComponent:relativePath];
    return realizedPath;
}

- (NSString*)pathToDir {
    static NSString *_pathToDir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
    NSString* tmpDir = NSTemporaryDirectory();
    NSString *appName = [self.appPath lastPathComponent];
    NSString *copyToDir = [tmpDir stringByAppendingPathComponent:YACD_DIR];
    NSString *fullPathToDir = [copyToDir stringByAppendingPathComponent:appName];
        _pathToDir = fullPathToDir;
    });
    
    return _pathToDir;
}

@end
