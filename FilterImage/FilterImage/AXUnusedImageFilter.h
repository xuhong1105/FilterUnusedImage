//
//  AXUnusedImageFilter.h
//  FilterImage
//
//  Created by Allen on 15/12/9.
//  Copyright © 2015年 Allen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AXUnusedImageFilter : NSObject

@property (nonatomic,copy,readonly) NSString *path;
@property (nonatomic,assign) BOOL removeUnusedImage;/**< whether remove unused image from project, default is NO */
@property (nonatomic,assign) BOOL cleanPbxproj;/**< whether clean project.pbxproj, default is NO */
@property (nonatomic,assign) BOOL backupUnusedImage;/**< whether backup unusedImage to another path, default is NO */
@property (nonatomic,strong) NSArray *fileExtensions;/**< default is @[@"m", @"xib", @"cpp", @"storyboard", @"mm", @"swift", @"plist", @"json"] */


- (instancetype)initWithPath:(NSString *)path;
- (void)start;

@end

NS_ASSUME_NONNULL_END