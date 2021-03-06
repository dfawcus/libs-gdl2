/**
   EOCheapArray.m <title>EOCheapCopyArray Classes</title>

   Copyright (C) 2000-2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Manuel Guesdon <mguesdon@orange-concept.com>
   Date: Sep 2000

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
#include <Foundation/NSString.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSException.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSDebug.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#include <GNUstepBase/NSThread+GNUstepBase.h>
#endif

#include <EOControl/EOCheapArray.h>
#include <EOControl/EODebug.h>


@implementation EOCheapCopyArray : NSArray

- (id) init
{
#ifdef DEBUG
  NSDebugFLog(@"Init EOCheapCopyArray %p", 
              self);
#endif

  return [super init];
};
- (id)initWithArray: (NSArray *)array
{
#ifdef DEBUG
  NSDebugFLog(@"initWithArray EOCheapCopyArray %p", 
              self);
#endif

  if ((self = [super initWithArray: array]))
    {
    }

  return self;
}

- (id) initWithObjects: (const id[])objects
                 count: (NSUInteger)count
{
#ifdef DEBUG
  NSDebugFLog(@"initWithObjects EOCheapCopyArray %p", 
              self);
#endif

  if (count > 0)
    {
      NSUInteger i;

      _contents_array = NSZoneMalloc([self zone], sizeof(id) * count);

      if (_contents_array == 0)
        {
          RELEASE(self);
          return nil;
       }

      for (i = 0; i < count; i++)
        {
          if ((_contents_array[i] = RETAIN(objects[i])) == nil)
            {
              _count = i;
              RELEASE(self);
              [NSException raise: NSInvalidArgumentException
                          format: @"Tried to add nil"];
            }
        }

      _count = count;
    }

  return self;
}

- (void) dealloc
{

  if (_contents_array)
    {
#if     !GS_WITH_GC
      NSUInteger i;

      for (i = 0; i < _count; i++)
        {
          [_contents_array[i] release];
        }
#endif
      NSZoneFree([self zone], _contents_array);
    }

  NSDeallocateObject(self);
  /* Suppress compiler warning.  */
  if (0) [super dealloc];

#ifdef DEBUG
  NSDebugFLog(@"Stop Dealloc EOCheapCopyArray %p. %@",
              (void*)self, GSCurrentThread());
#endif
}

- (id) autorelease
{
#ifdef DEBUG
  NSDebugFLog(@"autorelease EOCheapCopyArray %p. %@ [super retainCount]=%"PRIuPTR,
              (void*)self,GSCurrentThread(),[super retainCount]);
#endif
  return [super autorelease];
}

- (oneway void) release
{
#ifdef DEBUG
  NSDebugFLog(@"Release EOCheapCopyArray %p. %@ [super retainCount]=%"PRIuPTR,
              (void*)self,GSCurrentThread(),[super retainCount]);
#endif
  [super release];
}

- (NSUInteger) retainCount
{
#ifdef DEBUG
  NSDebugFLog(@"retainCount EOCheapCopyArray %p. %@",
              (void*)self,GSCurrentThread());
#endif
  return [super retainCount];

}

- (id) retain
{
#ifdef DEBUG
  NSDebugFLog(@"retain EOCheapCopyArray %p. %@, [super retainCount]=%"PRIuPTR,
              (void*)self,GSCurrentThread(),[super retainCount]);
#endif
  return [super retain];
}

- (id) objectAtIndex: (NSUInteger)index
{
  if (index >= _count)
    {
      [NSException raise: NSRangeException
                  format: @"Index out of bounds"];
    }

  return _contents_array[index];
}

//- (id) copyWithZone: (NSZone*)zone;
- (NSUInteger) count
{
  return _count;
}

//- (BOOL) containsObject: (id)obejct;
@end

@implementation EOCheapCopyMutableArray

- (id) initWithCapacity: (NSUInteger)capacity
{
  if (capacity == 0)
    {
      capacity = 1;
    }

  _contents_array = NSZoneMalloc([self zone], sizeof(id) * capacity);
  _capacity = capacity;
  _grow_factor = capacity > 1 ? capacity/2 : 1;

  return self;
}

- (id) initWithObjects: (const id[])objects
                 count: (NSUInteger)count
{
  self = [self initWithCapacity: count];

  if (self != nil && count > 0)
    {
      unsigned  i;

      for (i = 0; i < count; i++)
        {
          if ((_contents_array[i] = RETAIN(objects[i])) == nil)
            {
              _count = i;
              RELEASE(self);
              [NSException raise: NSInvalidArgumentException
                          format: @"Tried to add nil"];
            }
        }
      _count = count;
    }

  return self;
}

- (id)initWithArray: (NSArray *)array
{
  if ((self = [super initWithArray: array]))
    {
      _grow_factor = 5;
    }

  return self;
}

- (void) dealloc
{
#ifdef DEBUG
  NSDebugFLog(@"Deallocate EOCheapCopyMutableArray %p zone=%p _contents_array=%p _count=%"PRIuPTR" _capacity=%"PRIuPTR,
              self, [self zone], _contents_array, _count, _capacity);
#endif
  if (_contents_array)
    {
#if     !GS_WITH_GC
      NSUInteger  i;
      for (i = 0; i < _count; i++)
        {
          [_contents_array[i] release];
        }
#endif
      NSZoneFree([self zone], _contents_array);
    }

  DESTROY(_immutableCopy);
  NSDeallocateObject(self);
  /* Suppress compiler warning.  */
  if (0) [super dealloc];

#ifdef DEBUG
  NSDebugFLog(@"Stop Dealloc EOCheapCopyMutableArray %p. %@",
              (void*)self,GSCurrentThread());
#endif
}

- (NSArray *)shallowCopy
{
#ifdef DEBUG
  NSDebugFLog(@"Start shallowCopy EOCheapCopyMutableArray %p. %@ immutableCopy=%p",
              (void*)self,GSCurrentThread(),_immutableCopy);
#endif
  //OK
  if (!_immutableCopy)
    {
      // OK. It's retained for us.
      _immutableCopy= [[EOCheapCopyArray alloc]
			initWithObjects: _contents_array
			count: _count];
      //Next will retain for caller
    }
  RETAIN(_immutableCopy); // Because copy return a not autoreleased object. Retain for request caller

#ifdef DEBUG
  NSDebugFLog(@"Stop shallowCopy EOCheapCopyMutableArray %p. %@ immutableCopy=%p",
              (void*)self,GSCurrentThread(),_immutableCopy);
#endif
  return _immutableCopy;
}

- (void) _setCopy: (id)param0
{
  //TODO
}

- (void) _mutate
{
  DESTROY(_immutableCopy);
}

- (NSUInteger) count
{
  return _count;
}

- (id) objectAtIndex: (NSUInteger)index
{
  if (index >= _count)
    {
      [NSException raise: NSRangeException
                  format: @"Index out of bounds"];
    }

  return _contents_array[index];
}

- (void)addObject: (id)object
{


  if (!object)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Tried to add nil"];
    }

  [self _mutate];

  if (_count >= _capacity)
    {
      unsigned int grow = (_grow_factor>5 ? _grow_factor : 5);
      size_t size = (_capacity + grow) * sizeof(id);
      id *ptr;

      ptr = NSZoneRealloc([self zone], _contents_array, size);

      if (ptr == 0)
        {
          [NSException raise: NSMallocException
                      format: @"Unable to grow"];
        }

      _contents_array = ptr;
      _capacity += _grow_factor;
      _grow_factor = _capacity / 2;
    }

  _contents_array[_count] = RETAIN(object);
  _count++;     // Do this AFTER we have retained the object.


}

- (void) insertObject: (id)object
              atIndex: (NSUInteger)index
{
  NSUInteger i;

  if (!object)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Tried to insert nil"];
    }

  if (index > _count)
    {
      [NSException raise: NSRangeException
		   format:
		     @"in insertObject:atIndex:, index %"PRIuPTR" is out of range",
		   index];
    }

  [self _mutate];

  if (_count == _capacity)
    {
      id        *ptr;
      size_t    size = (_capacity + _grow_factor) * sizeof(id);

      ptr = NSZoneRealloc([self zone], _contents_array, size);

      if (ptr == 0)
        {
          [NSException raise: NSMallocException
                      format: @"Unable to grow"];
        }

      _contents_array = ptr;
      _capacity += _grow_factor;
      _grow_factor = _capacity / 2;
    }

  for (i = _count; i > index; i--)
    {
      _contents_array[i] = _contents_array[i - 1];
    }

  /*
   *    Make sure the array is 'sane' so that it can be deallocated
   *    safely by an autorelease pool if the '[anObject retain]' causes
   *    an exception.
   */
  _contents_array[index] = nil;
  _count++;
  _contents_array[index] = RETAIN(object);
}

- (void) removeLastObject
{
  if (_count == 0)
    {
      [NSException raise: NSRangeException
                  format: @"Trying to remove from an empty array."];
    }

  [self _mutate];
  _count--;

  RELEASE(_contents_array[_count]);
}

- (void) removeObjectAtIndex: (NSUInteger)index
{
  id    obj;

  if (index >= _count)
    {
      [NSException raise: NSRangeException
                  format: @"in removeObjectAtIndex:, index %"PRIuPTR" is out of range",
                        index];
    }
  obj = _contents_array[index];
  [self _mutate];
  _count--;

  while (index < _count)
    {
      _contents_array[index] = _contents_array[index+1];
      index++;
    }

  RELEASE(obj); /* Adjust array BEFORE releasing object.        */
}

- (void) replaceObjectAtIndex: (NSUInteger)index
                   withObject: (id)object;
{
  id    obj;

  if (index >= _count)
    {
      [NSException raise: NSRangeException format:
            @"in replaceObjectAtIndex:withObject:, index %"PRIuPTR" is out of range",
            index];
    }

  /*
   *    Swap objects in order so that there is always a valid object in the
   *    array in case a retain or release causes an exception.
   */
  obj = _contents_array[index];
  [self _mutate];

  IF_NO_GC(RETAIN(object));
  _contents_array[index] = object;

  RELEASE(obj);
}

//TODO implement it for speed ?? - (BOOL) containsObject:(id)object
//TODO implement it for speed ?? - (unsigned int) indexOfObjectIdenticalTo:(id)object
//TODO implement it for speed ?? - (void) removeAllObjects;
- (void) exchangeObjectAtIndex: (NSUInteger)index1
             withObjectAtIndex: (NSUInteger)index2
{
  id obj = nil;

  if (index1 >= _count || index2>=_count)
    {      
      [NSException raise: NSRangeException format:
            @"in exchangeObjectAtIndex:withObjectAtIndex:, index %"PRIuPTR" is out of range",
            (index1 >= _count ? index1 : index2)];
    }

  obj = _contents_array[index1];

  [self _mutate];

  _contents_array[index1] = _contents_array[index2];
  _contents_array[index2] = obj;
}

@end
