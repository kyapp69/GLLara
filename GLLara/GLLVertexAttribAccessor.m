//
//  GLLVertexAttribAccessor.m
//  GLLara
//
//  Created by Torsten Kammer on 06.04.21.
//  Copyright © 2021 Torsten Kammer. All rights reserved.
//

#import "GLLVertexAttribAccessor.h"

@interface GLLVertexAttribAccessor()

@property (nonatomic, readonly, assign) NSUInteger baseSize;

@end

@implementation GLLVertexAttribAccessor

- (instancetype)initWithAttrib:(enum GLLVertexAttrib)attrib layer:(NSUInteger) layer size:(enum GLLVertexAttribSize)size componentType:(enum GLLVertexAttribComponentType)type dataBuffer:(NSData *)buffer offset:(NSUInteger)offset;
{
    if (!(self = [super init])) {
        return nil;
    }
        
    NSAssert(type != GllVertexAttribComponentTypeInt2_10_10_10_Rev || size == GLLVertexAttribSizeVec4, @"2_10_10_10_Rev only allowed with Vec4");
    
    _attrib = attrib;
    _layer = layer;
    _size = size;
    _type = type;
    _dataBuffer = buffer;
    _dataOffset = offset;
    
    return self;
}

- (NSUInteger)hash
{
    return _attrib ^ _layer ^ _size ^ _type ^ [_dataBuffer hash] ^ _dataOffset;
}

- (BOOL)isEqualFormat:(GLLVertexAttribAccessor *)format
{
    return format.attrib == self.attrib && format.layer == self.layer && format.size == self.size && format.type == self.type;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:self.class])
        return NO;
    
    GLLVertexAttribAccessor *format = (GLLVertexAttribAccessor *) object;
    return format.attrib == self.attrib && format.layer == self.layer && format.size == self.size && format.type == self.type;
}

- (id)copy
{
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSUInteger)baseSize {
    switch (self.type) {
        case GllVertexAttribComponentTypeByte:
        case GllVertexAttribComponentTypeUnsignedByte:
            return 1;
        case GllVertexAttribComponentTypeShort:
        case GllVertexAttribComponentTypeUnsignedShort:
        case GllVertexAttribComponentTypeHalfFloat:
            return 2;
        case GllVertexAttribComponentTypeFloat:
            return 4;
        case GllVertexAttribComponentTypeInt2_10_10_10_Rev:
            return 1;
        default:
            return 0;
    }
}

- (NSUInteger)numberOfElements {
    switch (self.size) {
        case GLLVertexAttribSizeScalar:
            return 1;
        case GLLVertexAttribSizeVec2:
            return 2;
        case GLLVertexAttribSizeVec3:
            return 3;
        case GLLVertexAttribSizeVec4:
        case GLLVertexAttribSizeMat2:
            return 4;
        case GLLVertexAttribSizeMat3:
            return 9;
        case GLLVertexAttribSizeMat4:
            return 16;
        default:
            return 0;
    }
}

- (NSUInteger)sizeInBytes {
    if (self.type == GllVertexAttribComponentTypeInt2_10_10_10_Rev) {
        return 4;
    }
    return self.baseSize * self.numberOfElements;
}

@end

