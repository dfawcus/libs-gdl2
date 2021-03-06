/** 
   EOObserver.m <title>EOObserver</title>

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Author: David Ayers <ayers@fsfe.org>
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
#include <Foundation/NSMapTable.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSException.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#endif

#include <EOControl/EOObserver.h>
#include <EOControl/EODebug.h>
#include <EOControl/EOPrivate.h>

@implementation NSObject (EOObserver)

/**
 * This is the hook to allow observers to be notified that the state
 * of the receiver is about to change.  The method should be called in
 * all mutating accessor methods before the state of the receiver changes.
 * This method invokes [EOObserverCenter+notifyObserversObjectWillChange:]
 * with the receiver.  It is responsible for invoking 
 * [(EOObserving)-objectWillChange:] for all corresponding observers.
 */
- (void)willChange
{
  [EOObserverCenter notifyObserversObjectWillChange: self];
}

@end

/**
 * <p>This is the central coordinating class of the change tracking system
 * of EOControl.  It manages the observers [(EOObserving)] and the objects
 * to be observed.  No instances of this class should be needed or created.
 * All methods for coordinating the tracking mechanism are class methods.</p>
 * <p>Observers must implement the [(EOObserving)] protocol, in particular
 * [(EOObserving)-objectWillChange:] while the observed objects must invoke
 * [NSObject-willChange].  Invoke [+addObserver:forObject:] to register an
 * observer for a particular object.  That will setup for 
 * [(EOObserving)-objectWillChange:] to be invoked on the observer each time
 * [NSObject-willChange] gets called.  To remove an observer invoke 
 * [+removeObserver:forObject:].  For observers who wish to be notified for
 * every change the methods [+addOmniscientObserver:] and 
 * [+removeOmniscientObserver:] can be used.</p>
 */

@implementation EOObserverCenter

static NSMapTable *observersMap = NULL;
static NSHashTable *omniscientHash = NULL;
static unsigned int notificationSuppressCount=0;
static id lastObject;


+ (void)initialize
{
  observersMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
				  NSNonOwnedPointerMapValueCallBacks,
				  32);
  omniscientHash = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
  lastObject = nil;

  notificationSuppressCount = 0;
}

/**
 * <p>
 * Adds the observer to be notified with a [(EOObserving)-objectWillChange:] 
 * on the first of consecutive [NSObject-willChange] methods invoked on
 * the object.
 * </p>
 * <p>
 * This does not retain the object.  It is the observers
 * responsibility to unregister the object with [+removeObserver:forObject:]
 * before the object ceases to exist.
 * The observer is also not retained.  It is the observers responsibility
 * to unregister before it ceases to exist.
 * </p>
 * <p>
 * Both observer and object equality are considered equal through pointer
 * equality, so an observer observing multiple objects considered
 * <code>isEqual:</code>
 * will recieve multiple observer notifications,
 * objects considered <code>isEqual:</code> may contain different sets of
 * observers, and an object can have multiple observers considered 
 * <code>isEqual:</code>.
 * </p>
 */
+ (void)addObserver: (id <EOObserving>)observer forObject: (id)object
{
  NSHashTable *observersHash;

  if (observer == nil || object == nil)
    return;
  
  observersHash = NSMapGet(observersMap, object);

  if (observersHash == NULL)
    {
      observersHash = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
      NSMapInsert(observersMap, object, observersHash);
      NSHashInsert(observersHash, observer);
    }
  else
    {
      NSHashInsertIfAbsent(observersHash, observer);
    }
}

/**
 * Removes the observer from being notified on [NSObject-willChange] 
 * invocations of object.
 */
+ (void)removeObserver: (id <EOObserving>)observer forObject: (id)object
{
  NSHashTable *observersHash;

  if (observer == nil || object == nil)
    return;

  observersHash = NSMapGet(observersMap, object);

  if (observersHash)
    {
      NSHashRemove(observersHash, observer);

      if (NSCountHashTable(observersHash) == 0)
        {
	  NSFreeHashTable(observersHash);
          NSMapRemove(observersMap, object);
        }
    }
}

+ (void)_forgetObject:(id)object
{
  if (lastObject == object) lastObject = nil;  
}

/**
 * This method is invoked from [NSObject-willChange] to dispatch
 * [(EOObserving)-objectWillChange:] to all observers registered
 * to observe object.  This method records the last object it was
 * invoked with so that subsequent invocations with the same object
 * get ignored.  Invoke this method with nil as the object to insure
 * that the new changes will be forwarded to the observer.
 * The observer notification can be suppressed with invocations of
 * [+suppressObserverNotification] which must be paired up with invocations 
 * of [+enableObserverNotification] before they are dispatched again.
 */
+ (void)notifyObserversObjectWillChange: (id)object
{
  if (!notificationSuppressCount)
  {
    SEL objectWillChangeSel = @selector(objectWillChange:);
    
    if (object == nil)
    {
      NSHashEnumerator omniscEnum = NSEnumerateHashTable(omniscientHash);
      id obj;
      
      lastObject = nil;
      while ((obj = (id)NSNextHashEnumeratorItem(&omniscEnum)))
	    {
	      [obj performSelector:objectWillChangeSel withObject:object];
	    }
    }
    else if (lastObject != object)
    {
      NSHashTable *observersHash;
      NSHashEnumerator observersEnum;
      id obj;
      
      lastObject = object;
      
      observersHash = NSMapGet(observersMap, object);
      
      if (observersHash)
	    {
	      observersEnum = NSEnumerateHashTable(observersHash);
        
	      while ((obj = (id)NSNextHashEnumeratorItem(&observersEnum)))
        {
          [obj performSelector:objectWillChangeSel withObject:object];
        }
	    }
      
      observersEnum = NSEnumerateHashTable(omniscientHash);
      while ((obj = (id)NSNextHashEnumeratorItem(&observersEnum)))
	    {
	      [obj performSelector:objectWillChangeSel withObject:object];
	    }
    }
  }
  
}

/**
 * Returns an array of observers that have been registered of object.
 * Note that this class is considered 'final' and that for efficiency
 * the observers are accessed directly internally, thus overriding this
 * method could lead to unexpected results.  In other words, if you
 * must subclass then you should override all methods that access
 * the internal map if this method is overridden to use a different
 * store.
 */
+ (NSArray *)observersForObject: (id)object
{
  if (object)
    {
      NSHashTable *observersHash = NSMapGet(observersMap, object);

      if (observersHash)
        {
          return NSAllHashTableObjects(observersHash);
	}
    }
  
  return nil;
}

/**
 * Returns the first observer of the object that matches [-isKindOfClass:] 
 * of the targetClass.
 */
+ (id)observerForObject: (id)object ofClass: (Class)targetClass
{
  NSHashTable *observersHash;
  id observer = nil;
  
  if (object == nil)
    return nil;
  
  observersHash = NSMapGet(observersMap, object);
  if (observersHash)
  {
    NSHashEnumerator observersEnum;
    observersEnum = NSEnumerateHashTable(observersHash);
    
    while ((observer = (id)NSNextHashEnumeratorItem(&observersEnum)))
    {
      if ([observer isKindOfClass: targetClass])
      {
        break; 
      }
    }
    // avoid memory leak! -- dw
    NSEndHashTableEnumeration(&observersEnum);
  }
  
  return observer;
}

/**
 * Increases the notification suppression count.  When the count is 
 * non zero [+notifyObserversObjectWillChange:] invocations do nothing.  
 * Call [+enableObserverNotification] a matching amount of times
 * to enable the dispatch of those notifications again.
 */
+ (void)suppressObserverNotification
{
  notificationSuppressCount++;
}

/**
 * Decreases the notification suppression count.  This should be called
 * to pair up [+suppressObserverNotification] invocations.  When they
 * all have been paired up [+notifyObserversObjectWillChange:] will
 * continue to dispatch [(EOObserving)-objectWillChange:] methods again.
 * If this is invoked when the [+observerNotificationSuppressCount] is 0,
 * this method raises an NSInternalInconsistencyException.
 */
+ (void)enableObserverNotification
{
  if (notificationSuppressCount)
    {
      notificationSuppressCount--;
    }
  else
    {
      [NSException raise: NSInternalInconsistencyException
		   format: @"Unmatched enableObserverNotification invocation"];
    }
}

/**
 * Returns the current observer notification suppress count.
 */
+ (unsigned int)observerNotificationSuppressCount
{
  return notificationSuppressCount;
}

/**
 * Adds observer as an omniscient observer to receive 
 * [(EOObserving)-objectWillChange:] for all objects and nil.
 */
+ (void)addOmniscientObserver: (id <EOObserving>)observer
{
  if (observer)
    NSHashInsertIfAbsent(omniscientHash, observer);
}

/**
 * Removes observer as an omniscient observer.
 */
+ (void)removeOmniscientObserver: (id <EOObserving>)observer
{
  if (observer)
    NSHashRemove(omniscientHash, observer);
}

@end


@implementation EODelayedObserver

/**
 * [(EOObserving)] implementation which enqueues the receiver in the
 * queue returned by observerQueue.
 */
- (void)objectWillChange: (id)subject
{
  [[self observerQueue] enqueueObserver: self];
}

/**
 * Returns the EOObserverPriority of the receiver.  EODelayedObserver 
 * returns EOObserverPriorityThird by default.  Subclasses can override
 * this method to return the corresponding priority.
 */
- (EOObserverPriority)priority
{
  return EOObserverPriorityThird;
}

/**
 * Returns the receivers observer queue.  EODelayedObserver returns
 * [EODelayedObserverQueue+defaultObserverQueue].  Subclasses can
 * override this method to return an applicable queue.
 */
- (EODelayedObserverQueue *)observerQueue
{
  return [EODelayedObserverQueue defaultObserverQueue];
}

/**
 * Invoked by [EODelayedObserverQueue-notifyObserversUpToPriority:] or 
 * [EODelayedObserverQueue-enqueueObserver:].  Overridden by subclasses
 * to process the delayed change notification.  EODelayesObserver does
 * nothing.
 */
- (void)subjectChanged
{
  return;
}

/**
 * Discards all pending notifications of the receiver by dequeuing
 * the receiver from the observer queue returned by [-observerQueue].
 * Subclasses should invoke this method in thier dealloc implementations.
 */
- (void)discardPendingNotification
{
  [[self observerQueue] dequeueObserver: self];
}

@end


/**
 * EODelayedObserverQueue manages the delayed observer notifications
 * for [EODelayedObserver] that register with it.  A delayed observer
 * may only register itself with one queue and a fixed priority.  
 * Upon [-notifyObserversUpToPriority:] all enqueued observers are sent
 * [EODelayedObserver-subjectChanged] according to the EOObserverPriority
 * of the observer.  The first time an observer is enqueued with
 * [-enqueueObserver:] (with a priority other than 
 * EOObserverPriorityImmediate) the queue registers itself with the
 * <code>NSRunLoop currentRunLoop</code> with
 * EOFlushDelayedObserverRunLoopOrdering
 * to invoke [-notifyObserversUpToPriority:] with EOObserverPrioritySixth.
 * In general this mechanism is used by [EOAssociation] subclasses and
 * in part [EODisplayGroup] or even [EOEditingContext].
 */

@implementation EODelayedObserverQueue

static EODelayedObserverQueue *observerQueue;

/**
 * Returns the default queue.
 */
+ (EODelayedObserverQueue *)defaultObserverQueue
{
  if (!observerQueue)
    observerQueue = [[self alloc] init];

  return observerQueue;
}

/**
 * </init>Initializes the an EODelayedObserverQueue 
 * with NSDefaultRunLoopMode.
 */
- init
{
  if (self == [super init])
    {
      ASSIGN(_modes, [NSArray arrayWithObject: NSDefaultRunLoopMode]);
    }

  return self;
}

- (void)_notifyObservers: (id)ignore
{
  [self notifyObserversUpToPriority: EOObserverPrioritySixth];
  _haveEntryInNotificationQueue = NO;
}

/**
 * <p>Registers the observer with the receiver so that it will
 * dispatch [EODelayedObserver-subjectChanged] either immediately,
 * if the observers priority is EOObserverPriorityImmediate, or
 * for the next invocation of [-notifyObserversUpToPriority:].  If
 * this method is invoked during the processing of 
 * [-notifyObserversUpToPriority:], then the dispatch will be enqueue
 * for the current processing.</p>
 * <p>Upon the first invocation within a run loop, this method registers
 * a callback method to have [-notifyObserversUpToPriority:] invoked
 * with EOObserverPrioritySixth with the
 * <code>NSRunLoop currentRunLoop </code>with
 * EOFlushDelayedObserverRunLoopOrdering and the receivers run loop modes.</p>
 * <p>The observer is not retained and should be removed from the receiver
 * with [-dequeueObserver:] during the EODelayedObservers
 * <code>NSObject dealloc</code> method.</p>
 */
- (void)enqueueObserver: (EODelayedObserver *)observer
{
  EOObserverPriority priority = [observer priority];

  if (priority == EOObserverPriorityImmediate)
    [observer subjectChanged];
  else
    {
      if (_queue[priority])
	{
	  EODelayedObserver *obj = _queue[priority];
	  EODelayedObserver *last = nil;

	  for (; obj != nil && obj != observer; obj = obj->_next)
	    {
	      last = obj;
	    }
	  
	  if (obj == observer)
	    {
	      return;
	    }

	  NSAssert2(observer->_next == nil, @"observer:%@ has ->next:%@",
		    observer, observer->_next);

	  NSAssert(last != nil, @"Currupted Queue");
	  last->_next = observer;
	}
      else
	_queue[priority] = observer;

      if (priority > _highestNonEmptyQueue)
	{
	  _highestNonEmptyQueue = priority;
	}

      if (_haveEntryInNotificationQueue == NO)
	{
	  [[NSRunLoop currentRunLoop]
	    performSelector: @selector(_notifyObservers:)
	    target: self
	    argument: nil
	    order: EOFlushDelayedObserversRunLoopOrdering
	    modes: _modes];

	  _haveEntryInNotificationQueue = YES;
	}
    }
}

/**
 * Unregisters the observer from the receiver.
 */
- (void)dequeueObserver: (EODelayedObserver *)observer
{
  EOObserverPriority priority;
  EODelayedObserver *obj, *last = nil;

  if (!observer)
    return;

  priority = [observer priority];
  obj = _queue[priority];

  while (obj)
    {
      if (obj == observer)
	{
	  if (last)
	    {
	      last->_next = obj->_next;
	      obj->_next = nil;
	    }
	  else
	    {
	      _queue[priority] = obj->_next;
	      obj->_next = nil;
	    }


	  if (!_queue[priority])
	    {
	      int i = priority;

	      if (priority >= _highestNonEmptyQueue)
		{
		  for (; i > EOObserverPriorityImmediate; --i)
		    {
		      if (_queue[i])
			{
			  _highestNonEmptyQueue = i;
			  break;
			}
		    }
		}

	      if (priority == EOObserverPriorityFirst
		  || i == EOObserverPriorityImmediate)
		{
		  _highestNonEmptyQueue = EOObserverPriorityImmediate;
		}
	    }

	  return;
	}

      last = obj;
      obj = obj->_next;
    }
}

/**
 * <p>Dispatches registered observer notifications by sending
 * [EODelayedObserver-subjectChanged] to all registered observers
 * of the receiver.  During the processing new enqueObserver: methods will
 * be honored.  It is up toe the callers to ensure no loops result.</p>
 * <p>This method is invoked automatically with EOObserverPrioritySixth
 * during each run loop after an invocation of [-enqueueObserver:].</p>
 * <p>Note that unlike the reference implementation, we dequeue the
 * observer after dispatching [EODelayedObserver-subjectChanged].</p>
 */
- (void)notifyObserversUpToPriority: (EOObserverPriority)priority
{
  EOObserverPriority i = EOObserverPriorityFirst;
  EODelayedObserver *observer = nil;

  while (i <= priority)
    {
      observer = _queue[i];

      if (observer)
	{
	  [self dequeueObserver: observer];
	  [observer subjectChanged];
	  i = EOObserverPriorityFirst;
	}
      else
	{
	  i++;
	}
    }
}

/**
 * Sets the run loop modes the receiver uses when registering
 * for [-notifyObserversUpToPriority:] during [-enqueueObserver:].
 * (see <code>NSRunLoop</code>).
 */
- (void)setRunLoopModes: (NSArray *)modes
{
  ASSIGN(_modes, modes);
}

/**
 * Returns the run loop modes the receiver uses when registering
 * for [-notifyObserversUpToPriority:] during [-enqueueObserver:].
 * (see <code>NSRunLoop</code>).
 */
- (NSArray *)runLoopModes
{
  return _modes;
}

@end

/**
 * This is a convenience class which is initialized with a target,
 * an action method and a priority, to have the action method
 * invoked on the target when the subjectChanged method is invoked
 * by the EODelayedObserverQueue.
 */

@implementation EOObserverProxy

/**
 * Initializes the receiver to dispatch action to target upon processing
 * [-subjectChanged].  The receiver uses priority for the 
 * [EODelayedObserverQueue].
 * Target is not retained.
 */
- (id)initWithTarget: (id)target
	      action: (SEL)action
	    priority: (EOObserverPriority)priority
{
  if ((self = [super init]))
    {
      _target = target;
      _action = action;
      _priority = priority;
    }
  return self;
}

- (void) dealloc
{
  [self discardPendingNotification];
  [super dealloc];
}

/**
 * Returns the priority the receiver was initialized with.
 */
- (EOObserverPriority)priority
{
  return _priority;
}

/**
 * Overridden to dispatch the action method to the target which
 * the receiver was initialized with.
 */
- (void)subjectChanged
{
  [_target performSelector: _action
	   withObject: self];
}

@end
