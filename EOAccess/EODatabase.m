/** 
   EODatabase.m <title>EODatabase Class</title>

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
#include <Foundation/NSArray.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#endif

#include <EOControl/EOObjectStore.h>
#include <EOControl/EOKeyGlobalID.h>
#include <EOControl/EONull.h>
#include <EOControl/EODebug.h>

#include <EOAccess/EOAccessFault.h>
#include <EOAccess/EOAdaptor.h>
#include <EOAccess/EOModel.h>
#include <EOAccess/EOEntity.h>
#include <EOAccess/EODatabase.h>
#include <EOAccess/EODatabaseContext.h>

#include "EOPrivate.h"
/* TODO

   Controllare il resultCache, ad ogni forget/invalidate deve essere
   updatato.
 */

NSString *EOGeneralDatabaseException = @"EOGeneralDatabaseException";
NSTimeInterval EODistantPastTimeInterval = -603979776.0;
static BOOL _doesReleaseUnreferencedSnapshots = YES;

@implementation EODatabase

/*
 *  Database Global Methods
 */

static NSMutableArray *databaseInstances;

+ (void)initialize
{
  static BOOL initialized=NO;
  if (!initialized)
    {
      initialized=YES;

      GDL2_EOAccessPrivateInit();

      // THREAD
      databaseInstances = [NSMutableArray new];
    }
}

+ (void)makeAllDatabasesPerform: (SEL)aSelector withObject: anObject
{
  int i;
    
  // THREAD
  for (i = [databaseInstances count] - 1; i >= 0; i--)
    [[[databaseInstances objectAtIndex: i] nonretainedObjectValue] 
      performSelector: aSelector withObject: anObject];
}

/*
 * Initializing new instances
 */

-(id)init
{
  if ((self=[super init]))
    {
      _timestamp = EODistantPastTimeInterval;
    }
  return self;
}

//OK
- initWithAdaptor: (EOAdaptor *)adaptor
{
  if (!adaptor)
    {
      [self autorelease];
      return nil;
    }

  if ((self = [self init]))
    {
      [[NSNotificationCenter defaultCenter]
        addObserver: self
        selector: @selector(_globalIDChanged:)
        name: @"EOGlobalIDChangedNotification"
        object: nil];
      //  [databaseInstances addObject:[NSValue valueWithNonretainedObject:self]];
      ASSIGN(_adaptor,adaptor);

      _registeredContexts = [NSMutableArray new];
      _snapshots = [NSMutableDictionary new];
      _models = [NSMutableArray new];
      _entityCache = [NSMutableDictionary new];
      _toManySnapshots = [NSMutableDictionary new];
    }



  return self;
}

+ (EODatabase *)databaseWithModel: (EOModel *)model
{
  return [[[self alloc] initWithModel: model] autorelease];
}

- (id)initWithModel: (EOModel *)model
{
  EOAdaptor *adaptor = [EOAdaptor adaptorWithModel:model]; //Handle exception to deallocate self ?

  if ((self = [self initWithAdaptor: adaptor]))
    {
      [self addModel: model];
    }

  return self;
}

- (void)dealloc
{
  DESTROY(_adaptor);
  DESTROY(_registeredContexts);
  DESTROY(_snapshots);
  DESTROY(_models);
  DESTROY(_entityCache);
  DESTROY(_toManySnapshots);

  [super dealloc];
}

- (void)incrementSnapshotCountForGlobalID:(EOGlobalID *)globalId
{
  if (!_doesReleaseUnreferencedSnapshots)
  {
    return;
  }
  GSOnceFLog(@"TODO: %s", __PRETTY_FUNCTION__);
}

- (void)decrementSnapshotCountForGlobalID:(EOGlobalID *)globalId
{
  if (!_doesReleaseUnreferencedSnapshots)
  {
    return;
  }
  GSOnceFLog(@"TODO: %s", __PRETTY_FUNCTION__);  
}

+ (void)disableSnapshotRefcounting
{
  _doesReleaseUnreferencedSnapshots = NO;
}

- (NSArray *)registeredContexts
{
  NSMutableArray *array = [NSMutableArray array];
  int i, n;
  
  for (i = 0, n = [_registeredContexts count]; i < n; i++)
    [array addObject: [[_registeredContexts objectAtIndex: i]
			nonretainedObjectValue]];
    
  return array;
}

- (unsigned int) _indexOfRegisteredContext: (EODatabaseContext *)context
{
  int i;

  for( i = [_registeredContexts count]-1; i >= 0; i--)
    if ([[_registeredContexts objectAtIndex: i]
	  nonretainedObjectValue] == context)
      {
	return i;
      }

  return -1;
}

- (void)registerContext: (EODatabaseContext *)context
{
  unsigned int index=0;

  //OK

  NSAssert(([context database] == self),@"Database context is not me");

  index = [self _indexOfRegisteredContext:context];

  NSAssert(index == (unsigned int) -1 , @"DatabaseContext already registred");

  [_registeredContexts addObject:
			 [NSValue valueWithNonretainedObject: context]];
}

- (void)unregisterContext: (EODatabaseContext *)context
{
  //OK
  unsigned int index = [self _indexOfRegisteredContext:context];

  NSAssert(index != (unsigned int) -1, @"DatabaseContext wasn't registred");

  [_registeredContexts removeObjectAtIndex:index];
}

- (EOAdaptor *)adaptor
{
  return _adaptor;
}

- (void)addModel: (EOModel *)model
{
  [_models addObject: model];
}

- (void)removeModel: (EOModel *)model
{
  [_models removeObject: model];
}

- (BOOL)addModelIfCompatible: (EOModel *)model
{
  BOOL modelOk = NO;

  NSAssert(model, @"No model");//WO simply return NO (doesn't handle this case).

  if ([_models containsObject:model] == YES)
    modelOk = YES;
  else
    {
      EOAdaptor *adaptor = [self adaptor];

      if ([[model adaptorName] isEqualToString: [adaptor name]] == YES
         || [_adaptor canServiceModel: model] == YES)
        {
          [_models addObject: model];
          modelOk = YES;
        }
    }

  return modelOk;
}

- (NSArray *)models
{
  return _models;
}

- (EOEntity *)entityNamed: (NSString *)entityName
{
  //OK
  EOEntity *entity=nil;
  int i = 0;
  int count = 0;

  NSAssert(entityName, @"No entity name");

  count = [_models count];

  for(i = 0; !entity && i < count; i++)
    {
      EOModel *model = [_models objectAtIndex: i];

      entity = [model entityNamed: entityName];
    }

  return entity;
}

- (EOEntity *)entityForObject: (id)object
{
  //OK
  EOEntity *entity = nil;
  NSString *entityName = nil;



  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"object=%p (of class %@)",
			object, [object class]);
  NSAssert(!_isNilOrEONull(object), @"No object");

  if ([EOFault isFault: object])
    {
      EOFaultHandler *faultHandler = [EOFault handlerForFault: object];
      EOKeyGlobalID *gid;

      EOFLOGObjectLevelArgs(@"EODatabaseContext", @"faultHandler=%p (of class %@)",
			    faultHandler, [faultHandler class]);      

      gid = [(EOAccessFaultHandler *)faultHandler globalID];

      NSAssert3(gid, @"No gid for fault handler %p for object %p of class %@",
                faultHandler, object, [object class]);
      entityName = [gid entityName];
    }
  else
    entityName = [object entityName];

  NSAssert2(entityName, @"No object entity name for object %@ of class %@",
	    object, [object class]);

  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"entityName=%@", entityName);

  entity = [self entityNamed: entityName];

  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"entity=%p", entity);


  return entity;
}

- (NSArray *)resultCacheForEntityNamed: (NSString *)name
{
  return [_entityCache objectForKey: name];
}

- (void)setResultCache: (NSArray *)cache
        forEntityNamed: (NSString *)name
{


  [_entityCache setObject: cache
                forKey: name];


}

- (void)invalidateResultCacheForEntityNamed: (NSString *)name
{
  [_entityCache removeObjectForKey: name];//??
}

- (void)invalidateResultCache
{
  [_entityCache removeAllObjects];
}

- (void)handleDroppedConnection
{
  NSArray	    *dbContextArray;
  NSEnumerator	    *contextEnum;
  EODatabaseContext *dbContext;
  
  EOFLOGObjectFnStartOrCond2(@"DatabaseLevel", @"EODatabase");
  
  [_adaptor handleDroppedConnection];
  
  dbContextArray = [self registeredContexts];
  contextEnum = [dbContextArray objectEnumerator];
 
  while ((dbContext = [contextEnum nextObject]))
    [dbContext handleDroppedConnection];
  
  EOFLOGObjectFnStopOrCond2(@"DatabaseLevel", @"EODatabase");
}

-(void)setTimestampToNow
{
  _timestamp = [NSDate timeIntervalSinceReferenceDate];
}

@end


@implementation EODatabase (EOUniquing)

- (void)recordSnapshot: (NSDictionary *)snapshot
           forGlobalID: (EOGlobalID *)gid
{


  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"snapshot %p %@", snapshot, snapshot);
  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"gid=%@", gid);

  NSAssert(gid, @"No gid");
  NSAssert(snapshot, @"No snapshot");
  NSAssert(_snapshots, @"No _snapshots");

  [_snapshots setObject: snapshot
              forKey: gid];

  NSAssert([_snapshots objectForKey: gid], @"SNAPSHOT not save !!");


}

//"Receive EOGlobalIDChangedNotification notification"
/*
  This method is currently only intended to replace EOTemporaryGlobalIDs
  with corresponding EOKeyGlobalIDs.  Since the globalIDs within
  the _toManySnapshots can only contain EOKeyGlobalIDs from fetched
  data, they need not be searched yet.  This may change if we add support
  to allow mutable primary key class attributes or recordToManySnapshots:
  ever gets called with EOTemporaryGlobalIDs for some obscure reasons.
 */
- (void)_globalIDChanged: (NSNotification *)notification
{
  NSDictionary *snapshot = nil;
  NSDictionary *userInfo = nil;
  NSEnumerator *enumerator = nil;
  EOGlobalID *tempGID = nil;
  EOGlobalID *gid = nil;



  userInfo = [notification userInfo];
  enumerator = [userInfo keyEnumerator];

  while ((tempGID = [enumerator nextObject]))
    {
      EOFLOGObjectLevelArgs(@"EODatabaseContext", @"tempGID=%@", tempGID);

      gid = [userInfo objectForKey: tempGID];

      EOFLOGObjectLevelArgs(@"EODatabaseContext", @"gid=%@", gid);

      //OK ?
      snapshot = [_snapshots objectForKey: tempGID];
      EOFLOGObjectLevelArgs(@"EODatabaseContext", @"_snapshots snapshot=%@", snapshot);

      if (snapshot)
	{
	  [_snapshots removeObjectForKey: tempGID];
	  [_snapshots setObject: snapshot
                      forKey: gid];
	}

      //OK ?
      snapshot = [_toManySnapshots objectForKey: tempGID];
      EOFLOGObjectLevelArgs(@"EODatabaseContext", @"_toManySnapshots snapshot=%@",
			    snapshot);

      if (snapshot)
	{
	  [_toManySnapshots removeObjectForKey: tempGID];
	  [_toManySnapshots setObject: snapshot
                            forKey: gid];
	}
    }


}

//MG2014: OK
- (NSDictionary *)snapshotForGlobalID: (EOGlobalID *)gid
{
  return [self snapshotForGlobalID: gid
	       after: EODistantPastTimeInterval];
}

//MG2014: TODO: use ti
- (NSDictionary *)snapshotForGlobalID: (EOGlobalID *)gid
				after: (NSTimeInterval)ti
{
  NSDictionary *snapshot = nil;

  NSAssert(gid, @"No gid");

  snapshot = [_snapshots objectForKey: gid];

  return snapshot;
}

- (void)recordSnapshot: (NSArray*)gids
     forSourceGlobalID: (EOGlobalID *)gid
      relationshipName: (NSString *)name
{
  //OK
  NSMutableDictionary *toMany = nil;



  NSAssert(gid,@"No snapshot");
  NSAssert(gid,@"No Source Global ID");
  NSAssert(name,@"No relationship name");

  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"self=%p snapshot gids=%@", self, gids);
  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"SourceGlobalID gid=%@", gid);
  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"relationshipName=%@", name);

  toMany = [_toManySnapshots objectForKey: gid];

  if (!toMany)
    {
      toMany = [NSMutableDictionary dictionaryWithCapacity: 10];
      [_toManySnapshots setObject: toMany
			forKey: gid];
    }

  [toMany setObject: gids
          forKey: name];


}

- (NSArray *)snapshotForSourceGlobalID: (EOGlobalID *)gid
		      relationshipName: (NSString *)name
{
  NSAssert(gid, @"No Source Global ID");
  NSAssert(name, @"No relationship name");

  return [[_toManySnapshots objectForKey: gid] objectForKey: name];
}

- (void)forgetSnapshotForGlobalID: (EOGlobalID *)gid
{
  //Seems OK


  NSAssert(gid,@"No Global ID");

  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"gid=%@", gid);

  [_snapshots removeObjectForKey: gid];
  [_toManySnapshots removeObjectForKey: gid];

  [[NSNotificationCenter defaultCenter]
    postNotificationName: EOObjectsChangedInStoreNotification
    object: self
    userInfo: [NSDictionary dictionaryWithObject:
			      [NSArray arrayWithObject: gid]
			    forKey: EOInvalidatedKey]];


};

- (void)forgetSnapshotsForGlobalIDs: (NSArray*)gids
{
  NSEnumerator *gidEnum = nil;
  id gid = nil;



  NSAssert(gids, @"No Global IDs");
  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"gids=%@", gids);

  gidEnum = [gids objectEnumerator];

  while ((gid = [gidEnum nextObject]))
    {
      [_snapshots removeObjectForKey: gid];
      [_toManySnapshots removeObjectForKey: gid];
    }

  [[NSNotificationCenter defaultCenter]
    postNotificationName: EOObjectsChangedInStoreNotification
    object: self
    userInfo: [NSDictionary dictionaryWithObject: gids
			    forKey: EOInvalidatedKey]];


}

- (void)forgetAllSnapshots
{
   NSMutableSet	  *gidSet = [NSMutableSet new];
   NSMutableArray *gidArray = [NSMutableArray array];
 
   EOFLOGObjectFnStartOrCond2(@"DatabaseLevel", @"EODatabase");
 
   [gidSet addObjectsFromArray: [_snapshots allKeys]];
   [gidSet addObjectsFromArray: [_toManySnapshots allKeys]];
   [gidArray addObjectsFromArray: [gidSet allObjects]];
   [gidSet release];
   [_snapshots removeAllObjects];
   [_toManySnapshots removeAllObjects];

   [[NSNotificationCenter defaultCenter]
     postNotificationName: EOObjectsChangedInStoreNotification
     object:self
     userInfo: [NSDictionary dictionaryWithObject: gidArray
                             forKey: EOInvalidatedKey]];

   EOFLOGObjectFnStopOrCond2(@"DatabaseLevel", @"EODatabase");
}

- (void)recordSnapshots: (NSDictionary *)snapshots
{
  //OK
  //VERIFY: be sure to replace all anapshot entries if any !


  [_snapshots addEntriesFromDictionary: snapshots];

  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"self=%p _snapshots=%@",
			self, _snapshots);


}

- (void)recordToManySnapshots: (NSDictionary *)snapshots
{
//Seems OK
  NSEnumerator *keyEnum = nil;
  id key = nil;



  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"snapshots=%@", snapshots);
  NSAssert(snapshots, @"No snapshots");

  keyEnum = [snapshots keyEnumerator];

  while ((key = [keyEnum nextObject]))
    {
      NSMutableDictionary *toMany = nil;

      toMany = [_toManySnapshots objectForKey: key]; // look if already exists

      if (!toMany)
	{
	  toMany = [NSMutableDictionary dictionaryWithCapacity: 10];
	  [_toManySnapshots setObject: toMany
			    forKey: key];
	}

      [toMany addEntriesFromDictionary: [snapshots objectForKey: key]];
    }

  EOFLOGObjectLevelArgs(@"EODatabaseContext", @"snapshots=%@", snapshots);


}

- (NSDictionary *)snapshots
{
  return AUTORELEASE([_snapshots copy]);
}

@end /* EODatabase (EOUniquing) */

