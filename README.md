# FilterUnusedImage
## Features【能做什么】
- Filter and remove unused image from your iOS project.
- Auto clean project.pbxproj file.
- Backup unused image before removing.
- Custom extension of files which need to be retrieved.

- 过滤并删除iOS项目中没有使用的图片.
- 自动清理project.pbxproj文件.
- 备份没有使用的图片.
- 自定义需要检索的源文件的扩展名.
## Examples【示例】
```objc
NSString * projectPath = @"write your project path here";
AXUnusedImageFilter * filter = [[AXUnusedImageFilter alloc] initWithPath:projectPath];
filter.removeUnusedImage = YES;
filter.cleanPbxproj = YES;
filter.backupUnusedImage = YES;
[filter start];
```
