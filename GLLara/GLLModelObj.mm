//
//  GLLModelObj.m
//  GLLara
//
//  Created by Torsten Kammer on 12.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import "GLLModelObj.h"

#import "GLLBone.h"
#import "GLLMeshObj.h"
#import "GLLObjFile.h"

@interface GLLModelObj ()
{
	GLLObjFile *file;
}

@end

@implementation GLLModelObj

- (id)initWithContentsOfURL:(NSURL *)url error:(NSError *__autoreleasing*)error;
{
	if (!(self = [super init])) return nil;

	try {
		file = new GLLObjFile((__bridge CFURLRef) url);
	} catch (std::exception e) {
		if (error)
			*error = [NSError errorWithDomain:@"GLLModelObj" code:1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"There was an error loading the file.", @"couldn't load obj file")}];
		return nil;
	}
	
	// 1. Set up bones. We only have the one.
	self.bones = @[ [[GLLBone alloc] initWithModel:self] ];
	
	// 2. Set up meshes. We use one mesh per material group.
	NSMutableArray *meshes = [[NSMutableArray alloc] initWithCapacity:file->getMaterialRanges().size()];
	for (auto &range : file->getMaterialRanges())
	{
		[meshes addObject:[[GLLMeshObj alloc] initWithObjFile:file range:range]];
	}
	
	return self;
}

@end
