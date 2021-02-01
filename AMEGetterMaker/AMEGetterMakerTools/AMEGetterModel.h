//
//  AMEGetterModel.h
//  GetterMaker
//
//  Created by 陈谦 on 2021/1/6.
//  Copyright © 2021 AME. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AMEGetterModel : NSObject

// @property (nonatomic, copy) NSArray<NSString *> *array;

// NSArray
@property (nonatomic, copy) NSString *className;
// NSString
@property (nonatomic, copy) NSString *childClass;
// array
@property (nonatomic, copy) NSString *propertyName;
// _array
@property (nonatomic, copy) NSString *underLineName;

@property (nonatomic, assign, readonly) BOOL isView;

@end

NS_ASSUME_NONNULL_END
