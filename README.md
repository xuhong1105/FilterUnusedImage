# FilterUnusedImage
- Filter unused image from your iOS project.
- 过滤iOS项目中没有使用的图片

* [Examples 【示例】](#Examples)
```objc
NSString * projectPath = @"write your project path here";
AXUnusedImageFilter * filter = [[AXUnusedImageFilter alloc] initWithPath:projectPath];
filter.removeUnusedImage = YES;
filter.cleanPbxproj = YES;
filter.backupUnusedImage = YES;
[filter start];
```
