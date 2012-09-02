//
//  GLLTexture.m
//  GLLara
//
//  Created by Torsten Kammer on 01.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#import "GLLTexture.h"

#import <CoreGraphics/CoreGraphics.h>
#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>
#import "OpenDDSFile.h"

#pragma mark -
#pragma mark Private DDS loading functions

GLenum _dds_get_compressed_texture_format(const DDSFile *file)
{
	enum DDSDataFormat format = DDSGetDataFormat(file);
	switch(format)
	{
		case DDS_DXT1:
			return GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
		case DDS_DXT3:
			return GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
		case DDS_DXT5:
			return GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
			
		default:
			return 0;
	}
}

void _dds_get_texture_format(const DDSFile *file, GLenum *format, GLenum *type)
{
	enum DDSDataFormat fileFormat = DDSGetDataFormat(file);
	*format = 0;
	*type = 0;
	switch(fileFormat)
	{
		case DDS_RGB_8:
			*format = GL_RGB;
			*type = GL_UNSIGNED_BYTE;
			break;
		case DDS_RGB_565:
			*format = GL_RGB;
			*type = GL_UNSIGNED_SHORT_5_6_5;
			break;
		case DDS_ARGB_8:
			*format = GL_BGRA;
			*type = GL_UNSIGNED_INT_8_8_8_8_REV;
			break;
		case DDS_ARGB_4:
			*format = GL_BGRA;
			*type = GL_UNSIGNED_SHORT_4_4_4_4_REV;
			break;
		case DDS_ARGB_1555:
			*format = GL_BGRA;
			*type = GL_UNSIGNED_SHORT_1_5_5_5_REV;
			break;
		
		default:
			*format = 0;
			*type = 0;
	}
}

Boolean _dds_upload_texture_data(const DDSFile *file, CFIndex mipmapLevel)
{
	CFIndex size;
	CFIndex width;
	CFIndex height;
	CFDataRef data;
	
	width = DDSGetWidth(file) >> mipmapLevel;
	height = DDSGetHeight(file) >> mipmapLevel;
	if (!width || !height) return 0;
	
	data = DDSCreateDataForMipmapLevel(file, mipmapLevel);
	if (!data) return 0;
    const void *byteData = CFDataGetBytePtr(data);
    size = CFDataGetLength(data);
    
	if (DDSIsCompressed(file))
		glCompressedTexImage2D(GL_TEXTURE_2D, (GLsizei) mipmapLevel, _dds_get_compressed_texture_format(file), (GLsizei) width, (GLsizei) height, 0, (GLsizei) size, byteData);
	else
	{
		GLenum format;
		GLenum type;
        _dds_get_texture_format(file, &format, &type);
		glTexImage2D(GL_TEXTURE_2D, (GLsizei) mipmapLevel, GL_RGBA, (GLsizei) width, (GLsizei) height, 0, format, type, byteData);
	}
    
    CFRelease(data);
    
	return 1;
}

@interface GLLTexture ()

- (void)_loadDDSTextureWithData:(NSData *)data;
- (void)_loadCGCompatibleTexture:(NSData *)data;

@end

@implementation GLLTexture

- (id)initWithFile:(NSURL *)fileURL;
{
	if (!(self = [super init])) return nil;
	
	glGenTextures(GL_TEXTURE_2D, &_name);
	glBindTexture(GL_TEXTURE_2D, _name);
	
	NSData *data = [NSData dataWithContentsOfURL:fileURL];
	if ([fileURL.pathExtension isEqual:@"dds"])
		[self _loadDDSTextureWithData:data];
	else
		[self _loadCGCompatibleTexture:data];
	
	return self;
}

- (void)unload;
{
	glDeleteTextures(1, &_name);
	_name = 0;
}

- (void)dealloc
{
	NSAssert(_name == 0, @"did not call unload before dealloc");
}

#pragma mark -
#pragma mark Private methods

- (void)_loadDDSTextureWithData:(NSData *)data;
{
	DDSFile *file = DDSOpenData((__bridge CFDataRef) data);
	NSAssert(file, @"Not a DDS file at all!");
	
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, DDSHasMipmaps(file) ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR);
	
	CFIndex mipmap = 0;
	while (_dds_upload_texture_data(file, mipmap))
		mipmap++;
	
	DDSDestroy(file);
}
- (void)_loadCGCompatibleTexture:(NSData *)data;
{
	CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) data, NULL);
	CFDictionaryRef dict = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
	CFIndex width, height;
	CFNumberGetValue(CFDictionaryGetValue(dict, kCGImagePropertyPixelWidth), kCFNumberCFIndexType, &width);
	CFNumberGetValue(CFDictionaryGetValue(dict, kCGImagePropertyPixelHeight), kCFNumberCFIndexType, &height);
	CFRelease(dict);
	
	unsigned char *bufferData = malloc(width * height * 4);
	CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, NULL);
	CFRelease(source);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef cgContext = CGBitmapContextCreate(bufferData, width, height, 8, width * 4, colorSpace, kCGImageAlphaFirst);
	
	CGColorSpaceRelease(colorSpace);
	
	CGContextDrawImage(cgContext, CGRectMake(0.0f, 0.0f, (CGFloat) width, (CGFloat) height), cgImage);
	CGContextRelease(cgContext);
	CGImageRelease(cgImage);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei) width, (GLsizei) height, 0, GL_BGRA_INTEGER, GL_UNSIGNED_INT_8_8_8_8_REV, bufferData);
	
	free(bufferData);
}

@end