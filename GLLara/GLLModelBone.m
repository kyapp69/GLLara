//
//  GLLModelBone.m
//  GLLara
//
//  Created by Torsten Kammer on 01.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import "GLLModelBone.h"

#import "GLLASCIIScanner.h"
#import "GLLModel.h"
#import "simd_matrix.h"
#import "TRInDataStream.h"

@implementation GLLModelBone

- (id)initWithModel:(GLLModel *)model;
{
	if (!(self = [super init])) return nil;
	
	_model = model;
	
	_parentIndex = UINT16_MAX;
	_children = @[];
	
	_positionX = 0;
	_positionY = 0;
	_positionZ = 0;
	
	_positionMatrix = simd_mat_identity();
	_inversePositionMatrix = simd_mat_identity();
	
	_name = NSLocalizedString(@"Root bone", @"Only bone in a boneless format");
	
	return self;

}

- (id)initFromSequentialData:(id)stream partOfModel:(GLLModel *)model error:(NSError *__autoreleasing*)error;
{
	if (!(self = [super init])) return nil;
	
	if (![stream isValid])
	{
		if (error)
			*error = [NSError errorWithDomain:GLLModelLoadingErrorDomain code:GLLModelLoadingError_PrematureEndOfFile userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"The file is missing some data.", @"Premature end of file error") }];
		return nil;
	}
	
	_model = model;
	
	_name = [stream readPascalString];
	_parentIndex = [stream readUint16];
	_positionX = [stream readFloat32];
	_positionY = [stream readFloat32];
	_positionZ = [stream readFloat32];
	
	if (![stream isValid])
	{
		if (error)
			*error = [NSError errorWithDomain:GLLModelLoadingErrorDomain code:GLLModelLoadingError_PrematureEndOfFile userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"The file is missing some data.", @"Premature end of file error") }];
		return nil;
	}
	
	_positionMatrix = simd_mat_positional(simd_make(_positionX, _positionY, _positionZ, 1.0f));
	_inversePositionMatrix = simd_mat_positional(simd_make(-_positionX, -_positionY, -_positionZ, 1.0f));
	
	return self;
}

- (GLLModelBone *)parent
{
	if (self.parentIndex >= self.model.bones.count) return nil;
	return self.model.bones[self.parentIndex];
}

#pragma mark - Finishing loading

- (BOOL)findParentsAndChildrenError:(NSError *__autoreleasing*)error;
{
	if (self.parentIndex != UINT16_MAX && self.parentIndex >= self.model.bones.count)
	{
		if (error)
			*error = [NSError errorWithDomain:GLLModelLoadingErrorDomain code:GLLModelLoadingError_IndexOutOfRange userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Bone's parent does not exist.", @"The parent index of this bone is invalid.") }];

		return NO;
	}
	
	GLLModelBone *parent = self.parent;
	NSMutableSet *encounteredBones = [NSMutableSet setWithObject:self];
	while (parent != nil)
	{
		if ([encounteredBones containsObject:parent])
		{
			if (error)
				*error = [NSError errorWithDomain:GLLModelLoadingErrorDomain code:GLLModelLoadingError_CircularReference userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"A bone has itself as an ancestor.", @"Found a circle in the bone relationships.") }];
			
			return NO;
		}
		[encounteredBones addObject:parent];
		parent = parent.parent;
	}
	
	_children = [self.model.bones filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"parent == %@", self]];
	return YES;
}

@end
