//
//  AMEFileLineNumModel.h
//  GetterMaker
//
//  Created by 陈谦 on 2021/1/8.
//  Copyright © 2021 AME. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AMEFilePairCharFindType) {
    /// ()
    AMEFilePairCharFindTypeParentheses,
    /// []
    AMEFilePairCharFindTypeSquareBrackets,
    /// {}
    AMEFilePairCharFindTypeCurlyBrackets,
    /// <>
    AMEFilePairCharFindTypeAngleBrackets
    
};

@interface AMEFileLineNumModel : NSObject

@property (nonatomic, assign, readonly) NSInteger interfaceLineNum;
@property (nonatomic, assign, readonly) NSInteger implementationLineNum;
@property (nonatomic, assign, readonly) NSInteger implementationEndLineNum;
@property (nonatomic, copy, readonly) NSString *className;

- (instancetype)initWithLines:(NSArray<NSString *> *)lines selectStartLine:(NSInteger)startLine endStartLine:(NSInteger)endLine;

- (void)updateLines:(NSArray<NSString *> *)lines;

- (NSInteger)findPairStringWithLeft:(NSString *)leftString right:(NSString *)rightString regex:(NSString *)regex startLine:(NSInteger)startLine;
- (NSInteger)findString:(NSString *)string;
- (NSInteger)findString:(NSString *)string startLine:(NSInteger)startLine;
- (NSInteger)findRegex:(NSString *)string;
- (NSInteger)findRegex:(NSString *)string startLine:(NSInteger)startLine;
- (NSInteger)findPairChar:(AMEFilePairCharFindType)type startLine:(NSInteger)startLine;
- (NSTextCheckingResult *)firstMatch:(NSString *)regularString findString:(NSString *)findString;

@end

NS_ASSUME_NONNULL_END
