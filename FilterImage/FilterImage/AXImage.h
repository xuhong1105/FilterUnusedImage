//
//  AXImage.h
//  FilterImage
//
//  Created by Allen on 15/12/9.
//  Copyright © 2015年 Allen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AXImage : NSObject

/**< short file name without extension or @2x @3x. 去掉扩展名和@2x @3x的文件名 */
@property (nonatomic,copy  ) NSString *shortName;
/**< real file name.真实的文件名 */
@property (nonatomic,copy  ) NSString *realName;
/**< size of file. 文件大小 */
@property (nonatomic,assign) CGFloat  size;
/**< path of file.文件路径 */
@property (nonatomic,copy  ) NSString *path;

@end
