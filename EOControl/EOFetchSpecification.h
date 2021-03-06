/* -*-objc-*-
   EOFetchSpecification.h

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#ifndef __EOFetchSpecification_h__
#define __EOFetchSpecification_h__

#ifdef GNUSTEP
#include <Foundation/NSObject.h>
#else
#include <Foundation/Foundation.h>
#endif

#include <EOControl/EODefines.h>

@class NSArray;
@class NSDictionary;
@class NSString;

@class EOQualifier;
@class EOKeyValueArchiver;
@class EOKeyValueUnarchiver;
@class EOFetchSpecification;


@interface EOFetchSpecification : NSObject <NSCopying, NSCoding>
{
  EOQualifier *_qualifier;
  NSArray *_sortOrderings;
  NSString *_entityName;
  NSDictionary *_hints;
  unsigned int _fetchLimit;
  NSArray *_prefetchingRelationshipKeys;
  NSArray *_rawAttributeKeys;
  struct {
    unsigned usesDistinct:1;
    unsigned isDeep:1;
    unsigned locksObjects:1;
    unsigned refreshesRefetchedObjects:1;
    unsigned promptsAfterFetchLimit:1;
    unsigned requiresAllQualifierBindingVariables:1;
    unsigned reserved:26;
  }_flags;
}

+ (EOFetchSpecification *)fetchSpecification;

- (id)initWithEntityName: (NSString *)entityName
	       qualifier: (EOQualifier *)qualifier
	   sortOrderings: (NSArray *)sortOrderings
	    usesDistinct: (BOOL)usesDistinct
		  isDeep: (BOOL)isDeep
		   hints: (NSDictionary *)hints;

- (EOFetchSpecification *)fetchSpecificationWithQualifierBindings: (NSDictionary *)bindings;

+ (EOFetchSpecification *)fetchSpecificationNamed: (NSString *)name
                                      entityNamed: (NSString *)entityName;

+ (EOFetchSpecification *)fetchSpecificationWithEntityName: (NSString *)name
                                                 qualifier: (EOQualifier *)qualifier
                                             sortOrderings: (NSArray *)sortOrderings;

+ (EOFetchSpecification *)fetchSpecificationWithEntityName: (NSString *)name
                                                 qualifier: (EOQualifier *)qualifier
                                             sortOrderings: (NSArray *)sortOrderings
                                              usesDistinct: (BOOL)usesDistinct
                                                    isDeep: (BOOL)isDeep
                                                     hints: (NSDictionary *)hints;

+ (EOFetchSpecification *)fetchSpecificationWithEntityName: (NSString *)name
                                                 qualifier: (EOQualifier *)qualifier
                                             sortOrderings: (NSArray *)sortOrderings
                                              usesDistinct: (BOOL)usesDistinct;

- (id)copyWithZone: (NSZone *)zone;

- (id)initWithKeyValueUnarchiver: (EOKeyValueUnarchiver *)unarchiver;
- (void)encodeWithKeyValueArchiver: (EOKeyValueArchiver *)archiver;

- (void)setEntityName: (NSString *)entityName;
- (NSString *)entityName;

- (void)setSortOrderings: (NSArray *)sortOrderings;
- (NSArray *)sortOrderings;

- (void)setQualifier: (EOQualifier *)qualifier;
- (EOQualifier *)qualifier;

- (void)setUsesDistinct: (BOOL)usesDistinct;
- (BOOL)usesDistinct;

- (void)setIsDeep: (BOOL)isDeep;
- (BOOL)isDeep;

- (void)setLocksObjects: (BOOL)locksObjects;
- (BOOL)locksObjects;

- (void)setRefreshesRefetchedObjects: (BOOL)refreshesRefetchedObjects;
- (BOOL)refreshesRefetchedObjects;

- (void)setFetchLimit: (unsigned)fetchLimit;
- (unsigned)fetchLimit;

- (void)setPromptsAfterFetchLimit: (BOOL)promptsAfterFetchLimit;
- (BOOL)promptsAfterFetchLimit;

- (void)setRequiresAllQualifierBindingVariables: (BOOL)flag;
- (BOOL)requiresAllQualifierBindingVariables;

- (void)setPrefetchingRelationshipKeyPaths: (NSArray *)prefetchingRelationshipKeys;
- (NSArray *)prefetchingRelationshipKeyPaths;

- (void)setRawAttributeKeys: (NSArray *)rawAttributeKeys;
- (NSArray *)rawAttributeKeys;

- (void)setFetchesRawRows: (BOOL)fetchRawRows;
- (BOOL)fetchesRawRows;

- (void)setHints: (NSDictionary *)hints;
- (NSDictionary *)hints;
- (NSDictionary *)_hints;

- (NSArray *)rawRowKeyPaths;
- (void)setRawRowKeyPaths: (NSArray *)rawRowKeyPaths;

@end

#endif

