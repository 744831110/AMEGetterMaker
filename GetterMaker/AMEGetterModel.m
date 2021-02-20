//
//  AMEGetterModel.m
//  GetterMaker
//
//  Created by 陈谦 on 2021/1/6.
//  Copyright © 2021 AME. All rights reserved.
//

#import "AMEGetterModel.h"

@implementation AMEGetterModel

- (BOOL)isView {
    NSArray<NSString *> *array = @[
        @"view",
        @"label",
        @"button",
        @"switch",
        @"slider",
        @"textField",
        @"bar"
    ];
    for(NSString *suffix in array) {
        if([self.className rangeOfString:suffix options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isViewController {
    if([self.className rangeOfString:@"viewController" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    return NO;
}

@end
