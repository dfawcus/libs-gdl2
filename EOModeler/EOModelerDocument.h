#ifndef __EOModelerDocument_H__
#define __EOModelerDocument_H__

/* -*-objc-*-
   EOModelerDocument.h

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author: Matt Rice <ratmice@gmail.com>
   Date: Apr 2005

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#ifdef NeXT_Foundation_LIBRARY
#include <Foundation/Foundation.h>
#else
#include <Foundation/NSObject.h>
#endif

#include <EOModeler/EODefines.h>

@class EOModel;
@class NSMutableArray;
@class NSDictionary;
@class EOEditingContext;
@class EOModelerEditor;
@class EOAdaptor;
@class NSAttributedString;
@class NSString;

GDL2MODELER_EXPORT NSString *EOMCheckConsistencyBeginNotification;
GDL2MODELER_EXPORT NSString *EOMCheckConsistencyEndNotification;
GDL2MODELER_EXPORT NSString *EOMCheckConsistencyForModelNotification;

GDL2MODELER_EXPORT NSString *EOMConsistencyModelObjectKey;


@interface EOModelerDocument : NSObject
{
  EOModel *_model;
  NSMutableArray *_editors;
  NSDictionary *_userInfo;
  EOEditingContext *_editingContext;
}

+ (void) setDefaultEditorClass: (Class)defaultEditorClass;
- (id) initWithModel:(EOModel *)model;
- (void) saveAs:(id)sender;
- (NSString *)documentPath;
- (EOModel *)model;
- (EOAdaptor *)adaptor;
- (EOModelerEditor *) addDefaultEditor;
- (void) activate;
- (void) appendConsistencyCheckErrorText:(NSAttributedString *)errorText;
- (void) appendConsistencyCheckSuccessText:(NSAttributedString *)successText;
/* actions */
- (void) addEntity:(id)sender;
- (void) addRelationship:(id)sender;
- (void) addAttribute:(id)sender;
- (void) delete:(id)sender;
@end

#endif // __EOModelerDocument_H__
