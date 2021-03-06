/**
   eoutil.m <title>eoutil Tool</title>

   Copyright (C) 2003,2004,2005 Free Software Foundation, Inc.

   Author: Stephane Corthesy <stephane@sente.ch>
   Date: February 2003

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
#include <Foundation/NSDecimalNumber.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSData.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#endif

#include <EOControl/EOControl.h>
#include <EOAccess/EOAccess.h>

/*
 TODO
 Implement -ascii option
 Test multiple models
 Add new option -dateFormat ISO|Apple (has ISO enough precision for microseconds?)
 Add new option -nullValue '__NULL__'
 Question: is it possible to save/restore sequences (for PK)?
 Replace all autorelease/release/retain by macros
 Document plist format
 Document usage
 Optimization: if not -force, do all EOF ops in one go
 */

@interface NSString(eoutil)
- (NSString *) lossyASCIIString;
@end


@implementation NSString(eoutil)

- (NSString *) lossyASCIIString
{
  NSData *d;

  d = [self dataUsingEncoding: NSASCIIStringEncoding 
         allowLossyConversion: YES];
  return [[[NSString alloc] initWithData: d 
                                encoding: NSASCIIStringEncoding] autorelease];
}

@end

// TODO
// Add support to read/write multiple plists, one per entity
// -source plists    where 'plists' is a directory name (created if necessary)
// In the directory, create one plist per entity

static BOOL
usage(BOOL fullUsage)
{
  char *usageString;

  if (fullUsage)
    usageString = "Command line utility to perform database and EOF oriented tasks.\n"
      "Syntax: eoutil dump/connect/convert\n"
      "  eoutil dump <model> [-source <source> [sourcefile]] -dest <dest> [destfile] [-schemaCreate <options>] [-schemaDrop <options>] [-postInstall] [-force] [-connDict <connection dictionary>] [-entities <entities>] [-excludedEntities <entities>] [-modelGroup <modelGroup>] [-ascii]\n"
      "\tThis command reads data from <source> and dumps it to <dest>. The dump may\n"
      "\tinclude bits of DML that create bits of database schema. The -source flag is\n"
      "\toptional if only schema is to be created (i.e. no data is being dumped). The\n"
      "\tfollowing is a list of possible values for each of the arguments in the command:\n"
      "\t   model -- must be the name of an eomodel or eomodeld file\n"
      "\t   source -- 'plist' (read from stdin unless source file is specified) or\n"
      "\t             'database' (uses model to connect)\n"
      "\t   sourcefile -- name of file to read plist from\n"
      "\t   dest -- 'plist' or 'script' (both are written to stdout unless destfile is\n"
      "\t           specified) or 'database' (uses model to connect)\n"
      "\t   destfile -- name of file to write plist or script\n"
      "\t   options -- 'database', 'tables', 'primaryKeySupport',\n"
      "\t              'primaryKeyConstraints' or 'foreignKeyConstraints'\n"
      "\t   postInstall -- looks in the userInfo dictionary for an array of SQL strings\n"
      "\t                  to process after any schema creation and data dumping is done\n"
      "\t   force -- Do not quit processing after database error\n"
      "\t   connDict -- A substitute connection dictionary\n"
      "\t   entities -- a subset of the entities in the model (all are used by default)\n"
      "\t   excludedEntities -- a subset of the entities in the model which shall not be used (all are used by default)\n"
      "\t   modelGroup -- A list of models to create a model group. (Allows you to use\n"
      "\t                 models not in a framework. Model names must be absolute paths.)\n"
      "\t   ascii -- Convert all non-ASCII characters to their nearest ASCII equivalents.\n"
      "\n"
      "\tExample: eoutil dump Movies.eomodeld -source plist -dest database -schemaCreate tables primaryKeySupport foreignKeyConstraints < MovieData.plist\n"
      "\t         Creates the tables in the database, reads data in plist format from,\n"
      "\t         stdin stores the data in the database listed in the connection\n"
      "\t         dictionary of model, creates primary key support in the database, and\n"
      "\t         creates foreign key constraints corresponding to the relationship\n"
      "\t         definitions.\n"
      "\n"
      "  eoutil convert <model> <adaptorName> <connectionDictionary> <outFileName>\n"
      "\tThis command converts the type mapping in a model for the data source specified\n"
      "\tby the connection dictionary URL. The connection dictionary in the new model is\n"
      "\tset to connectionDictionary.\n"
      "\n"
      "\t   model -- must be the name of an eomodel or eomodeld file\n"
      "\t   adaptorName -- PostgreSQL, FlatFile, etc.\n"
      "\t   connectionDictionary -- string in property list format representing a\n"
      "\t                           dictionary, specifying the database name for the\n"
      "\t                           data source (required) and username and password (if\n"
      "\t                           required by that data source).\n"
      "\t   outFileName -- the name of a directory to write the converted model\n"
      "\n"
      "\tExample: eoutil convert Movies.eomodeld PostgreSQL '{ databaseName = test; hostName = localhost; userName = postgres; password = postgres; }' M.eomodeld\n"
      "\t         Converts types in Movies.eomodeld file to PostgreSQL types and writes\n"
      "\t         the converted model to ./M.eomodel\n"
      "\n"
      "  eoutil connect (<model> | (<adaptorName> <connectionDictionary>))\n"
      "\tThis command attempts to connect to a data source using the adaptor named\n"
      "\tadaptorName with connectionDictionary, or using the connection dictionary in\n"
      "\tmodel. It returns an exit status of 0 if successful and 1 otherwise. This is\n"
      "\tprimarily useful for scripts.\n"
      "\n"
      "\t   model -- must be the name of an eomodel or eomodeld file\n"
      "\t   adaptorName -- PostgreSQL, FlatFile, etc.\n"
      "\t   connectionDictionary -- string in property list format representing a\n"
      "\t                           dictionary, specifying the database name for the\n"
      "\t                           data source (required) and username and password (if\n"
      "\t                           required by that data source).\n"
      "\n"
      "\tExample: eoutil connect PostgreSQL '{ databaseName = test; hostName = localhost; userName = postgres; password = postgres; }'\n"
      "\t         Attempts to connect to a PostgreSQL database on host localhost.\n"
      "\n"
      "  eoutil help\n"
      "\tPrints this text.\n"
      "\n";
  else
    usageString = "Command line utility to perform database and EOF oriented tasks.\n"
      "Syntax: eoutil dump/connect/convert/help\n"
      "  eoutil dump <model> [-source <source> [sourcefile]] -dest <dest> [destfile] [-schemaCreate <options>] [-schemaDrop <options>] [-postInstall] [-force] [-connDict <connection dictionary>] [-entities <entities>] [-modelGroup <modelGroup>] [-ascii]\n"
      "  eoutil convert <model> <adaptorName> <connectionDictionary> <outFileName>\n"
      "  eoutil connect (<model> | (<adaptorName> <connectionDictionary>))\n"
      "  eoutil help\n";
    
  NSLog(@"%s", usageString);

  return YES;
}


enum {
  databaseOption = 1 << 0,
  tablesOption = 1 << 1,
  pkSupportOption = 1 << 2,
  pkConstraintsOption = 1 << 3,
  fkConstraintsOption = 1 << 4,
};


static void executeSQLStatements(EOModel *srcModel, NSArray *sqlStatements, BOOL force){
    EODatabaseContext	*aDatabaseContext;
    EOEditingContext	*anEC = [[EOEditingContext alloc] init];
    
    aDatabaseContext =
	    [EODatabaseContext registeredDatabaseContextForModel: srcModel
                                              editingContext: anEC];
    
    [aDatabaseContext lock];
    
    NS_DURING
    {
        EODatabaseChannel *aDatabaseChannel = [aDatabaseContext
            availableChannel];
        EOAdaptorChannel *anAdaptorChannel = [aDatabaseChannel
            adaptorChannel];
        NSEnumerator *anEnum;
        EOSQLExpression *aStatement;
        
        if (![anAdaptorChannel isOpen])
            [anAdaptorChannel openChannel];
        
        anEnum = [sqlStatements objectEnumerator];
        
        while ((aStatement = [anEnum nextObject]))
		{
            NS_DURING
                [anAdaptorChannel evaluateExpression: aStatement];
            NS_HANDLER
                if(!force)
                    break;
            NS_ENDHANDLER;
		}
            
        [aDatabaseContext unlock];
        [anEC release];
    }
    NS_HANDLER
    {
        [aDatabaseContext unlock];
        [anEC release];
        [localException raise];
    }
    NS_ENDHANDLER;
}


static BOOL
dump(NSArray *arguments)
{
  int			 aCount = [arguments count], i = 0;
  EOModel		*srcModel;
  NSString		*sourceType = nil, *sourceFilename = nil;
  NSString		*destType = nil, *destFilename = nil;
  int			 schemaCreateOptions = 0, schemaDropOptions = 0;
  BOOL			 postInstall = NO;
  BOOL			 force = NO;
  NSDictionary		*aConnectionDictionary = nil;
  NSMutableArray	*entityNameList = nil, *excludedEntityNameList = nil;
  NSMutableArray	*entitiesList = nil;
  NSMutableArray	*modelList = nil;
  BOOL			 convertsNonASCII = NO;
  NSMutableString	*outputString = [NSMutableString string];
  NSArray		*initialStatements = nil;
  NSArray		*endingStatements = nil;
  NSDictionary		*dataDictionary = nil;
  Class			 exprClass;
  NSArray	*postInstallSQLExpressions = nil;
  
  // First, let's parse arguments
  srcModel = [[EOModel alloc] initWithContentsOfFile: [[arguments objectAtIndex: i++]
						stringByStandardizingPath]];
  [srcModel autorelease];

  while (i < aCount)
    {
      NSString	*anArg = [arguments objectAtIndex: i++];

      if ([anArg isEqualToString: @"-source"])
	{
	  if (sourceType != nil)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-source'"];

	  if (i < aCount)
	    sourceType = [arguments objectAtIndex: i++];
	  else
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument(s) after '-source'"];

	  if (![sourceType isEqualToString: @"database"])
	    {
	      if ([sourceType isEqualToString: @"plist"])
		{
		  if (i < aCount)
		    {
		      sourceFilename = [[arguments objectAtIndex: i++]
					 stringByStandardizingPath];

		      if ([sourceFilename hasPrefix: @"-"])
			{
			  // We consider it's an option, not a filename
			  sourceFilename = nil;
			  i--;
			}
                    }
                }
	      else
		[NSException raise: NSInvalidArgumentException
			     format: @"Illegal '-source' option: %@",
			     sourceType];
            }
        }
      else if ([anArg isEqualToString: @"-dest"])
	{
	  if (destType != nil)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-dest'"];

	  if (i < aCount)
	    destType = [arguments objectAtIndex: i++];
	  else
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument(s) after '-dest'"];

	  if (![destType isEqualToString: @"database"])
	    {
	      if ([destType isEqualToString: @"script"]
		  || [destType isEqualToString: @"plist"])
		{
		  if (i < aCount)
		    {
		      destFilename = [[arguments objectAtIndex: i++]
				       stringByStandardizingPath];

		      if ([destFilename hasPrefix: @"-"])
			{
			  // We consider it's an option, not a filename
			  destFilename = nil;
			  i--;
			}
                    }
                }
	      else
		[NSException raise: NSInvalidArgumentException
			     format: @"Illegal '-dest' option: %@", destType];
            }
        }
      else if ([anArg isEqualToString: @"-schemaCreate"])
	{
	  if (schemaCreateOptions != 0)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-schemaCreate'"];

	  while (i < aCount)
	    {
	      anArg = [arguments objectAtIndex: i++];

	      if ([anArg isEqualToString: @"database"])
		schemaCreateOptions |= databaseOption;
	      else if ([anArg isEqualToString: @"tables"])
		schemaCreateOptions |= tablesOption;
	      else if ([anArg isEqualToString: @"primaryKeySupport"])
		schemaCreateOptions |= pkSupportOption;
	      else if ([anArg isEqualToString: @"primaryKeyConstraints"])
		schemaCreateOptions |= pkConstraintsOption;
	      else if ([anArg isEqualToString: @"foreignKeyConstraints"])
		schemaCreateOptions |= fkConstraintsOption;
	      else
		{
		  if (![anArg hasPrefix:@"-"])
		    [NSException raise: NSInvalidArgumentException
				 format: @"Illegal '-schemaCreate' option: %@", anArg];
		  i--;
		  break;
		}
            }

	  if (schemaCreateOptions == 0)
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument(s) after '-schemaCreate'"];
        }
      else if ([anArg isEqualToString: @"-schemaDrop"])
	{
	  if (schemaDropOptions != 0)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-schemaDrop'"];

	  while (i < aCount)
	    {
	      anArg = [arguments objectAtIndex: i++];

	      if ([anArg isEqualToString: @"database"])
		schemaDropOptions |= databaseOption;
	      else if ([anArg isEqualToString: @"tables"])
		schemaDropOptions |= tablesOption;
	      else if ([anArg isEqualToString: @"primaryKeySupport"])
		schemaDropOptions |= pkSupportOption;
	      /*                else if ([anArg isEqualToString: @"primaryKeyConstraints"])
				schemaDropOptions |= pkConstraintsOption;
				else if ([anArg isEqualToString: @"foreignKeyConstraints"])
				schemaDropOptions |= fkConstraintsOption;*/
	      else
		{
		  if (![anArg hasPrefix: @"-"])
		    [NSException raise: NSInvalidArgumentException
				 format: @"Illegal '-schemaDrop' option: %@",
				 anArg];
		  i--;
		  break;
                }
            }

	  if (schemaDropOptions == 0)
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument(s) after '-schemaDrop'"];
        }
      else if ([anArg isEqualToString: @"-postInstall"])
	{
	  if (postInstall)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-postInstall'"];
	  postInstall = YES;
        }
      else if ([anArg isEqualToString: @"-force"])
	{
	  if (force)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-force'"];
	  force = YES;
        }
      else if ([anArg isEqualToString: @"-ascii"])
	{
	  if (convertsNonASCII)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-ascii'"];
	  convertsNonASCII = YES;
        }
      else if ([anArg isEqualToString: @"-connDict"])
	{
	  if (aConnectionDictionary)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-connDict'"];

	  if (i < aCount)
	    {
	      aConnectionDictionary = [[arguments objectAtIndex: i++]
					propertyList];

	      if (![aConnectionDictionary isKindOfClass: [NSDictionary class]])
		[NSException raise: NSInvalidArgumentException
			     format: @"Invalid '-connDict' argument; must be a NSDictionary"];
	    }
	  else
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument after '-connDict'"];
        }
      else if ([anArg isEqualToString: @"-entities"])
	{
	  if (entityNameList)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-entities'"];

	  entityNameList = [NSMutableArray array];

	  while (i < aCount)
	    {
	      anArg = [arguments objectAtIndex: i++];

	      if ([anArg hasPrefix: @"-"])
		{
		  // We consider it's an option, not an entity name
		  i--;
		  break;
		}

	      if ([entityNameList containsObject: anArg])
		[NSException raise: NSInvalidArgumentException
			     format: @"Entity name argument '%@' occurs more than once", anArg];

	      [entityNameList addObject: anArg];
            }

	  if ([entityNameList count] == 0)
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument(s) after '-entities'"];
        }
      else if ([anArg isEqualToString: @"-excludedEntities"])
      {
          if (excludedEntityNameList)
              [NSException raise: NSInvalidArgumentException
                          format: @"More than one occurence of parameter '-excludedEntities'"];
          
          excludedEntityNameList = [NSMutableArray array];
          
          while (i < aCount)
          {
              anArg = [arguments objectAtIndex: i++];
              
              if ([anArg hasPrefix: @"-"])
              {
                  // We consider it's an option, not an entity name
                  i--;
                  break;
              }
              
              if ([excludedEntityNameList containsObject: anArg])
                  [NSException raise: NSInvalidArgumentException
                              format: @"Entity name argument '%@' occurs more than once", anArg];
              
              [excludedEntityNameList addObject: anArg];
          }
          
          if ([excludedEntityNameList count] == 0)
              [NSException raise: NSInvalidArgumentException
                          format: @"Missing argument(s) after '-excludedEntities'"];
      }
      else if ([anArg isEqualToString: @"-modelGroup"])
	{
	  if (modelList)
	    [NSException raise: NSInvalidArgumentException
			 format: @"More than one occurence of parameter '-modelGroup'"];

	  modelList = [NSMutableArray array];

	  while (i < aCount)
	    {
	      anArg = [[arguments objectAtIndex: i++]
			stringByStandardizingPath];

	      if ([anArg hasPrefix: @"-"])
		{
		  // We consider it's an option, not a file name
		  i--;
		  break;
                }

	      if ([modelList containsObject: anArg])
		[NSException raise: NSInvalidArgumentException
			     format: @"Model file name argument '%@' occurs more than once", anArg];

	      if (![anArg isAbsolutePath])
		anArg = [[[NSFileManager defaultManager]
			   currentDirectoryPath]
			  stringByAppendingPathComponent:anArg];
	      //                    [NSException raise:NSInvalidArgumentException format:@"Model file name argument '%@' is not absolute", anArg];

	      [modelList addObject: anArg];
            }

	  if ([modelList count] == 0)
	    [NSException raise: NSInvalidArgumentException
			 format: @"Missing argument(s) after '-modelGroup'"];
        }
      else
	// Else, ignore remaining args
	break;
    }

  // Now check parameter consistency
  if (!destType)
    [NSException raise: NSInvalidArgumentException
		 format: @"Missing -dest <dest> [destfile] argument"];

  if (sourceType == nil && schemaCreateOptions == 0 && schemaDropOptions == 0)
    [NSException raise: NSInvalidArgumentException
		 format: @"Unknown operation"];

  if ([destType isEqualToString: @"plist"]
      && (schemaDropOptions != 0 || schemaCreateOptions != 0))
    [NSException raise: NSInvalidArgumentException
		 format: @"Can't declare plist as destination and use schema arguments"];

  // Load models
  {
    EOModelGroup *defaultModelGroup = [EOModelGroup globalModelGroup];

    [defaultModelGroup addModel: srcModel];

    if (modelList)
      {
	// Load other models in same model group
	NSEnumerator	*anEnum = [modelList objectEnumerator];
	NSString	*aString;

	while ((aString = [anEnum nextObject]))
	  {
	    (void)[defaultModelGroup addModelWithFile: aString];
	  }
      }

    [defaultModelGroup loadAllModelObjects];
    [EOModelGroup setDefaultGroup: defaultModelGroup];
  }

  // Create entity list
  if (entityNameList)
    {
      NSEnumerator	*anEnum = [entityNameList objectEnumerator];
      NSString		*aString;

      entitiesList = [NSMutableArray array];
      while ((aString = [anEnum nextObject]))
	{
          if(![excludedEntityNameList containsObject:aString]){
              EOEntity *anEntity = [[EOModelGroup defaultGroup]
				 entityNamed: aString];
              
              if (anEntity == nil)
                  [NSException raise: NSInvalidArgumentException
                              format: @"Unknown entity '%@'", aString];
              
              [entitiesList addObject: anEntity];
          }
      }
    }
  else
    {
      NSEnumerator	*anEnum = [[srcModel entities] objectEnumerator];
      EOEntity		*anEntity;

      entitiesList = [NSMutableArray array];
      while ((anEntity = [anEnum nextObject])){
          if(![excludedEntityNameList containsObject:[anEntity name]]){
	[entitiesList addObject:anEntity];
          }
      }
    }

  if (aConnectionDictionary)
    {
      [srcModel setConnectionDictionary: aConnectionDictionary];
      // Only for srcModel, not for additional models?
    }

  exprClass = [[EOAdaptor adaptorWithModel: srcModel] expressionClass];
  if (schemaDropOptions != 0 || schemaCreateOptions != 0)
    {
      // We split SQL execution in two parts: first we drop elements, and create tables,
      // and in a second phase we create constraints: this allows us to fill in database with data
      // and then we set the database constraints.
      NSDictionary *aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
						  ((schemaDropOptions & databaseOption) ? @"YES":@"NO"), EODropDatabaseKey,
						((schemaDropOptions & tablesOption) ? @"YES":@"NO"), EODropTablesKey,
						((schemaDropOptions & pkSupportOption) ? @"YES":@"NO"), EODropPrimaryKeySupportKey,
						//            ((schemaDropOptions & pkConstraintsOption) ? @"YES":@"NO"), EOPrimaryKeyConstraintsKey,
						//            ((schemaDropOptions & fkConstraintsOption) ? @"YES":@"NO"), EOForeignKeyConstraintsKey,
						((schemaCreateOptions & databaseOption) ? @"YES":@"NO"), EOCreateDatabaseKey,
						((schemaCreateOptions & tablesOption) ? @"YES":@"NO"), EOCreateTablesKey,
                        @"NO", EOCreatePrimaryKeySupportKey,
                        @"NO", EOPrimaryKeyConstraintsKey,
                        @"NO", EOForeignKeyConstraintsKey,
          nil];
      NSEnumerator	*anEnum;
      EOSQLExpression	*aStatement;

      if([aDictionary count] > 0)
          initialStatements = [exprClass schemaCreationStatementsForEntities: entitiesList
                                                                     options: aDictionary];

      aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
          @"NO", EODropDatabaseKey,
          @"NO", EODropTablesKey,
          @"NO", EODropPrimaryKeySupportKey,
          //            @"NO", EOPrimaryKeyConstraintsKey,
          //            @"NO", EOForeignKeyConstraintsKey,
          @"NO", EOCreateDatabaseKey,
          @"NO", EOCreateTablesKey,
          ((schemaCreateOptions & pkSupportOption) ? @"YES":@"NO"), EOCreatePrimaryKeySupportKey,
          ((schemaCreateOptions & pkConstraintsOption) ? @"YES":@"NO"), EOPrimaryKeyConstraintsKey,
          ((schemaCreateOptions & fkConstraintsOption) ? @"YES":@"NO"), EOForeignKeyConstraintsKey,
          nil];
      if([aDictionary count] > 0)
          endingStatements = [exprClass schemaCreationStatementsForEntities: entitiesList
                                                                    options: aDictionary];
      
      if(initialStatements){
          if ([destType isEqualToString: @"database"])
          {
              executeSQLStatements(srcModel, initialStatements, force);
          }
          else
          {
              // script
              anEnum = [initialStatements objectEnumerator];
              while ((aStatement = [anEnum nextObject]))
                  [exprClass appendExpression: aStatement toScript: outputString];
          }
      }
    }

  if (sourceType)
    {
      // Dump
      if ([sourceType isEqualToString: @"plist"])
	{
	  if (sourceFilename)
	    {
	      dataDictionary = [[NSDictionary alloc]
				 initWithContentsOfFile: sourceFilename];

	      NSCAssert1(dataDictionary != nil,
			 @"Unable to read plist from file '%@'",
			 sourceFilename);
            }
#ifndef GNUSTEP
	  else
	    {
#warning TODO: test this
	      NSString	*errorString = nil;
	      NSData	*readData = [[NSFileHandle fileHandleWithStandardInput]
				      readDataToEndOfFile];
                
	      dataDictionary = [NSPropertyListSerialization
				 propertyListFromData: readData
				 mutabilityOption: NSPropertyListImmutable
				 format: NULL
				 errorDescription: &errorString];

	      if (errorString != nil)
		[NSException raise: NSInvalidArgumentException
			     format: @"Unable to load plist from stdin: %@", errorString];
	      if (![dataDictionary isKindOfClass:[NSDictionary class]])
		[NSException raise: NSInvalidArgumentException
			     format: @"Invalid plist format from stdin: should be a dictionary"];

	      [dataDictionary retain];
            }
#endif
        }
      else
	{
	  // database
	  // We get data from database
	  NSEnumerator		*anEnum = [entitiesList objectEnumerator];
	  EOEntity		*anEntity;
	  EOEditingContext	*aContext = [[EOEditingContext alloc] init];

	  dataDictionary = [[NSMutableDictionary alloc] init];
	  while ((anEntity = [anEnum nextObject]))
	    {
	      // We don't fetch abstract entities
	      if (![anEntity isAbstractEntity])
		{
              NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
		  NSArray		*attributes = [anEntity attributes];
		  NSEnumerator		*anAttrEnum = [attributes
							objectEnumerator];
		  EOAttribute		*anAttribute;
		  NSMutableArray	*attributeNames = [NSMutableArray
							    array];
		  NSArray		*rawRows;
		  NSMutableArray	*rows;
		  EOFetchSpecification	*fetchSpec;
		  NSDictionary		*aRawRow;
          BOOL              usesPlistTypesOnly = [destType isEqualToString: @"plist"];
                    
		  while ((anAttribute = [anAttrEnum nextObject]))
		    {
              // We do fetch flattened or derived attributes (but we will not write them)
			[attributeNames addObject: [anAttribute name]];
		    }

		  fetchSpec = [EOFetchSpecification fetchSpecificationWithEntityName: [anEntity name]
						    qualifier: nil
						    sortOrderings: nil];
		  [fetchSpec setFetchesRawRows: YES];

		  rows = [NSMutableArray array];
          // FIXME Problem
          // If a raw row contains data which does not respect entity's constraints
          // (e.g. doesn't allow NULL attribute), then an exception is raised,
          // at least on WO4.5
		  rawRows = [aContext objectsWithFetchSpecification: fetchSpec];
		  anAttrEnum = [rawRows objectEnumerator];

		  while ((aRawRow = [anAttrEnum nextObject]))
		    {
		      NSMutableArray	*values = [NSMutableArray array];
		      NSEnumerator	*anEnum3 = [attributeNames
						     objectEnumerator];
		      NSString		*aName;

		      while ((aName = [anEnum3 nextObject]))
			{
			  id aValue = [aRawRow objectForKey: aName];

			  if ([aValue isEqual: [EONull null]])
			    [values addObject: @"__NULL__"];
			  else
			    {
			      if ([aValue isKindOfClass: [NSString class]])
				{
				  if (convertsNonASCII)
				    [values addObject: [aValue
							 lossyASCIIString]];
				  else
				    [values addObject: aValue];
				}
                  else if(usesPlistTypesOnly){
                      if ([aValue isKindOfClass:[NSCalendarDate class]]){
                          // Format is ISO's + milliseconds
                          [values addObject:[aValue descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S.%F %z" /*local:*/]];
                      }
                      else if ([aValue isKindOfClass:[NSData class]])
                          [values addObject:[aValue description]];
/*                      else if ([aValue isKindOfClass:[NSDecimalNumber class]])
                          [values addObject:[aValue stringValue]];*/
                      else if ([aValue isKindOfClass:[NSNumber class]])
                          [values addObject:[aValue stringValue]];
                      else
                          // FIXME No support for custom data types?
                          [values addObject: aValue];
                  }			      
			      else
				[values addObject: aValue];
			    }
			}
		      [rows addObject: values];
		    }

		  [(NSMutableDictionary *)dataDictionary
					  setObject: [NSDictionary dictionaryWithObjectsAndKeys: attributeNames, @"attributeNames", rows, @"rows", nil]
					  forKey: [anEntity name]];
          [arp release];
		}
	    }
	  [aContext release];
	}
    }
  // Else, no sourcefile => schemaDrop and/or schemaCreate

  if (postInstall)
        {
            // Look for a key "AdaptorName"PostInstallExpressions which
            // which have an array of SQL expressions
            postInstallSQLExpressions = [[srcModel userInfo] objectForKey:[[[EOAdaptor adaptorWithModel: srcModel] name] stringByAppendingString:@"PostInstallExpressions"]];
        }

  if ([destType isEqualToString: @"plist"])
    {
      // Write data as plist
      NSCAssert(dataDictionary != nil, @"No data to write in plist?!?");
        
      if (destFilename)
	NSCAssert1([[dataDictionary description] writeToFile:destFilename atomically:NO], @"Unable to write plist to '%@'", destFilename);
      else
	[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:[[dataDictionary description] dataUsingEncoding:NSUTF8StringEncoding]];
    }
  else if ([destType isEqualToString: @"script"])
    {
      // Write schemaDrop and/or schemaCreate script, or data creation SQL script
      if (dataDictionary)
	{
	  // Generate SQL to create data from dataDictionary
	  NSEnumerator	*entityNameEnum = [dataDictionary keyEnumerator];
	  NSString	*anEntityName;

#warning PROBLEM: we cannot create the statement telling to defer constraints!
	  // In the script, we miss:
	  // BEGIN;
	  // SET CONSTRAINTS ALL DEFERRED;
	  // ...
	  // COMMIT

	  while ((anEntityName = [entityNameEnum nextObject]))
	    {
          NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
	      EOEntity			*anEntity = [[EOModelGroup defaultGroup] entityNamed: anEntityName];
	      NSEnumerator		*aRowEnum = [[[dataDictionary objectForKey: anEntityName] objectForKey: @"rows"] objectEnumerator];
	      NSMutableDictionary	*aDict = [NSMutableDictionary dictionary];
	      NSArray			*aRow, *attrNames = [[dataDictionary objectForKey: anEntityName] objectForKey: @"attributeNames"];

	      while ((aRow = [aRowEnum nextObject]))
		{
		  NSEnumerator	*anAttributeEnum = [attrNames objectEnumerator];
		  NSEnumerator	*aValueEnum = [aRow objectEnumerator];
		  NSString	*anAttrName;

		  while ((anAttrName = [anAttributeEnum nextObject]))
		    {
		      id aValue = [aValueEnum nextObject];

		      if (![aValue isKindOfClass: [NSString class]]
			  || ![aValue isEqualToString: @"__NULL__"])
			[aDict setObject: aValue forKey: anAttrName];
                    }

		  [exprClass appendExpression:
			       [exprClass insertStatementForRow: aDict
					  entity: anEntity]
			     toScript: outputString];
		  [aDict removeAllObjects];
                }
          [arp release];
            }
        }

      if (postInstallSQLExpressions)
	{
              [outputString appendString:[postInstallSQLExpressions componentsJoinedByString:@"\n"]];
        }
      if (destFilename)
	{
	  if (![outputString writeToFile: destFilename atomically: NO])
	    [NSException raise: NSInvalidArgumentException
			 format: @"Unable to save file '%@'", destFilename];
        }
      else
	[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput]
			 writeData: [outputString dataUsingEncoding:
						    NSUTF8StringEncoding]];
    }
  else
    {
      // database
      // Execute statements one after the other?
      if (dataDictionary)
	{
	  NSEnumerator		*entityEnum = [entitiesList objectEnumerator];
	  EOEntity		*anEntity;
	  EOEditingContext	*anEC = [[EOEditingContext alloc] init];

      [anEC setUndoManager:nil];
      
	  while ((anEntity = [entityEnum nextObject]))
	    {
          NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
	      NSDictionary		*aDictionary = [dataDictionary objectForKey: [anEntity name]];
	      NSArray			*attributeNames = [aDictionary objectForKey: @"attributeNames"];
	      NSEnumerator		*anEnum = [attributeNames objectEnumerator];
	      NSString			*aName;
	      NSMutableSet		*newClassProperties = [NSMutableSet set];
	      EORelationship		*aRelationship;

	      if ([anEntity isReadOnly])
		[anEntity setReadOnly: NO];
	      if (![[anEntity className] isEqualToString: @"EOGenericRecord"])
		[anEntity setClassName: @"EOGenericRecord"];

	      while ((aName = [anEnum nextObject]))
		{
		  EOAttribute	*anAttribute = [anEntity attributeNamed: aName];

		  NSCAssert1(anAttribute != nil,
			     @"'%@' is not a valid attribute name", aName);

		  if (![anAttribute isReadOnly] && ![anAttribute isDerived])
              [newClassProperties addObject: anAttribute];
                }

	      NSCAssert1([anEntity setClassProperties:[newClassProperties allObjects]], @"Unable to set new class properties from %@", newClassProperties);

	      anEnum = [[NSArray arrayWithArray: [anEntity relationships]]
			 objectEnumerator];

	      while ((aRelationship = [anEnum nextObject]))
		{
		  [anEntity removeRelationship: aRelationship];
                }
          [arp release];
            }

	  entityEnum = [entitiesList objectEnumerator];
	  while ((anEntity = [entityEnum nextObject]))
	    {
          NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
	      NSDictionary	*aDictionary = [dataDictionary objectForKey: [anEntity name]];
	      NSEnumerator	*rowEnum = [[aDictionary objectForKey: @"rows"] objectEnumerator];
	      NSArray		*aRow;
	      NSArray		*attributeNames = [aDictionary objectForKey: @"attributeNames"];
	      NSEnumerator	*attrNameEnum = [attributeNames objectEnumerator];
	      NSString		*anAttrName;
          NSMutableArray    *filteredAttributeNames = [NSMutableArray array];
          NSArray       *classPropertyNames = [anEntity classPropertyNames];
          
          // First, we filter out given attribute names to retain only
          // the ones that have a matching class property
          // (we already cleaned up entities attributes/relationships)
		  while ((anAttrName = [attrNameEnum nextObject])){
              if([classPropertyNames containsObject:anAttrName])
                  [filteredAttributeNames addObject:anAttrName];
          }
          
	      while ((aRow = [rowEnum nextObject]))
		{
              NSAutoreleasePool *arp2 = [[NSAutoreleasePool alloc] init];
		  EOGenericRecord *aRecord = [anEC createAndInsertInstanceOfEntityNamed: [anEntity name]];

		  attrNameEnum = [filteredAttributeNames objectEnumerator];
		  while ((anAttrName = [attrNameEnum nextObject]))
		    {
		      NSString	*aStringValue;
		      id	 aValue = nil;

              i = [attributeNames indexOfObject:anAttrName];
              aStringValue = [aRow objectAtIndex: i];
		      if ([aStringValue isEqualToString: @"__NULL__"])
			aValue = [EONull null];
		      else
			{
			  EOAttribute *anAttribute = [anEntity attributeNamed:
								 anAttrName];
			  NSString    *internalType = [anAttribute
							valueClassName];

			  if ([internalType isEqualToString: @"NSString"])
			    {
			      aValue = aStringValue;
			    }
			  else if ([internalType isEqualToString: @"NSNumber"])
			    {
#if 0
			      if (![anAttribute valueType]
				  || [@"cil" rangeOfString:
					 [anAttribute valueType]].length != 0)
				aValue = [NSNumber numberWithInt: [aStringValue
								    intValue]];
			      else if([@"fd" rangeOfString:
					  [anAttribute valueType]].length != 0)
				aValue = [NSNumber numberWithDouble:
						     [aStringValue
						       doubleValue]];
			      else
				[NSException raise:NSInvalidArgumentException format:@"Unknown valueType '%@' for attribute %@", [anAttribute valueType], anAttribute];
#else
			      aValue = [NSNumber numberWithDouble:
						   [aStringValue doubleValue]];
#endif
			    }
			  else if ([internalType isEqualToString:
						   @"NSDecimalNumber"])
			    {
			      aValue = [NSDecimalNumber decimalNumberWithString: aStringValue];
			      NSCAssert1(aValue != nil, @"Invalid decimal number representation: %@", aStringValue);
			    }
			  else if ([internalType isEqualToString:@"NSCalendarDate"])
			    {
			      // Format is Apple's eoutil format
			      aValue = [[NSCalendarDate alloc] initWithString: aStringValue calendarFormat: @"%b %d %Y %H:%M" /*locale:*/];
			      if(!aValue)
				// Format is ISO's
				aValue = [[NSCalendarDate alloc] initWithString: aStringValue calendarFormat: @"%Y-%m-%d %H:%M:%S %z" /*locale:*/];
			      if(!aValue)
				// Format is ISO's + milliseconds
				aValue = [[NSCalendarDate alloc] initWithString:aStringValue calendarFormat:@"%Y-%m-%d %H:%M:%S.%F %z" /*locale:*/];
			      NSCAssert1(aValue != nil, @"Unable to parse date from '%@'", aStringValue);
                  [aValue autorelease];
			    }
			  else if ([internalType isEqualToString: @"NSData"])
			    {
			      if ([aStringValue isEqualToString: @""])
				aValue = [NSData data];
			      else
				{
				  aValue = [aStringValue propertyList];
				  NSCAssert1([aValue isKindOfClass:
						       [NSData class]],
					     @"Invalid data: %@", aStringValue);
				}
			    }
			  else
			    [NSException raise:NSInvalidArgumentException format: @"Unknown attribute (%@) valueClassName: %@", anAttribute, internalType];
			}

		      [aRecord takeStoredValue: aValue forKey: anAttrName];
                    }

          NS_DURING
          {
              [anEC saveChanges];
          }
          NS_HANDLER
          {
              if(!force){
                  [anEC release];
                  [arp2 release];
                  [arp release];
                  [localException raise];
              }
              else{
                  NSLog(@"%@", localException);
                  [anEC revert];
              }
          }
          NS_ENDHANDLER;
          [arp2 release];
        }
          [arp release];
        }
          [anEC release];
      	}

        if(endingStatements)
            executeSQLStatements(srcModel, endingStatements, force);

        if (postInstallSQLExpressions)
        {
            EODatabaseContext	*databaseContext;
            EOEditingContext	*anEC = [[EOEditingContext alloc] init];

            databaseContext =
                [EODatabaseContext registeredDatabaseContextForModel: srcModel
                                                               editingContext: anEC];

            [databaseContext lock];

            NS_DURING
            {
                EODatabaseChannel *databaseChannel = [databaseContext
                    availableChannel];
                EOAdaptorChannel *adaptorChannel = [databaseChannel
                    adaptorChannel];
                NSString		*aString;
                NSEnumerator	*anEnum;

                if (![adaptorChannel isOpen])
                    [adaptorChannel openChannel];

                anEnum = [postInstallSQLExpressions objectEnumerator];

                while ((aString = [anEnum nextObject]))
                {
                    NS_DURING
                        EOSQLExpression	*aStatement = [exprClass expressionForString:aString];
                        
                        [adaptorChannel evaluateExpression: aStatement];
                    NS_HANDLER
                        if(!force)
                            break;
                        NS_ENDHANDLER;
                }

                    [databaseContext unlock];
                    [anEC release];
            }
                NS_HANDLER
                {
                    [databaseContext unlock];
                    [anEC release];
                    [localException raise];
                }
                NS_ENDHANDLER;
        }
    }
        
  return YES;
}

static BOOL
convert(NSArray *arguments)
{
  EOModel	*aModel;
  EOAdaptor	*newAdaptor;
  NSDictionary	*newConnectionDictionary;
  NSString	*newFilename;

  if ([arguments count] < 4)
    return NO;

  aModel = [[EOModel alloc] initWithContentsOfFile:
		      [[arguments objectAtIndex: 0]
			stringByStandardizingPath]];
  newAdaptor = [EOAdaptor adaptorWithName: [arguments objectAtIndex: 1]];
  newConnectionDictionary = [[arguments objectAtIndex: 2] propertyList];
  newFilename = [[arguments objectAtIndex: 3] stringByStandardizingPath];

  [aModel setAdaptorName: [newAdaptor name]];
  [aModel setConnectionDictionary: newConnectionDictionary];
  [[newAdaptor class] assignExternalInfoForEntireModel: aModel];
  [aModel writeToFile: newFilename];
  [aModel release];

  NSLog(@"Converted %@ to %@", [arguments objectAtIndex: 0], newFilename);
    
  return YES;
}

static BOOL
dbConnect(NSArray *arguments)
{
  EOAdaptor	*anAdaptor = nil;
  NSDictionary	*aConnectionDictionary = nil;
  EOModel	*aModel;

  switch ([arguments count])
    {
    case 1:
      aModel = [[EOModel alloc] initWithContentsOfFile:
			  [[arguments objectAtIndex: 0]
			    stringByStandardizingPath]];
      anAdaptor = [EOAdaptor adaptorWithModel: aModel];
      aConnectionDictionary = [aModel connectionDictionary];
      [aModel release];

    default:
      if (anAdaptor == nil)
	{
	  anAdaptor = [EOAdaptor adaptorWithName: [arguments objectAtIndex: 0]];
	  aConnectionDictionary = [[arguments objectAtIndex: 1] propertyList];
	  [anAdaptor setConnectionDictionary: aConnectionDictionary];
	}

      [anAdaptor assertConnectionDictionaryIsValid];            
    }
    
  return YES;
}

int
main(int arcg, char *argv[], char **envp)
{
  NSAutoreleasePool	*localAP = [[NSAutoreleasePool alloc] init];
  BOOL			 noUsage = NO;
  NSArray		*arguments = [[NSProcessInfo processInfo] arguments];
  int			 argc = [arguments count];
  BOOL			 hasError = NO;

  if (argc >= 2)
    {
      NSString *command = [arguments objectAtIndex: 1];

      if (argc > 2)
	arguments = [arguments subarrayWithRange: NSMakeRange(2, argc - 2)];
      else
	arguments = [NSArray array];

      NS_DURING
	{
	  if ([command isEqualToString: @"dump"])
	    noUsage = dump(arguments);
	  else if ([command isEqualToString: @"convert"])
	    noUsage = convert(arguments);
	  else if ([command isEqualToString: @"connect"])
	    noUsage = dbConnect(arguments);
	  else if ([command isEqualToString: @"help"])
	    noUsage = usage(YES);
	}
      NS_HANDLER
	{
	  noUsage = ![[localException name]
		       isEqualToString: NSInvalidArgumentException];
	  hasError = YES;
	  NSLog(@"%@", localException);
	}
      NS_ENDHANDLER;
    }

  if (!noUsage)
    (void)usage(NO);

  [localAP release];

  return hasError;
}
