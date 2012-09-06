//
//  GLLMeshSettings.h
//  GLLara
//
//  Created by Torsten Kammer on 05.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GLLSourceListItem.h"

@class GLLItem;
@class GLLMesh;

@interface GLLMeshSettings : NSObject <GLLSourceListItem>

- (id)initWithItem:(GLLItem *)item mesh:(GLLMesh *)mesh;

@property (nonatomic, weak, readonly) GLLItem *item;
@property (nonatomic, retain, readonly) GLLMesh *mesh;

@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, readonly, copy) NSString *displayName;

@end
