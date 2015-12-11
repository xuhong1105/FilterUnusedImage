# FilterUnusedImage
Filter unused image from your iOS project.过滤iOS项目中没有使用的图片
Example:
    NSString * projectPath = @"write your project path here";
    AXFilterImage * filter = [[AXFilterImage alloc] initWithPath:projectPath];
    filter.removeUnusedImage = YES;
    filter.cleanPbxproj = YES;
    filter.saveUnusedImage = YES;
    [filter start];
