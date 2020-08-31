//
//  NSError+ErrorHelper.m
//  yacd
//
//  Created by Derek Selander on 8/30/20.
//  Copyright © 2020 Selander. All rights reserved.
//

#import "NSError+ErrorHelper.h"

@implementation NSError (ErrorHelper)

+ (NSError*)errorWithDescription:(NSString *)description {
    NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : description};
    NSError *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain
                   code:errno userInfo:errorDictionary];
    return error;
}

@end
