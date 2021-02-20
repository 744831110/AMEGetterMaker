//
//  GetterTest.m
//  AMEGetterMakerTests
//
//  Created by 陈谦 on 2021/2/20.
//  Copyright © 2021 AME. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AMEGetterMaker.h"

@interface GetterTest : XCTestCase

@end

@implementation GetterTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *txtPath = [bundle pathForResource:@"amegetterError" ofType:@"txt"];
    NSString *content = [NSString stringWithContentsOfFile:txtPath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"content is %@",content);
    NSMutableArray<NSString *> *contentArray = [[content componentsSeparatedByString:@"\n"] mutableCopy];
    
    [[AMEGetterMaker shardMaker] makeGetter:contentArray selectStartLine:32 selectEndLine:38];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
