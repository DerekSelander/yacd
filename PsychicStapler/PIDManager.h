//
//  PIDManager.h
//  WanaCore
//
//  Created by Derek Selander on 6/14/18.
//  Copyright © 2018 Selander. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PIDInfo.h"

/// Storer of the PIDInfos 
@interface PIDManager : NSObject

+ (PIDManager *)sharedManager;
- (NSSet <PIDInfo*> *)procesIDsForName:(char const *)name error:(NSError **)error;


- (NSSet <PIDInfo*> *)getPIDsWithError:(NSError **)error;

/// Path -> PIDInfo
- (NSDictionary <NSString*, PIDInfo*> *)runningProcessesWithError:(NSError **)error;

@end
