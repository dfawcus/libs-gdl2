/** 
   EOObjectStore.m <title>EOObjectStore</title>

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: June 2000

   $Revision$
   $Date$

   <abstract></abstract>

   This file is part of the GNUstep Database Library.

   <license>
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
   </license>
**/

#include "config.h"

#ifdef GNUSTEP
#include <Foundation/NSString.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#endif

#include <EOControl/EOObjectStore.h>


NSString *EOObjectsChangedInStoreNotification = @"EOObjectsChangedInStoreNotification";

NSString *EOInvalidatedAllObjectsInStoreNotification = @"EOInvalidatedAllObjectsInStoreNotification";

NSString *EODeletedKey = @"deleted";
NSString *EOInsertedKey = @"inserted";
NSString *EOInvalidatedKey = @"invalidated";
NSString *EOUpdatedKey = @"updated";


@implementation EOObjectStore

- (id)faultForGlobalID: (EOGlobalID *)globalID
	editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id)faultForRawRow: (NSDictionary *)row
	 entityNamed: (NSString *)entityName
      editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSArray *)arrayFaultWithSourceGlobalID: (EOGlobalID *)globalID
			 relationshipName: (NSString *)name
			   editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void)initializeObject: (id)object
	    withGlobalID: (EOGlobalID *)globalID
          editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)objectsForSourceGlobalID: (EOGlobalID *)globalID
		     relationshipName: (NSString *)name
		       editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void)refaultObject: object
	 withGlobalID: (EOGlobalID *)globalID
       editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
}

- (void)saveChangesInEditingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)objectsWithFetchSpecification: (EOFetchSpecification *)fetchSpecification
			    editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL)isObjectLockedWithGlobalID: (EOGlobalID *)gid
		    editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (void)lockObjectWithGlobalID: (EOGlobalID *)gid
		editingContext: (EOEditingContext *)context
{
  [self subclassResponsibility: _cmd];
}

- (void)invalidateAllObjects
{
  [self subclassResponsibility: _cmd];
}

- (void)invalidateObjectsWithGlobalIDs: (NSArray *)globalIDs
{
  [self subclassResponsibility: _cmd];
}

- (id) propertiesForObjectWithGlobalID: (EOGlobalID *)gid
                        editingContext: (EOEditingContext *)context
{
  return [self subclassResponsibility:_cmd];
}

@end
