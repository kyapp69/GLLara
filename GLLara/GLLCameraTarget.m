//
//  GLLCameraTarget.m
//  GLLara
//
//  Created by Torsten Kammer on 09.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import "GLLCameraTarget.h"
#import "GLLBoneTransformation.h"

#import "GLLItem.h"
#import "simd_functions.h"

static void *contextMarker = (void *) 0xdeadbeef;

@interface GLLCameraTarget ()

@property (nonatomic, assign, readwrite) vec_float4 position;
- (void)_updatePosition;

@end

@implementation GLLCameraTarget

+ (NSSet *)keyPathsForValuesAffectingDisplayName
{
	return [NSSet setWithObjects:@"name", @"bones", nil];
}

@synthesize position;

@dynamic name;
@dynamic bones;
@dynamic cameras;

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self addObserver:self forKeyPath:@"bones" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:contextMarker];
}
- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self addObserver:self forKeyPath:@"bones" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:contextMarker];
}
- (void)awakeFromSnapshotEvents:(NSSnapshotEventType)flags
{
	[super awakeFromSnapshotEvents:flags];
	[self addObserver:self forKeyPath:@"bones" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:contextMarker];
}
- (void)willTurnIntoFault
{
	[self removeObserver:self forKeyPath:@"bones"];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == contextMarker && [keyPath isEqual:@"bones"])
	{
		for (GLLBoneTransformation *transform in change[NSKeyValueChangeOldKey])
			[transform removeObserver:self forKeyPath:@"relativeTransform"];
		
		for (GLLBoneTransformation *transform in change[NSKeyValueChangeNewKey])
			[transform addObserver:self forKeyPath:@"relativeTransform" options: NSKeyValueObservingOptionInitial context:contextMarker];
	}
	else if (context == contextMarker && [keyPath isEqual:@"relativeTransform"])
	{
		[self _updatePosition];
	}
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (NSString *)displayName
{
	return [NSString stringWithFormat:NSLocalizedString(@"%@ — %@", @"camera target name format"), self.name, [[self.bones.anyObject item] displayName]];
}

- (void)_updatePosition
{
	vec_float4 newPosition;
	for (GLLBoneTransformation *transform in self.bones)
		newPosition += transform.globalPosition;
	
	self.position = newPosition / simd_splatf(self.bones.count);
}

@end
