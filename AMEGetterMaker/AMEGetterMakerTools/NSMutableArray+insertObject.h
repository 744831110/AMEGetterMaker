//
//  NSMutableArray+insertObject.h
//  AMEGetterMaker
//
//  Created by 陈谦 on 2021/1/26.
//  Copyright © 2021 AME. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableArray (insertObject)

- (void)insertObjects:(NSArray *)objects atFirstIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
