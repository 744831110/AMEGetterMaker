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
#import "AMEFileLineNumModel.h"
#import "NSMutableArray+insertObject.h"

static AMEGetterMaker * _ame_getter_maker;

@interface AMEGetterMaker()

@property (nonatomic, strong) NSMutableArray *lines;
@property (nonatomic, assign) NSInteger selectStartLine;
@property (nonatomic, assign) NSInteger selectEndLine;

@property (nonatomic, assign) NSInteger actionAndDelegateInsertIndex;
@property (nonatomic, strong) AMEFileLineNumModel *lineNumModel;
@property (nonatomic, strong) NSMutableArray<NSString *> *uiPodArray;

@end

@implementation AMEGetterMaker

+ (instancetype)shardMaker{
    @synchronized (self) {
        if (!_ame_getter_maker) {
            _ame_getter_maker = [AMEGetterMaker new];
        }
    }
    return _ame_getter_maker;
}

- (NSMutableArray<NSString *> *)selectLinesWithStart:(NSInteger)startLine endLine:(NSInteger)endLine{
    NSMutableArray * selectLines = [NSMutableArray arrayWithCapacity:endLine-startLine];
    for (NSInteger i = startLine; i<=endLine ; i++) {
//        //去掉分号
//        NSString * string = [self.lines[i] stringByReplacingOccurrencesOfString:@";" withString:@""];
        
        [selectLines addObject:self.lines[i]];
    }
    return selectLines;
}

- (void)makeGetter:(NSMutableArray *)lines selectStartLine:(NSInteger)selectStartLine selectEndLine:(NSInteger)selectEndLine {
    self.lines = lines;
    self.selectStartLine = selectStartLine;
    self.selectEndLine = selectEndLine;
    [self make];
}

- (void)make{
    //选中的起始行
    NSInteger startLine = self.selectStartLine;
    //选中的起始列
    NSInteger endLine   = self.selectEndLine;
    NSLog(@"cqtest start line is %ld end line is %ld", startLine, endLine);
    
    //遍历获取选中区域 获得选中区域的字符串数组
    NSMutableArray<NSString *> * selectLines = [self selectLinesWithStart:startLine endLine:endLine];
    NSLog(@"===========================");
    self.actionAndDelegateInsertIndex = -1;
    //按行处理 如果是objc就丢到十八层地狱 如果是swift就地处斩😈
    
    self.lineNumModel = [[AMEFileLineNumModel alloc] initWithLines:self.lines selectStartLine:startLine endStartLine:endLine];
    self.uiPodArray = @[@"ASUIConfig.h", @"Masonry.h"].mutableCopy;
    
    for (int i = 0 ; i < selectLines.count ; i++) {
        NSString * string = selectLines[i];
        NSLog(@"string is %@", string);
        //排除空字符串
        if(string == nil||[string isEqualToString:@""]){
            continue;
        }
        
        // 判断是否为属性
        AMEGetterMakerType type = [self typeJudgeWithString:string];
        NSLog(@"AMEGetterMakerType type is %lld", type);
        //排除注释和xib
        if (type != AMEGetterMakerTypeOther) {
            [self handlePropertyString:string type:type startLine:startLine endLine:endLine implementationEndLine:self.lineNumModel.implementationEndLineNum];
        } else {
            AMEImplementationType type = [self implementationTypeJudgeWithString:string];
            if(type != AMEGetterMakerTypeOther) {
                [self handleImplementString:string type:type];
            }
        }
    }
}

#pragma mark - Objective-C
#pragma mark impletation
- (void)handleImplementString:(NSString *)string type:(AMEImplementationType)type {
    if(type == AMEImplementationTypeObjc) {
        [self insertUiPod];
    }
}

- (void)insertUiPod {
    if(self.uiPodArray.count != 0) {
        NSInteger index = [self findInsertImportIndex];
        NSArray<NSString *> *array = [self objc_uiPod];
        [self.lines insertObjects:array atFirstIndex:index];
        [self.lineNumModel updateLines:self.lines];
    }
}

#pragma mark property
- (void)handlePropertyString:(NSString *)string type:(AMEGetterMakerType)type startLine:(NSInteger)startLine endLine:(NSInteger)endLine implementationEndLine:(NSInteger)implementationEndLine{
    NSString * getterResult =@"";
    //objc
    if (type == AMEGetterMakerTypeObjc) {
        AMEGetterModel *model = [self analysisPropertyLine:string];
        getterResult = [self objc_formatGetter:model];
        //找end并写入
        if (implementationEndLine <= 1) {
            return;
        }
        if(self.actionAndDelegateInsertIndex == -1) {
            self.actionAndDelegateInsertIndex = implementationEndLine;
        }
        [self.lines insertObject:getterResult atIndex:implementationEndLine];
        NSString *actionAndDelegate = [self objc_actionAndDelegate:model];
        if(actionAndDelegate) {
            [self.lines insertObject:actionAndDelegate atIndex:self.actionAndDelegateInsertIndex];
            [self.lineNumModel updateLines:self.lines];
        }
        if(model.isView) {
            NSInteger setupSubviewFunctionInsertIndex = [self findSetupSubviewFunctionEnd:YES];
            NSArray<NSString *> *constraintArray = [self objc_masonryConstraint:model];
            [self.lines insertObjects:constraintArray atFirstIndex:setupSubviewFunctionInsertIndex];
            [self.lineNumModel updateLines:self.lines];
            [self insertUiPod];
        }
    }else{
        //swift
        getterResult = [self swift_formatGetter:string];
        if (!getterResult || [getterResult isEqualToString:@""]) {
            return;
        }
        //找距离startline最近的相同行(因为行号会变)
        NSInteger currentLine = [self findCurrentLine:self.lines selectionStartLine:startLine currentString:string];
        //清除原行 添加懒加载代码
        self.lines[currentLine] = @"";
        [self.lines insertObject:getterResult atIndex:currentLine];
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

#pragma mark - find
- (NSInteger)findSetupSubviewFunctionEnd:(BOOL)isInsertWhenMiss {
    NSInteger setupSubviewline = [self.lineNumModel findString:@"- (void)setupSubview" startLine:self.lineNumModel.implementationLineNum];
    NSLog(@"cqtest  setupSubviewLine %ld", setupSubviewline);
    NSInteger insertIndex = 0;
    if(setupSubviewline == -1) {
        if(!isInsertWhenMiss) {
            return -1;
        }
        // 没有找到setupSubview，在impletement下的第一个方法后面创建一个
        NSInteger firstFunctionLine = [self.lineNumModel findRegex:@"- *\\([\\w]+\\) *[\\w]+ *{" startLine:self.lineNumModel.implementationLineNum];
        if(firstFunctionLine == -1) {
            firstFunctionLine = [self.lineNumModel findRegex:@"- *\\([\\w]+\\) *[\\w]+ *" startLine:self.lineNumModel.implementationLineNum]+1;
            if(firstFunctionLine == -1) {
                firstFunctionLine = self.lineNumModel.implementationLineNum;
            }
        }
        NSLog(@"cqtest  firstFunctionLine %ld", firstFunctionLine);
        NSInteger firstFunctionEndLine = [self.lineNumModel findPairChar:AMEFilePairCharFindTypeCurlyBrackets startLine:firstFunctionLine];
        NSLog(@"cqtest  firstFunctionEndLine %ld", firstFunctionEndLine);
        NSLog(@"cqtest  insertIndex %ld", insertIndex);
        NSString *line1 = [NSString stringWithFormat:@"- (void)setupSubview {"];
        NSString *line2 = [NSString stringWithFormat:@"\t<#add subview#>\n"];
        NSString *line3 = [NSString stringWithFormat:@"}"];
        [self.lines insertObjects:@[@"\n", line1, line2, line3] atFirstIndex:firstFunctionEndLine + 2];
        [self.lineNumModel updateLines:self.lines];
        insertIndex = [self.lineNumModel findPairChar:AMEFilePairCharFindTypeCurlyBrackets startLine:firstFunctionEndLine+3];
    } else {
        insertIndex = [self.lineNumModel findPairChar:AMEFilePairCharFindTypeCurlyBrackets startLine:setupSubviewline];
        NSLog(@"cqtest  insertIndex %ld", insertIndex);
    }
    return insertIndex;
}

- (NSInteger)findInterface:(BOOL)isInsertWhenMiss {
    NSInteger interfaceIndex = [self.lineNumModel findString:@"@interface " startLine:0];
    if(interfaceIndex == -1 && isInsertWhenMiss) {
        [self.lines insertObjects:[self objc_interface:self.lineNumModel.className] atFirstIndex:self.lineNumModel.implementationLineNum];
    }
    return interfaceIndex;
}

- (NSInteger)findInsertImportIndex {
    // 找到最后一个@import位置，同时清除已导入的UI库
    NSString *uiRegexFormatter = @"#import [\\\"|<][\\w]*%@[\\\"|>]";
    NSInteger lastIndex = 0;
    NSInteger index = 0;
    while (index != -1) {
        lastIndex = index;
        index = [self.lineNumModel findRegex:@"#import [\\\"|<][\\w\\.]+[\\\"|>]" startLine:lastIndex+1];
        if(index == -1) {
            break;
        }
        NSString *line = self.lines[index];
        
        NSArray *tempArray = [self.uiPodArray copy];
        for(int i = 0; i<tempArray.count; i++) {
            NSString *uipod = [tempArray objectAtIndex:i];
            NSString *regex = [NSString stringWithFormat:uiRegexFormatter, uipod];
            NSTextCheckingResult *result = [self.lineNumModel firstMatch:regex findString:line];
            if(result && result.range.location != NSNotFound) {
                [self.uiPodArray removeObject:uipod];
            }
        }
    }
    return lastIndex+1;
}

#pragma mark judge type
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

- (AMEImplementationType)implementationTypeJudgeWithString:(NSString *)string {
    if ([string hasSubString:@"//"] || [string hasSubString:@"/*"]|| [string hasSubString:@"*/"] || ([string hasSubString:@"IBOutlet"] && [string hasSubString:@"@"]) || (![string hasSubString:@"@interface"] && ![string hasSubString:@"@implementation"])) {
        return AMEImplementationTypeOther;
    }
    return AMEImplementationTypeObjc;
}

#pragma mark insert string
//输出的字符串_objc
- (NSString*)objc_formatGetter:(AMEGetterModel *)model{
    NSString *myResult;
    NSString *line1 = [NSString stringWithFormat:@"\n- (%@%@ *)%@{",model.className,model.childClass,model.propertyName];
    NSString *line2 = [NSString stringWithFormat:@"\n\tif(!%@){",model.underLineName];
    NSString *line3 = [NSString stringWithFormat:@"\n\t\t%@ = [[%@ alloc] init];",model.underLineName, model.className];
    NSString *line4 = [self objc_specialInitWithClassName:model];
    NSString *line7 = [NSString stringWithFormat:@"\n\t}"];
    NSString *line8 = [NSString stringWithFormat:@"\n\treturn %@;",model.underLineName];
    NSString *line9 = [NSString stringWithFormat:@"\n}"];
    
    
    myResult = [NSString stringWithFormat:@"%@%@%@%@%@%@%@",line1,line2,line3,line4 ?: @"",line7,line8,line9];
    
    return myResult;
}

- (NSArray<NSString *> *)objc_masonryConstraint:(AMEGetterModel *)model {
    NSString *line1 = [NSString stringWithFormat:@"\t[self.%@ mas_makeConstraints:^(MASConstraintMaker *make) {", model.propertyName];
    NSString *line2 = [NSString stringWithFormat:@"\t\t<#masonry constraint#>"];
    NSString *line3 = [NSString stringWithFormat:@"\t}];\n"];
    return @[line1, line2, line3];
}

- (NSString *)objc_actionAndDelegate:(AMEGetterModel *)model {
    NSString *result;
    if([model.className containsString:@"Button"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n- (void)%@Action:(%@%@ *)sender{",model.propertyName,model.className,model.childClass];
        NSString *line2 = [NSString stringWithFormat:@"\n\t<#action#>"];
        NSString *line3 = [NSString stringWithFormat:@"\n}"];
        result = [NSString stringWithFormat:@"%@%@%@", line1, line2, line3];
    }
    return result;
}

- (NSString *)objc_specialInitWithClassName:(AMEGetterModel *)model {
    NSString *string;
    if([model.className containsString:@"Label"]) {
        NSString *line1 = [NSString stringWithFormat:@"\n\t\t[%@ setFont:<#font#>];",model.underLineName];
        NSString *line2 = [NSString stringWithFormat:@"\n\t\t[%@ setTextColor:<#color#>];",model.underLineName];
        string = [NSString stringWithFormat:@"%@%@",line1,line2];
    } else if([model.className rangeOfString:@"Button" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSString *line1 = [NSString stringWithFormat:@"\n\t\t[%@ addTarget:self action:@selector(%@Action:) forControlEvents:UIControlEventTouchUpInside];",model.underLineName ,model.propertyName];
        string = [NSString stringWithFormat:@"%@", line1];
    } else if([model.className rangeOfString:@"StackView" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSString *line1 = [NSString stringWithFormat:@"\n\t\t[%@ setAxis:<#(UILayoutConstraintAxis)#>];",model.underLineName];
        NSString *line2 = [NSString stringWithFormat:@"\n\t\t[%@ setAlignment:<#(UIStackViewAlignment)#>];",model.underLineName];
        NSString *line3 = [NSString stringWithFormat:@"\n\t\t[%@ setDistribution:<#(UIStackViewDistribution)#>];",model.underLineName];
        string = [NSString stringWithFormat:@"%@%@%@", line1, line2, line3];
    } else if([model.className rangeOfString:@"TableView" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSString *line1 = [NSString stringWithFormat:@"\n\t\t[%@ setSeparatorStyle:UITableViewCellSeparatorStyleNone];",model.underLineName];
        NSString *line2 = [NSString stringWithFormat:@"\n\t\t[%@ setDelegate:self];",model.underLineName];
        NSString *line3 = [NSString stringWithFormat:@"\n\t\t[%@ setDataSource:self];",model.underLineName];
        // insert delegate and datasource in interface
        string = [NSString stringWithFormat:@"%@%@%@", line1, line2, line3];
    }
    return string;
}

- (NSArray<NSString *> *)objc_interface:(NSString *)className {
//    @interface EDUCorrectAssignmentViewController () <THMUploadViewDelegate, UIDocumentInteractionControllerDelegate> {
//        int64_t _recordId;
//        int64_t _classAssignmentId;
//    }
    NSString *line1 = [NSString stringWithFormat:@"@interface %@ ()\n", className];
    NSString *line2 = [NSString stringWithFormat:@"@end\n"];
    return @[line1, line2];
}

- (NSArray<NSString *> *)objc_uiPod {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for(NSString *uiPod in self.uiPodArray) {
        NSString *string = [NSString stringWithFormat:@"#import \"%@\"", uiPod];
        [result addObject:string];
    }
    return result.copy;
}

#pragma mark - Swift
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

- (NSInteger)findCurrentLine:(NSArray<NSString *> *)lines selectionStartLine:(NSInteger)startLine currentString:(NSString *)string{
    for (NSInteger i = startLine; i<lines.count; i++) {
        if ([lines[i] isEqualToString:string]) {
            return i;
        }
    }
    return 0;
}


// 自动创建setupSubview -
// 自动加布局到setupSubView -
// 加入添加布局库 -
// 导入相关库 并排序

@end
