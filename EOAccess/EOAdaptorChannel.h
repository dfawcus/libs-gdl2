/* -*-objc-*-
   EOAdaptorChannel.h

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

#ifndef __EOAdaptorChannel_h__
#define __EOAdaptorChannel_h__

#ifdef GNUSTEP
#include <Foundation/NSObject.h>
#include <Foundation/NSZone.h>
#else
#include <Foundation/Foundation.h>
#endif

#include <EOAccess/EODefines.h>


@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSString;
@class NSMutableString;
@class NSCalendarDate;
@class NSException;

@class EOModel;
@class EOEntity;
@class EOAttribute;
@class EOAdaptorContext;
@class EOQualifier;
@class EOStoredProcedure;
@class EOAdaptorOperation;
@class EOSQLExpression;
@class EOFetchSpecification;


/* The EOAdaptorChannel class could be overriden for a concrete database
   adaptor. You have to override only those methods marked in this header
   with `override'.
*/

@interface EOAdaptorChannel : NSObject
{
  EOAdaptorContext *_context;
  id _delegate;	// not retained

  BOOL _debug;

  /* Flags used to check if the delegate responds to several messages */
  struct {
    unsigned willPerformOperations:1;
    unsigned didPerformOperations:1;
    unsigned shouldSelectAttributes:1;
    unsigned didSelectAttributes:1;
    unsigned willFetchRow:1;
    unsigned didFetchRow:1;
    unsigned didChangeResultSet:1;
    unsigned didFinishFetching:1;
    unsigned shouldEvaluateExpression:1;
    unsigned didEvaluateExpression:1;
    unsigned shouldExecuteStoredProcedure:1;
    unsigned didExecuteStoredProcedure:1;
    unsigned shouldConstructStoredProcedureReturnValues:1;
    unsigned shouldReturnValuesForStoredProcedure:1;
  } _delegateRespondsTo;
}

+ (EOAdaptorChannel *)adaptorChannelWithAdaptorContext: (EOAdaptorContext *)adaptorContext;

/* Initializing an adaptor context */
- (id)initWithAdaptorContext: (EOAdaptorContext *)adaptorContext;

/* Getting the adaptor context */
- (EOAdaptorContext *)adaptorContext;

/* Opening and closing a channel */
- (BOOL)isOpen;
- (void)openChannel;
- (void)closeChannel;

/* Modifying rows */
- (void)insertRow: (NSDictionary *)row forEntity: (EOEntity *)entity;
- (void)updateValues: (NSDictionary *)values
inRowDescribedByQualifier: (EOQualifier *)qualifier
	      entity: (EOEntity *)entity;

- (NSUInteger) updateValues: (NSDictionary *)values
 inRowsDescribedByQualifier: (EOQualifier *)qualifier
                     entity: (EOEntity *)entity;

- (void)deleteRowDescribedByQualifier: (EOQualifier *)qualifier
                               entity: (EOEntity *)entity;

- (NSUInteger) deleteRowsDescribedByQualifier: (EOQualifier *)qualifier
                                       entity: (EOEntity *)entity;

/* Fetching rows */
- (void)selectAttributes: (NSArray *)attributes
      fetchSpecification: (EOFetchSpecification *)fetchSpecification
		    lock: (BOOL)flag
		  entity: (EOEntity *)entity;

- (void)lockRowComparingAttributes: (NSArray *)attrs
			    entity: (EOEntity *)entity
			 qualifier: (EOQualifier *)qualifier
			  snapshot: (NSDictionary *)snapshot;

- (void)evaluateExpression: (EOSQLExpression *)expression;

- (BOOL)isFetchInProgress;

- (NSArray *)describeResults;

- (NSMutableDictionary *)fetchRowWithZone: (NSZone *)zone;

- (void)setAttributesToFetch: (NSArray *)attributes;

- (NSArray *)attributesToFetch;

- (void)cancelFetch;

/** 
 * Database adaptors need to override this
 */
- (NSDictionary *)primaryKeyForNewRowWithEntity: (EOEntity *)entity;

/**
 * The default implementation just calls
 * primaryKeyForNewRowWithEntity count times.
 * you might override this in subclasses for optimized results.
 */

- (NSArray *)primaryKeysForNewRowsWithEntity:(EOEntity *)entity 
                                       count:(NSUInteger)count;

- (NSArray *)describeTableNames;

- (NSArray *)describeStoredProcedureNames;

- (EOModel *)describeModelWithTableNames: (NSArray *)tableNames;

- (void)addStoredProceduresNamed: (NSArray *)storedProcedureNames
			 toModel: (EOModel *)model;

- (void)setDebugEnabled: (BOOL)flag;
- (BOOL)isDebugEnabled;

- (id)delegate;
- (void)setDelegate: (id)delegate;

- (NSMutableDictionary *)dictionaryWithObjects: (id *)objects
				 forAttributes: (NSArray *)attributes
					  zone: (NSZone *)zone;

@end


@interface EOAdaptorChannel (EOStoredProcedures)

- (void)executeStoredProcedure: (EOStoredProcedure *)storedProcedure
		    withValues: (NSDictionary *)values;
- (NSDictionary *)returnValuesForLastStoredProcedureInvocation;

@end


@interface EOAdaptorChannel (EOBatchProcessing)

- (void)performAdaptorOperation: (EOAdaptorOperation *)adaptorOperation;
- (void)performAdaptorOperations: (NSArray *)adaptorOperations;

@end


@interface NSObject (EOAdaptorChannelDelegation)

- (NSArray *)adaptorChannel: (id)channel
      willPerformOperations: (NSArray *)operations;

- (NSException *)adaptorChannel: (id)channel
	   didPerformOperations: (NSArray *)operations
		      exception: (NSException *)exception;

- (BOOL)adaptorChannel: (id)channel
shouldSelectAttributes: (NSArray *)attributes
    fetchSpecification: (EOFetchSpecification *)fetchSpecification
		  lock: (BOOL)flag
		entity: (EOEntity *)entity;

- (void)adaptorChannel: (id)channel
   didSelectAttributes: (NSArray *)attributes
    fetchSpecification: (EOFetchSpecification *)fetchSpecification
		  lock: (BOOL) flag
		entity: (EOEntity *)entity;

- (void)adaptorChannelWillFetchRow: (id)channel;

- (void)adaptorChannel: (id)channel didFetchRow: (NSMutableDictionary *)row;

- (void)adaptorChannelDidChangeResultSet: (id)channel;

- (void)adaptorChannelDidFinishFetching: (id)channel;

- (BOOL)adaptorChannel: (id)channel
shouldEvaluateExpression: (EOSQLExpression *)expression;

- (void)adaptorChannel: (id)channel
 didEvaluateExpression: (EOSQLExpression *)expression;

- (NSDictionary *)adaptorChannel: (id)channel
    shouldExecuteStoredProcedure: (EOStoredProcedure *)procedure
		      withValues: (NSDictionary *)values;

- (void)adaptorChannel: (id)channel
didExecuteStoredProcedure: (EOStoredProcedure *)procedure
	    withValues: (NSDictionary *)values;

- (NSDictionary *)adaptorChannelShouldConstructStoredProcedureReturnValues: (id)channel;

- (NSDictionary *)adaptorChannel: (id)channel
shouldReturnValuesForStoredProcedure: (NSDictionary *)returnValues;

@end /* NSObject(EOAdaptorChannelDelegation) */


GDL2ACCESS_EXPORT NSString *EOAdaptorOperationsKey;
GDL2ACCESS_EXPORT NSString *EOFailedAdaptorOperationKey;
GDL2ACCESS_EXPORT NSString *EOAdaptorFailureKey;
GDL2ACCESS_EXPORT NSString *EOAdaptorOptimisticLockingFailure;


#endif /* __EOAdaptorChannel_h__ */
