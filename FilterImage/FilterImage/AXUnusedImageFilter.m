//
//  AXUnusedImageFilter.m
//  FilterImage
//
//  Created by Allen on 15/12/9.
//  Copyright © 2015年 Allen. All rights reserved.
//

#import "AXUnusedImageFilter.h"
#import <mach/mach_time.h>
#import "AXImage.h"

double MachTimeToSecs(uint64_t time)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)time * (double)timebase.numer / (double)timebase.denom / 1e9;
}

@interface AXUnusedImageFilter ()
@property (nonatomic,copy  ) NSString       *rootDirectoryPath;
@property (nonatomic,strong) NSFileManager  *manager;
@property (nonatomic,strong) NSArray        *subPaths;
@property (nonatomic,strong) NSMutableArray *imageArray;
@property (nonatomic,strong) NSMutableArray *imageNeedRemovedArray;
@property (nonatomic,copy  ) NSString       *mFilePath;
@end

@implementation AXUnusedImageFilter

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        _removeUnusedImage = NO;
        _cleanPbxproj = NO;
        _backupUnusedImage = NO;
        _path = path;
        _rootDirectoryPath = path;
        _fileExtensions = @[@"m", @"xib", @"cpp", @"storyboard", @"mm", @"swift", @"plist", @"json"];
        _manager = [NSFileManager defaultManager];
        _imageArray = [[NSMutableArray alloc] init];
        _imageNeedRemovedArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)start
{
    uint64_t begin = mach_absolute_time();
    
    // check if the directory exists. 检查目录是否存在
    if(![self.manager fileExistsAtPath:self.rootDirectoryPath]) {
        NSLog(@"The Directory does not exist");
        return;
    }
    self.subPaths = [self.manager subpathsAtPath:self.rootDirectoryPath];

    // pick out all png and jpg image.选出所有的 .png 或者 .jpg
    [self getAllImageFile];
    
    // pick out all source files that need to be retrieved.选出所有的需要检索的文件
    [self getAllMFile];
    
    // the most important step, filter all unused image.检查没有用过的图片
    [self filterUnusedImage];
    
    uint64_t middle = mach_absolute_time();
    NSLog(@"Take Time %g s", MachTimeToSecs(middle - begin));
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        // clear useless array.清空没有用的数组
        [strongSelf.imageArray removeAllObjects];
        
        // clear temporary file.删除临时文件
        [strongSelf.manager removeItemAtPath:self.mFilePath error:nil];
        
        if (strongSelf.backupUnusedImage) {
            // backup unused images to another path before removing them.备份不用的图片到另一个目录
            [strongSelf backupUnusedImageFile];
        }
        
        if (strongSelf.removeUnusedImage) {
            // removing these image.删除图片
            [strongSelf removeImageFile];
        }
    });
    
    if (self.cleanPbxproj) {
        // edit project.pbxproj. 修改project.pbxproj
        [self cleanPbxprojFile];
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    uint64_t end = mach_absolute_time();
    NSLog(@"Take Time %g s", MachTimeToSecs(end - begin));
}

- (void)getAllImageFile
{
    for (NSString * subPath in self.subPaths) {
        NSString * pathExtension = [subPath pathExtension];
        if ([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"PNG"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"JPG"]) {
            // skip images in bundle.不考虑bundle中的图片
            if ([subPath containsString:@".bundle"]) {
                continue;
            }
            // store this image into array.将该图片存入数组
            NSString * realName = [subPath lastPathComponent];
            NSString * fullFileName = [realName stringByDeletingPathExtension];
            CGFloat size = [[self.manager attributesOfItemAtPath:[self.rootDirectoryPath stringByAppendingPathComponent:subPath] error:nil] fileSize];
            AXImage * axImage = [[AXImage alloc] init];
            axImage.realName = realName;
            axImage.size = size;
            axImage.path = [self.rootDirectoryPath stringByAppendingPathComponent:subPath];
            if ([fullFileName containsString:@"@2x"] || [fullFileName containsString:@"@3x"]) {
                NSString * partFileName = [fullFileName substringWithRange:NSMakeRange(0, fullFileName.length-3)];
                axImage.shortName = partFileName;
            } else {
                axImage.shortName = fullFileName;
            }
            [self.imageArray addObject:axImage];
        }
    }
}

- (void)getAllMFile
{
    // create new file.We will store all string between "" in this file.新建文件
    self.mFilePath = [[self.rootDirectoryPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tmpMFile.txt"];
    [self.manager removeItemAtPath:self.mFilePath error:nil];
    [self.manager createFileAtPath:self.mFilePath contents:nil attributes:nil];
    
    // group for reading file
    dispatch_group_t groupReadMFile = dispatch_group_create();
    // group for writing file
    dispatch_group_t groupWriteNewMFile = dispatch_group_create();
    // serial queue for writing file
    dispatch_queue_t queueWriteNewMFile = dispatch_queue_create("WRITE_MFILE_QUEUE", DISPATCH_QUEUE_SERIAL);
    __weak typeof(self) weakSelf = self;
    // Regular Expression. 正则
    NSString *pattern = @"\"(.*?)\"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    // open the new file.打开新文件
    NSFileHandle * fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.mFilePath];
    
    for (NSString * subPath in self.subPaths) {
        // just consider regular type file.只考虑普通文件，不考虑链接之类的特殊文件
        if ([[self.manager attributesOfItemAtPath:[self.rootDirectoryPath stringByAppendingPathComponent:subPath] error:nil] fileType] != NSFileTypeRegular) {
            continue;
        }
        NSString * pathExtension = [subPath pathExtension];
        BOOL needSearch = NO;
        for (NSString * type in self.fileExtensions) {
            if ([pathExtension isEqualToString:type]) {
                needSearch = YES;
                break;
            }
        }
        if (needSearch) {
            // read files asynchronously and concurrently, then intercept strings between "". 异步并行读取文件，从中截取带双引号中的字符串
            dispatch_group_async(groupReadMFile, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                NSString * mFileRealPath = [strongSelf.rootDirectoryPath stringByAppendingPathComponent:subPath];
                // the content of original file. 原文件的内容字符串
                NSString * contentOfOldFile = [NSString stringWithContentsOfFile:mFileRealPath encoding:NSUTF8StringEncoding error:nil];
                // if the type of file is plist, copy the file directly.because image name in plist does not own "" in both side.如果是plist的话，直接拷贝文件，因为plist中的图片名字两侧不带双引号
                if ([pathExtension isEqualToString:@"plist"]) {
                    // write file asynchronously and serially.异步串行写文件
                    dispatch_group_async(groupWriteNewMFile, queueWriteNewMFile, ^{
                        [fileHandle seekToEndOfFile];
                        [fileHandle writeData:[contentOfOldFile dataUsingEncoding:NSUTF8StringEncoding]];
                    });
                } else {// 其他的进行按要求进行截取
                    // 新文件的内容字符串
                    NSMutableString * contentOfNewFile = [[NSMutableString alloc] init];
                    // 找到原文件中带双引号的字符串
                    NSArray *matches = [regex matchesInString:contentOfOldFile options:0 range:NSMakeRange(0, contentOfOldFile.length)];
                    for (NSTextCheckingResult * match in matches) {
                        NSString * tmpStr = [contentOfOldFile substringWithRange:[match rangeAtIndex:1]];
                        // ship .h 过滤.h
                        if (![tmpStr hasSuffix:@".h"]) {
                            [contentOfNewFile appendString:tmpStr];
                        }
                    }
                    // 异步串行写文件
                    dispatch_group_async(groupWriteNewMFile, queueWriteNewMFile, ^{
                        [fileHandle seekToEndOfFile];
                        [fileHandle writeData:[contentOfNewFile dataUsingEncoding:NSUTF8StringEncoding]];
                    });
                }
            });
        }
    }
    dispatch_group_wait(groupReadMFile, DISPATCH_TIME_FOREVER);
    dispatch_group_wait(groupWriteNewMFile, DISPATCH_TIME_FOREVER);
    [fileHandle closeFile];
}

- (void)filterUnusedImage
{
    __block CGFloat totalSize = 0;
    // 创建文本文件，保存没有用过的图片的名字
    NSString * unusedImageListFilePath = [[self.rootDirectoryPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Unused Image List.txt"];
    [self.manager createFileAtPath:unusedImageListFilePath contents:nil attributes:nil];
    NSFileHandle * unusedImageListFileHandle = [NSFileHandle fileHandleForWritingAtPath:unusedImageListFilePath];
    // 搜索文件的group
    dispatch_group_t groupSearchFile = dispatch_group_create();
    // 写文件的group
    dispatch_group_t groupWriteFile = dispatch_group_create();
    // 写文件的串行队列
    dispatch_queue_t queueWriteFile = dispatch_queue_create("WRITE_FILER_UNUSED_IMAGE_QUEUE", DISPATCH_QUEUE_SERIAL);
    __weak typeof(self) weakSelf = self;
    for (AXImage * image in self.imageArray) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        // 异步并行搜索文件
        dispatch_group_async(groupSearchFile, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @autoreleasepool {
                NSTask *task = [[NSTask alloc] init];
                task.launchPath = @"/usr/bin/grep";
                // -l 查询多文件时只输出包含匹配字符的文件名
                task.arguments = @[@"-l", image.shortName, self.mFilePath];
                NSPipe *pipe;
                pipe = [NSPipe pipe];
                [task setStandardOutput:pipe];
                NSFileHandle * fileHandle = [pipe fileHandleForReading];
                [task launch];
                NSData * data = [fileHandle readDataToEndOfFile];
                NSString * searchResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (searchResult.length == 0) {// 没有搜索到，即没有用过
                    // 异步串行写文件
                    dispatch_group_async(groupWriteFile, queueWriteFile, ^{
                        [strongSelf.imageNeedRemovedArray addObject:image];
                        totalSize += image.size;
                        NSLog(@"%lu - %@", (unsigned long)strongSelf.imageNeedRemovedArray.count, image.realName);
                        // 将文件名写到 没有使用的图片.txt
                        [unusedImageListFileHandle seekToEndOfFile];
                        [unusedImageListFileHandle writeData:[image.realName dataUsingEncoding:NSUTF8StringEncoding]];
                        [unusedImageListFileHandle seekToEndOfFile];
                        [unusedImageListFileHandle writeData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                    });
                }
            }
        });
    }
    dispatch_group_wait(groupSearchFile, DISPATCH_TIME_FOREVER);
    dispatch_group_wait(groupWriteFile, DISPATCH_TIME_FOREVER);
    
    // 写出总数和大小
    [unusedImageListFileHandle seekToEndOfFile];
    NSString * countAndSizeStr = [NSString stringWithFormat:@"\r\nTotal:%lu\r\nSize:%.2fkb", (unsigned long)self.imageNeedRemovedArray.count, totalSize/1024];
    [unusedImageListFileHandle writeData:[countAndSizeStr dataUsingEncoding:NSUTF8StringEncoding]];
    // clost file.关闭文件
    [unusedImageListFileHandle closeFile];
    
    NSLog(@"%lu", (unsigned long)self.imageNeedRemovedArray.count);
}

- (void)backupUnusedImageFile
{
    NSString * anotherImageFilePath = [[self.rootDirectoryPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Unused File"];
    [self.manager removeItemAtPath:anotherImageFilePath error:nil];
    [self.manager createDirectoryAtPath:anotherImageFilePath withIntermediateDirectories:NO attributes:nil error:nil];
    
    for (int i=0; i<self.imageNeedRemovedArray.count; i++) {
        AXImage * image = self.imageNeedRemovedArray[i];
        NSString * newFileName = [NSString stringWithFormat:@"(%i)%@", i+1, image.realName];
        NSError * error;
        BOOL success = [self.manager copyItemAtPath:image.path toPath:[anotherImageFilePath stringByAppendingPathComponent:newFileName] error:&error];
        if (!success) {
            NSLog(@"%@", error.description);
        }
        NSLog(@"Save file %@", image.realName);
    }
}

- (void)removeImageFile
{
    for (AXImage * image in self.imageNeedRemovedArray) {
        [self.manager removeItemAtPath:image.path error:nil];
        NSLog(@"Delete file %@", image.realName);
    }
}

- (void)cleanPbxprojFile
{
    if (self.imageNeedRemovedArray.count == 0) {
        return;
    }
    NSString * pbxprojPath = nil;
    for (NSString * subPath in self.subPaths) {
        if ([[subPath lastPathComponent] isEqualToString:@"project.pbxproj"]) {
            pbxprojPath = [self.rootDirectoryPath stringByAppendingPathComponent:subPath];
            break;
        }
    }
    if (pbxprojPath) {
        NSLog(@"Begin edit project.pbxproj...");
        // 利用sed删除project.pbxproj中没有用的那些行. use sed command to remove useless line.
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/sed";
        // -i 直接在原文件上修改. edit origin file directly
        // -e 拼接多个命令. joint a number of command
        NSMutableArray * arguments = [[NSMutableArray alloc] init];
        [arguments addObject:@"-i"];
        [arguments addObject:@""];
        for (int i = 0; i < self.imageNeedRemovedArray.count; i++) {
            AXImage * image = self.imageNeedRemovedArray[i];
            [arguments addObject:@"-e"];
            [arguments addObject:[NSString stringWithFormat:@"/%@/d",image.realName]];
        }
        [arguments addObject:pbxprojPath];
        task.arguments = arguments;
        [task launch];
        [task waitUntilExit];
        NSLog(@"Success edit project.pbxproj...");
    } else {
        NSLog(@"Not found project.pbxproj");
    }
}

@end
