//
//  main.m
//  FilterImage
//
//  Created by Allen on 15/12/8.
//  Copyright © 2015年 Allen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AXFilterImage.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString * projectPath = @"write your project path here";
        AXFilterImage * filter = [[AXFilterImage alloc] initWithPath:projectPath];
        filter.removeUnusedImage = YES;
        filter.cleanPbxproj = YES;
        filter.saveUnusedImage = YES;
        [filter start];
    }
    return 0;
}
