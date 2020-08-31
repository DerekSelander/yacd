//
//  NSError+ErrorHelper.h
//  yacd
//
//  Created by Derek Selander on 8/30/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSError (ErrorHelper)
+ (NSError*)errorWithDescription:(NSString *)description;
@end

NS_ASSUME_NONNULL_END
