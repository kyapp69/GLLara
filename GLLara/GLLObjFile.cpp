//
//  GLLObjFile.cpp
//  GLLara
//
//  Created by Torsten Kammer on 12.09.12.
//  Copyright (c) 2012 Torsten Kammer. All rights reserved.
//

#include "GLLObjFile.h"

#include <algorithm>
#include <iostream>
#include <fstream>
#include <sstream>
#include <stdexcept>

std::string stringFromFileURL(CFURLRef fileURL)
{
	// Not using CFURLGetFileSystemRepresentation here, because there is no function to find the maximum needed buffer size for CFURL.
	CFStringRef fsPath = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);
	CFIndex length = CFStringGetMaximumSizeOfFileSystemRepresentation(fsPath);
	char *buffer = new char[length];
	CFStringGetFileSystemRepresentation(fsPath, buffer, length);
	CFRelease(fsPath);
	
	std::string result(buffer);
	delete [] buffer;
	return result;
}

bool GLLObjFile::IndexSet::operator<(const GLLObjFile::IndexSet &other) const
{
	if (vertex < other.vertex) return true;
	else if (vertex > other.vertex) return false;
	
	if (normal < other.normal) return true;
	else if (normal > other.normal) return false;
	
	if (texCoord < other.texCoord) return true;
	else if (texCoord > other.texCoord) return false;
	
	return false;
}

GLLObjFile::Material::~Material()
{
	CFRelease(diffuseTexture);
	CFRelease(specularTexture);
	CFRelease(normalTexture);
}

template<class T> void GLLObjFile::parseFloatVector(const char *line, std::vector<T> &values, unsigned number) throw()
{
	if (number == 2)
	{
		float vals[4];
		int scanned = sscanf(line, "%*s %f %f %f %f", &vals[0], &vals[1], &vals[2], &vals[3]);
		for (int i = 0; i < std::min(scanned, (int) number); i++)
			values.push_back((T) vals[i]);
	}
}

void GLLObjFile::parseFace(std::istream &stream)
{
	IndexSet set[3];
	
	for (unsigned i = 0; i < 3; i++)
	{
		std::string indices;
		stream >> indices;
		
		int scanned = sscanf(indices.c_str(), "%u/%u/%u/%u", &set[i].vertex, &set[i].texCoord, &set[i].normal, &set[i].color);
		
		if (scanned < 3) throw std::invalid_argument("Only OBJ files with vertices, normals and texture coordinates are supported.");
		
		if (set[i].vertex > 0) set[i].vertex -= 1;
		else set[i].vertex += vertices.size() / 3;
		
		if (set[i].normal > 0) set[i].normal -= 1;
		else set[i].normal += normals.size() / 3;
		
		if (set[i].texCoord > 0) set[i].texCoord -= 1;
		else set[i].texCoord += texCoords.size() / 2;
		
		if (scanned > 3) // Color is optional.
		{
			if (set[i].color > 0) set[i].color -= 1;
			else set[i].color += colors.size() / 4;
		}
		else set[i].color = UINT_MAX;
		
		originalIndices.push_back(set[i]);
	}
}

void GLLObjFile::parseMaterialLibrary(CFURLRef location)
{
	std::string filename = stringFromFileURL(location);
	
	std::ifstream stream(filename.c_str());
	if (!stream) throw std::runtime_error("Could not open MTLLib file.");
	
	bool hasFirstMaterial = false;
	std::string materialName;
	Material *currentMaterial = new Material();
	
	while(stream.good())
	{
		std::string line;
		std::getline(stream, line);
		
		std::istringstream linestream(line);
		std::string token;
		linestream >> token;
		
		if (token == "newmtl")
		{
			if (!hasFirstMaterial)
			{
				// This is the first material. Just save the name.
				linestream >> materialName;
				hasFirstMaterial = true;
			}
			else
			{
				// Old material ends here. Store it here; map copies it, so it can be overwritten now.
				currentMaterial->ambient[3] = currentMaterial->diffuse[3] = currentMaterial->specular[3] = 1.0f;
				materials[materialName] = currentMaterial;
				
				// Reset material
				currentMaterial = new Material();
				
				// Save new name
				linestream >> materialName;
			}
		}
		else if (token == "Ka")
			sscanf(line.c_str(), "Ka %f %f %f", &currentMaterial->ambient[0], &currentMaterial->ambient[1], &currentMaterial->ambient[2]);
		else if (token == "Kd")
			sscanf(line.c_str(), "Kd %f %f %f", &currentMaterial->diffuse[0], &currentMaterial->diffuse[1], &currentMaterial->diffuse[2]);
		else if (token == "Ks")
			sscanf(line.c_str(), "Ks %f %f %f", &currentMaterial->specular[0], &currentMaterial->specular[1], &currentMaterial->specular[2]);
		else if (token == "Ns")
			sscanf(line.c_str(), "Ns %f", &currentMaterial->shininess);
		else if (token == "map_Kd")
		{
			std::string textureName;
			linestream >> textureName;
			
			currentMaterial->diffuseTexture = CFURLCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)textureName.c_str(), (CFIndex) textureName.size(), kCFStringEncodingUTF8, location);
		}
		else if (token == "map_Ks")
		{
			std::string textureName;
			linestream >> textureName;
			
			currentMaterial->specularTexture = CFURLCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)textureName.c_str(), (CFIndex) textureName.size(), kCFStringEncodingUTF8, location);
		}
		else if (token == "map_Kn" || token == "bump" || token == "map_bump")
		{
			std::string textureName;
			linestream >> textureName;
			
			currentMaterial->normalTexture = CFURLCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)textureName.c_str(), (CFIndex) textureName.size(), kCFStringEncodingUTF8, location);
		}
	}
}

unsigned GLLObjFile::unifiedIndex(const IndexSet &indexSet)
{
	std::map<IndexSet, unsigned>::iterator iter(vertexDataIndexForSet.find(indexSet));
	if (iter == vertexDataIndexForSet.end())
	{
		VertexData data;
		
		if (indexSet.vertex >= vertices.size()) throw std::range_error("Vertex index out of range.");
		if (indexSet.normal >= normals.size()) throw std::range_error("Surface normal index out of range.");
		if (indexSet.texCoord >= texCoords.size()) throw std::range_error("Texture coordinate index out of range.");
		
		memcpy(data.vert, &(vertices[indexSet.vertex*3]), sizeof(float [3]));
		memcpy(data.norm, &(normals[indexSet.normal*3]), sizeof(float [3]));
		memcpy(data.tex, &(texCoords[indexSet.texCoord*2]), sizeof(float [2]));
		unsigned dataSoFar = (unsigned) vertexData.size();
		vertexData.push_back(data);
		
		vertexDataIndexForSet[indexSet] = dataSoFar;
		
		return dataSoFar;
	}
	return iter->second;
}

void GLLObjFile::fillIndices()
{
	indices.clear();
	vertexData.clear();
	vertexDataIndexForSet.clear();
	
	for (unsigned i = 0; i < originalIndices.size(); i ++)
		indices.push_back(unifiedIndex(originalIndices[i]));
}

GLLObjFile::GLLObjFile(CFURLRef location)
{
	std::string filename = stringFromFileURL(location);
	
	std::ifstream stream(filename.c_str());
	if (!stream) throw std::runtime_error("Could not open OBJ file.");
	
	std::string activeMaterial("");
	unsigned activeMaterialStart = 0;
	while(stream.good())
	{
		std::string line;
		std::getline(stream, line);
		
		std::istringstream linestream(line);
		std::string token;
		linestream >> token;
		
		if (token == "v")
			parseFloatVector(line.c_str(), vertices, 3);
		else if (token == "vn")
			parseFloatVector(line.c_str(), normals, 3);
		else if (token == "vt")
			parseFloatVector(line.c_str(), texCoords, 2);
		else if (token == "vc")
			parseFloatVector(line.c_str(), colors, 4);
		else if (token == "f")
			parseFace(linestream);
		else if (token == "mtllib")
		{
			try
			{
				std::string filename;
				linestream >> filename;
				
				CFURLRef mtllibLocation = CFURLCreateWithBytes(kCFAllocatorDefault, (const UInt8 *)filename.c_str(), (CFIndex) filename.size(), kCFStringEncodingUTF8, location);
				
				parseMaterialLibrary(mtllibLocation);
				CFRelease(mtllibLocation);
			}
			catch (std::exception &e)
			{
				std::cerr << "Ignoring mtllib: " << e.what() << std::endl;
			}
		}
		else if (token == "usemtl")
		{
			if (activeMaterial.size() > 0)
			{
				// End previous material run
				materialRanges.push_back(MaterialRange(activeMaterialStart, (unsigned) originalIndices.size(), materials[activeMaterial]));
			}
			
			linestream >> activeMaterial;
			activeMaterialStart = (unsigned) originalIndices.size();
		}
	}
	
	fillIndices();
}