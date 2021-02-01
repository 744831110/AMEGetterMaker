//
//  AMEFileLineNumModel.m
//  GetterMaker
//
//  Created by 陈谦 on 2021/1/8.
//  Copyright © 2021 AME. All rights reserved.
//

#import "AMEFileLineNumModel.h"

@interface AMEFileLineNumModel()

@property (nonatomic, assign) NSInteger startLine;
@property (nonatomic, assign) NSInteger endLine;
@property (nonatomic, copy) NSArray<NSString *> *lines;

@property (nonatomic, assign, readwrite) NSInteger interfaceLineNum;
@property (nonatomic, assign, readwrite) NSInteger implementationLineNum;
@property (nonatomic, assign, readwrite) NSInteger implementationEndLineNum;
@property (nonatomic, copy, readwrite) NSString *className;

@end

@implementation AMEFileLineNumModel

- (instancetype)initWithLines:(NSArray<NSString *> *)lines selectStartLine:(NSInteger)startLine endStartLine:(NSInteger)endLine {
    if(self = [super init]) {
        self.lines = lines;
        self.startLine = startLine;
        self.endLine = endLine;
        [self findLineNum];
    }
    return self;
}

- (void)updateLines:(NSArray<NSString *> *)lines {
    self.lines = lines;
    [self findLineNum];
}

- (void)findLineNum {
    //找interface确认类名
    NSString * interfaceLine = @"";
    for (NSInteger i = self.endLine; i >= 1; i--) {
        if ([self.lines[i] rangeOfString:@"@interface"].location != NSNotFound) {
            interfaceLine = self.lines[i];
            self.interfaceLineNum = i;
            break;
        }
    }
    NSLog(@"AMEFileLineNumModel interface line is %@", interfaceLine);
    NSLog(@"AMEFileLineNumModel interface line num %ld", self.interfaceLineNum);
    NSRange rangeInterface = [interfaceLine rangeOfString:@"@interface"];
    NSRange rangeLeftBracket = [interfaceLine rangeOfString:@"("];
    NSRange classWithSpaceRange = NSMakeRange(rangeInterface.location + rangeInterface.length, interfaceLine.length - rangeInterface.length - rangeInterface.location - (interfaceLine.length - rangeLeftBracket.location));
    NSString * classWithSpace = [interfaceLine substringWithRange:classWithSpaceRange];
    //类名
    NSString * classStr = [classWithSpace stringByReplacingOccurrencesOfString:@" " withString:@""];
    self.className = classStr;
    NSLog(@"AMEFileLineNumModel classStr is %@", classStr);
    //根据类名找implementation
    BOOL findMark = NO;
    for (NSInteger i = self.endLine; i < self.lines.count; i++) {
        if ([self.lines[i] rangeOfString:@"@implementation"].location != NSNotFound &&
            [self.lines[i] rangeOfString:classStr].location != NSNotFound) {
            findMark = YES;
            self.implementationLineNum = i;
            continue;
        }
        if (findMark && [self.lines[i] rangeOfString:@"@end"].location != NSNotFound) {
            self.implementationEndLineNum = i;
        }
    }
    NSLog(@"AMEFileLineNumModel implementationLineNum is %lld implementationEndLineNum is %lld", self.implementationLineNum, self.implementationEndLineNum);
}

- (NSInteger)findString:(NSString *)string {
    return [self findString:string startLine:0];
}

- (NSInteger)findString:(NSString *)string startLine:(NSInteger)startLine {
    for(NSInteger i = startLine; i<self.lines.count; i++) {
        NSString *line = self.lines[i];
        if([line rangeOfString:string].location != NSNotFound) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)findPairChar:(AMEFilePairCharFindType)type startLine:(NSInteger)startLine{
    switch (type) {
        case AMEFilePairCharFindTypeParentheses:
            return [self findPairStringWithLeft:@"(" right:@")" regex:@"\\(|\\)" startLine:startLine];
        case AMEFilePairCharFindTypeAngleBrackets:
            return [self findPairStringWithLeft:@"<" right:@">" regex:@"\\<|\\>" startLine:startLine];
        case AMEFilePairCharFindTypeCurlyBrackets:
            return [self findPairStringWithLeft:@"{" right:@"}" regex:@"\\{|\\}" startLine:startLine];
        case AMEFilePairCharFindTypeSquareBrackets:
            return [self findPairStringWithLeft:@"[" right:@"]" regex:@"\\[|\\]" startLine:startLine];
        default:
            break;
    }
}

- (NSInteger)findPairStringWithLeft:(NSString *)leftString right:(NSString *)rightString regex:(NSString *)regex startLine:(NSInteger)startLine {
    int count = 0;
    for(NSInteger i = startLine; i<self.lines.count; i++) {
        NSString *line = self.lines[i];
        NSArray<NSTextCheckingResult *> *array = [self match:regex findString:line];
        for(NSTextCheckingResult *result in array) {
            NSRange range = result.range;
            NSString *subString = [line substringWithRange:range];
            if([leftString isEqualToString:subString]) {
                count++;
            } else if([rightString isEqualToString:subString]) {
                count--;
            }
            if(count == 0) {
                break;
            }
        }
        if(count == 0) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)findRegex:(NSString *)string {
    return [self findRegex:string startLine:0];
}

- (NSInteger)findRegex:(NSString *)string startLine:(NSInteger)startLine {
    for(NSInteger i = startLine; i<self.lines.count; i++) {
        NSString *line = self.lines[i];
        NSTextCheckingResult *result = [self firstMatch:string findString:line];
        if(result && result.range.location != NSNotFound) {
            return i;
        }
    }
    return -1;
}

- (NSTextCheckingResult *)firstMatch:(NSString *)regularString findString:(NSString *)findString {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regularString options:NSRegularExpressionCaseInsensitive error:&error];
    if(!error) {
        return [regex firstMatchInString:findString options:NSMatchingReportProgress range:NSMakeRange(0, findString.length)];
    }
    return nil;
}

- (NSArray<NSTextCheckingResult *> *)match:(NSString *)regularString findString:(NSString *)findString {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regularString options:NSRegularExpressionCaseInsensitive error:&error];
    
    if(!error) {
        return [regex matchesInString:findString options:NSMatchingReportProgress range:NSMakeRange(0, findString.length)];
    }
    return nil;
}

@end
