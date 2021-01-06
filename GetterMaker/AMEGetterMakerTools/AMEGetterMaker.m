//
//  AMEGetterMaker.m
//  AMEGetterMaker
//
//  Created by pc37 on 2017/8/30.
//  Copyright © 2017年 AME. All rights reserved.
//

#import "AMEGetterMaker.h"
#import "NSString+AMEGetterMaker.h"
#import "AMEGetterModel.h"

static AMEGetterMaker * _ame_getter_maker;
@implementation AMEGetterMaker

+ (instancetype)shardMaker{
    @synchronized (self) {
        if (!_ame_getter_maker) {
            _ame_getter_maker = [AMEGetterMaker new];
        }
    }
    return _ame_getter_maker;
}

- (AMEGetterMakerType)typeJudgeWithString:(NSString *)string{
    //注释 或者Xib 或者不带var property的注释夹层
    if ([string hasSubString:@"//"] || [string hasSubString:@"/*"]|| [string hasSubString:@"*/"] || ([string hasSubString:@"IBOutlet"] && [string hasSubString:@"@"]) || (![string hasSubString:@"@property"] && ![string hasSubString:@"var"])) {
        return AMEGetterMakerTypeOther;
    }
    if ([string hasSubString:@"@property"]) {
        return AMEGetterMakerTypeObjc;
    }
    if([string hasSubString:@"var"]){
        //swift
        return AMEGetterMakerTypeSwift;
    }
    return AMEGetterMakerTypeOther;
}

- (NSMutableArray<NSString *> *)selectLinesWithStart:(NSInteger)startLine endLine:(NSInteger)endLine{
    NSMutableArray * selectLines = [NSMutableArray arrayWithCapacity:endLine-startLine];
    for (NSInteger i = startLine; i<=endLine ; i++) {
//        //去掉分号
//        NSString * string = [self.invocation.buffer.lines[i] stringByReplacingOccurrencesOfString:@";" withString:@""];
        
        [selectLines addObject:self.invocation.buffer.lines[i]];
    }
    return selectLines;
}


- (void)makeGetter:(XCSourceEditorCommandInvocation *)invocation{
    self.invocation = invocation;
    [self make];
}

- (void)make{
    for (XCSourceTextRange *range in self.invocation.buffer.selections) {
        //选中的起始行
        NSInteger startLine = range.start.line;
        //选中的起始列
        NSInteger endLine   = range.end.line;
        NSLog(@"cqtest start line is %ld end line is %ld", startLine, endLine);
        
        //遍历获取选中区域 获得选中区域的字符串数组
        NSMutableArray<NSString *> * selectLines = [self selectLinesWithStart:startLine endLine:endLine];
        NSLog(@"===========================");
        NSInteger actionAndDelegateInsertIndex = -1;
        //按行处理 如果是objc就丢到十八层地狱 如果是swift就地处斩😈
        for (int i = 0 ; i < selectLines.count ; i++) {
            NSString * string = selectLines[i];
            if(i == 0)
            NSLog(@"cqtest string is %@", string);
            //排除空字符串
            if(string == nil||[string isEqualToString:@""]){
                continue;
            }
            AMEGetterMakerType type = [self typeJudgeWithString:string];
            //排除注释和xib
            if (type == AMEGetterMakerTypeOther) {
                continue;
            }
            NSString * getterResult =@"";
            //objc
            if (type == AMEGetterMakerTypeObjc) {
                AMEGetterModel *model = [self analysisPropertyLine:string];
                getterResult = [self objc_formatGetter:model];
                //找end并写入
                NSInteger implementationEndLine = [self findEndLine:self.invocation.buffer.lines selectionEndLine:endLine];
                if (implementationEndLine <= 1) {
                    continue;
                }
                if(i == 0) {
                    actionAndDelegateInsertIndex = implementationEndLine;
                }
                [self.invocation.buffer.lines insertObject:getterResult atIndex:implementationEndLine];
                NSString *actionAndDelegate = [self objc_actionAndDelegate:model];
                if(actionAndDelegate) {
                    [self.invocation.buffer.lines insertObject:actionAndDelegate atIndex:actionAndDelegateInsertIndex];
                }
            }else{
                //swift
                getterResult = [self swift_formatGetter:string];
                if (!getterResult || [getterResult isEqualToString:@""]) {
                    continue;
                }
                //找距离startline最近的相同行(因为行号会变)
                NSInteger currentLine = [self findCurrentLine:self.invocation.buffer.lines selectionStartLine:startLine currentString:string];
                //清除原行 添加懒加载代码
                self.invocation.buffer.lines[currentLine] = @"";
                [self.invocation.buffer.lines insertObject:getterResult atIndex:currentLine];
            }
        }
    }
}

- (AMEGetterModel *)analysisPropertyLine:(NSString *)sourceStr {
    //@property (nonatomic, strong) NSArray<TJSDestinationModel *> * dataArray
    //类名
    NSString * className = [sourceStr getStringWithOutSpaceBetweenString1:@")" options1:0 string2:@"*" options2:NSBackwardsSearch];
    NSLog(@"className--->%@",className);
    if ([className isEqualToString:@""]) {
        return [[AMEGetterModel alloc] init];
    }
    NSString * childClass = @"";
    if ([className hasSubString:@"<"] && [className hasSubString:@">"]) {
        childClass = [NSString stringWithFormat:@"<%@>",[className getStringWithOutSpaceBetweenString1:@"<" options1:0 string2:@">" options2:NSBackwardsSearch]];
        className = [className stringByReplacingOccurrencesOfString:childClass withString:@""];
        childClass = [childClass stringByReplacingOccurrencesOfString:@"*" withString:@" *"];
    }
    NSLog(@"childClass---->%@",childClass);
    NSLog(@"resetClassName--->%@",className);
    //属性名
    NSString * uName = [sourceStr getStringWithOutSpaceBetweenString1:@"*" options1:NSBackwardsSearch string2:@";" options2:NSBackwardsSearch];
    if ([uName isEqualToString:@""]) {
        return [[AMEGetterModel alloc] init];
    }
    NSLog(@"uName--->%@",uName);
    //_属性名
    NSString *underLineName=[NSString stringWithFormat:@"_%@",uName];
    AMEGetterModel *model = [[AMEGetterModel alloc] init];
    model.className = className;
    model.childClass = childClass;
    model.underLineName = underLineName;
    model.propertyName = uName;
    return model;
}

//输出的字符串_objc
- (NSString*)objc_formatGetter:(AMEGetterModel *)model{
    NSString *myResult;
    NSString *line1 = [NSString stringWithFormat:@"\n- (%@%@ *)%@{",model.className,model.childClass,model.propertyName];
    NSString *line2 = [NSString stringWithFormat:@"\n    if(!%@){",model.underLineName];
    NSString *line3 = [NSString stringWithFormat:@"\n          %@ = [[%@ alloc] init];",model.underLineName, model.className];
    NSString *line4 = [self objc_specialInitWithClassName:model];
    NSString *line7 = [NSString stringWithFormat:@"\n    }"];
    NSString *line8 = [NSString stringWithFormat:@"\n    return %@;",model.underLineName];
    NSString *line9 = [NSString stringWithFormat:@"\n}"];
    
    
    myResult = [NSString stringWithFormat:@"%@%@%@%@%@%@%@",line1,line2,line3,line4 ?: @"",line7,line8,line9];
    
    return myResult;
}

- (NSString *)objc_actionAndDelegate:(AMEGetterModel *)model {
    NSString *result;
    if([model.className containsString:@"Button"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n- (void)%@Action:(%@%@ *)sender{",model.propertyName,model.className,model.childClass];
        NSString *line2 = [NSString stringWithFormat:@"\n    <#action#>"];
        NSString *line3 = [NSString stringWithFormat:@"\n}"];
        result = [NSString stringWithFormat:@"%@%@%@", line1, line2, line3];
    }
    return result;
}

- (NSString *)objc_specialInitWithClassName:(AMEGetterModel *)model {
    NSString *string;
    if([model.className containsString:@"Label"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n          [%@ setFont:<#font#>];",model.underLineName];
        NSString *line2 = [NSString stringWithFormat:@"\n          [%@ setTextColor:<#color#>];",model.underLineName];
        string = [NSString stringWithFormat:@"%@%@",line1,line2];
    } else if([model.className containsString:@"Button"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n          [%@ addTarget:self action:@selector(%@Action:) forControlEvents:UIControlEventTouchUpInside];",model.underLineName ,model.propertyName];
        string = [NSString stringWithFormat:@"%@", line1];
    } else if([model.className containsString:@"StackView"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n          [%@ setAxis:<#(UILayoutConstraintAxis)#>];",model.underLineName];
        NSString *line2 = [NSString stringWithFormat:@"\n          [%@ setAlignment:<#(UIStackViewAlignment)#>];",model.underLineName];
        NSString *line3 = [NSString stringWithFormat:@"\n          [%@ setDistribution:<#(UIStackViewDistribution)#>];",model.underLineName];
        string = [NSString stringWithFormat:@"%@%@%@", line1, line2, line3];
    } else if([model.className containsString:@"TableView"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n          [%@ setSeparatorStyle:UITableViewCellSeparatorStyleNone];",model.underLineName];
        NSString *line2 = [NSString stringWithFormat:@"\n          [%@ setDelegate:self];",model.underLineName];
        NSString *line3 = [NSString stringWithFormat:@"\n          [%@ setDataSource:self];",model.underLineName];
        string = [NSString stringWithFormat:@"%@%@%@", line1, line2, line3];
    }
    return string;
}

//输出的字符串_swift
- (NSString*)swift_formatGetter:(NSString*)sourceStr{
    NSString *myResult = @"";
    //取类名 有等号或者有冒号
    NSString * className = @"";
    NSString * typeName = @"";
    if ([sourceStr hasSubString:@"="] && [sourceStr hasSubString:@"("]&& [sourceStr hasSubString:@")"]) {
        className = [sourceStr getStringWithOutSpaceBetweenString1:@"=" string2:@"("];
        if ([sourceStr hasSubString:@":"]) {
            typeName = [sourceStr getStringWithOutSpaceBetweenString1:@"var" string2:@":"];
        }else{
            typeName = [sourceStr getStringWithOutSpaceBetweenString1:@"var" string2:@"="];
        }
    }else if ([sourceStr hasSubString:@":"] && [sourceStr hasSubString:@"!"]){
        className = [sourceStr getStringWithOutSpaceBetweenString1:@":" string2:@"!"];
        typeName = [sourceStr getStringWithOutSpaceBetweenString1:@"var" string2:@":"];
    }else{
        NSLog(@"错误的格式或者对象");
        return nil;
    }
    NSLog(@"className----->%@",className);
    NSLog(@"typeName----->%@",typeName);
    if ([className isEqualToString:@""]) {
        return nil;
    }
    if ([typeName isEqualToString:@""]) {
        return nil;
    }
    NSString * line1 = [NSString stringWithFormat:@"\tlazy var %@ : %@ = {", typeName, className];
    NSString * line2 = [NSString stringWithFormat:@"\n\t\tlet object = %@()",className];
    NSString * line3 = [NSString stringWithFormat:@"\n\t\treturn object"];
    NSString * line4 = [NSString stringWithFormat:@"\n\t}()"];
    myResult = [NSString stringWithFormat:@"%@%@%@%@",line1,line2,line3,line4];
    NSLog(@"myResult---->%@",myResult);
    return myResult;
}

- (NSInteger)findEndLine:(NSArray<NSString *> *)lines selectionEndLine:(NSInteger)endLine{
    //找interface确认类名
    NSString * interfaceLine = @"";
    for (NSInteger i = endLine; i >= 1; i--) {
        if ([lines[i] rangeOfString:@"@interface"].location != NSNotFound) {
            interfaceLine = lines[i];
            break;
        }
    }
    NSRange rangeInterface = [interfaceLine rangeOfString:@"@interface"];
    NSRange rangeLeftBracket = [interfaceLine rangeOfString:@"("];
    NSRange classWithSpaceRange = NSMakeRange(rangeInterface.location + rangeInterface.length, interfaceLine.length - rangeInterface.length - rangeInterface.location - (interfaceLine.length - rangeLeftBracket.location));
    NSString * classWithSpace = [interfaceLine substringWithRange:classWithSpaceRange];
    NSLog(@"%@",classWithSpace);
    //类名
    NSString * classStr = [classWithSpace stringByReplacingOccurrencesOfString:@" " withString:@""];
    //根据类名找implementation
    BOOL findMark = NO;
    for (NSInteger i = endLine; i < lines.count; i++) {
        if ([lines[i] rangeOfString:@"@implementation"].location != NSNotFound &&
            [lines[i] rangeOfString:classStr].location != NSNotFound) {
            findMark = YES;
            continue;
        }
        if (findMark && [lines[i] rangeOfString:@"@end"].location != NSNotFound) {
            return i;
        }
    }
    return 0;
}

- (NSInteger)findCurrentLine:(NSArray<NSString *> *)lines selectionStartLine:(NSInteger)startLine currentString:(NSString *)string{
    for (NSInteger i = startLine; i<lines.count; i++) {
        if ([lines[i] isEqualToString:string]) {
            return i;
        }
    }
    return 0;
}

//自动创建setupSubview
// 自动加布局到setupSubView
// 自动添加#pragma mark -

@end
