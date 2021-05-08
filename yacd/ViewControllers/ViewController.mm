//
//  ViewController.m
//  PsychicPOC
//
//  Created by Derek Selander on 7/21/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <Security/Security.h>
#import <dlfcn.h>
#import <sys/mman.h>
#import <PsychicStapler/PsychicStapler.h>
#import "ViewController.h"
#import "ProcessDetailsViewController.h"
#import "UIViewController+DisplayError.h"
#import "ApplicationTableViewCell.h"

@interface ViewController () <UITableViewDataSource,  UISearchResultsUpdating>

@property (nonatomic, strong) NSDictionary <NSString*, PIDInfo*> *processDictionary;
@property (nonatomic, strong) NSArray <id<LSApplicationProxyProtocol>>*installedApplications;
@property (nonatomic, strong) NSArray <id<LSApplicationProxyProtocol>>* filteredInstalledApplications;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UISearchController* searchController;
@end

extern "C" {
int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
extern int mremap_encrypted(caddr_t addr, size_t len,
                            uint32_t cryptid, uint32_t cputype,
                            uint32_t cpusubtype);
};

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.obscuresBackgroundDuringPresentation = YES;
    _searchController.searchBar.placeholder = @"Filter";
    _searchController.dimsBackgroundDuringPresentation = YES;
    self.navigationItem.searchController = _searchController;
    self.definesPresentationContext = YES;
    [self refreshDataSource];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath* indexPath = [self.tableView indexPathForSelectedRow];
    ProcessDetailsViewController* vc = (ProcessDetailsViewController*)[segue destinationViewController];
    auto application = self.filteredInstalledApplications[indexPath.row];
    vc.application = application;
    auto pidInfo = self.processDictionary[application.canonicalExecutablePath];
    vc.pidInfo = pidInfo;
}

/********************************************************************************/
#pragma mark UITableViewDataSource
/********************************************************************************/

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    ApplicationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    auto application = self.filteredInstalledApplications[indexPath.row];
    
    auto path = [application canonicalExecutablePath];
    auto pidInfo = self.processDictionary[path];
    [cell setupCellWithApplicationProxy:application pidInfo:pidInfo];
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredInstalledApplications.count;
}
/********************************************************************************/
#pragma mark UISearchResultsUpdating
/********************************************************************************/

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.filteredInstalledApplications = [self filteredResults];
    [self.tableView reloadData];
}

/********************************************************************************/
#pragma mark Model methods
/********************************************************************************/

- (void)refreshDataSource {
    
    NSError *err = nil;
    self.processDictionary = [[PIDManager sharedManager] runningProcessesWithError:&err];
    if (err) {
        NSLog(@"%@", err);
    }

    id<LSApplicationWorkspaceProtocol> LSApplicationWorkspace = (id<LSApplicationWorkspaceProtocol>)NSClassFromString(@"LSApplicationWorkspace");
    self.installedApplications  = [[LSApplicationWorkspace defaultWorkspace] allApplications];
    self.filteredInstalledApplications = self.installedApplications;
    [self.tableView reloadData];
}

- (BOOL)needsUpdate {
    return _searchController.isActive && ![_searchController.searchBar.text isEqualToString:@""];
}

- (NSArray*)filteredResults {
    if (![self needsUpdate]) {
        return self.filteredInstalledApplications;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id<LSApplicationProxyProtocol> _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        NSString *appID = evaluatedObject.applicationIdentifier.lowercaseString;
        NSString *name = evaluatedObject.localizedName.lowercaseString;
        NSString *searchText = [[[self.searchController searchBar] text] lowercaseString];
        if ([appID containsString:searchText] || [name containsString:searchText]) {
            return YES;
        }
        return NO;
    }];
    
    return [self.installedApplications filteredArrayUsingPredicate:predicate];
}

/********************************************************************************/
#pragma mark IBActions
/********************************************************************************/

- (IBAction)reloadButtonTapped:(id)sender {
    [self refreshDataSource];
}

@end
