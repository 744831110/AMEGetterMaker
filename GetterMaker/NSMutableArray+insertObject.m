//
//  NSMutableArray+insertObject.m
//  AMEGetterMaker
//
//  Created by 陈谦 on 2021/1/26.
//  Copyright © 2021 AME. All rights reserved.
//

#import "NSMutableArray+insertObject.h"

@implementation NSMutableArray (insertObject)

- (void)insertObjects:(NSArray *)objects atFirstIndex:(NSUInteger)index {
    NSUInteger flag = index;
    for(id obj in objects) {
        [self insertObject:obj atIndex:flag];
        flag++;
    }
}

@end
