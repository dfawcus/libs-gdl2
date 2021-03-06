/**
    ModelerAttributeEditor.m
 
    Author: Matt Rice <ratmice@gmail.com>
    Date: 2005, 2006

    This file is part of DBModeler.
    
    <license>
    DBModeler is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    DBModeler is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with DBModeler; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
    </license>
**/

#include "DefaultColumnProvider.h"
#include "ModelerAttributeEditor.h"
#include "ModelerEntityEditor.h"
#include "KVDataSource.h"

#ifdef NeXT_GUI_LIBRARY
#include <AppKit/AppKit.h>
#else
#include <AppKit/NSImage.h>
#include <AppKit/NSTableView.h>
#include <AppKit/NSTableColumn.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSPopUpButtonCell.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSSplitView.h>
#endif

#ifdef NeXT_Foundation_LIBRARY
#include <Foundation/Foundation.h>
#else
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>
#endif
  
#include <EOAccess/EOAttribute.h>
#include <EOAccess/EOEntity.h>
#include <EOAccess/EORelationship.h>

#include <EOControl/EOEditingContext.h>

#include <EOModeler/EOModelerDocument.h>
#include <EOModeler/EOModelerApp.h>

#include <EOInterface/EODisplayGroup.h>

#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/GSVersionMacros.h>

@interface NSArray (EOMAdditions)
- (id) firstSelectionOfClass:(Class) aClass;
@end
@implementation ModelerAttributeEditor

- (id) initWithParentEditor:(id)parentEditor
{
  NSScrollView *scrollView;
  KVDataSource *wds1, *wds2;
  NSPopUpButton *cornerView;
  NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:@"+" action:(SEL)nil keyEquivalent:@""];

  self = [super initWithParentEditor:parentEditor];
  
  [DefaultColumnProvider class]; 
  _mainView = [[NSSplitView alloc] initWithFrame:NSMakeRect(0,0,100,100)];
  /* setup the attributes table view */
  scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,100,100)];
  _attributes_tableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0,0,100,100)];
#if OS_API_VERSION(GS_API_NONE, MAC_OS_X_VERSION_10_4)
  [_attributes_tableView setAutoresizesAllColumnsToFit:NO];
#else
  [_attributes_tableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_3, GS_API_LATEST) || GNU_GUI_LIBRARY
  [_attributes_tableView setUsesAlternatingRowBackgroundColors:YES];
  [_attributes_tableView setGridStyleMask:NSTableViewSolidVerticalGridLineMask];
#endif
  [_attributes_tableView setAllowsMultipleSelection:YES];
  [_attributes_tableView setAllowsEmptySelection:YES];

  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setDocumentView:_attributes_tableView];
  RELEASE(_attributes_tableView);
  [_mainView addSubview:scrollView];
  RELEASE(scrollView);
  
  /* and the tableViews corner view */
  cornerView = [[NSPopUpButton alloc] initWithFrame:[[_attributes_tableView cornerView] bounds] pullsDown:YES];
  [[cornerView cell] setArrowPosition:NSPopUpNoArrow];
  [cornerView setTitle:@"+"];
  [cornerView setPreferredEdge:NSMinYEdge];
  [cornerView setBezelStyle:NSShadowlessSquareBezelStyle];

  [[cornerView cell] setUsesItemFromMenu:NO];
  [[cornerView cell] setShowsFirstResponder:NO];
  [[cornerView cell] setMenuItem:mi];
  
  [_attributes_tableView setCornerView:cornerView];
  RELEASE(cornerView);

  /* and the attributes tableview's display group */
  wds1 = [[KVDataSource alloc] initWithClassDescription:nil
                      editingContext:[[self document] editingContext]];
  [wds1 setKey:@"attributes"];
  _attributes_dg = [[EODisplayGroup alloc] init];
  [_attributes_dg setDataSource:wds1];
  RELEASE(wds1);
  [_attributes_dg setFetchesOnLoad:YES];
  [_attributes_dg setSelectsFirstObjectAfterFetch:NO];
  [_attributes_dg setDelegate:self];

  [self setupCornerView:cornerView
          tableView:_attributes_tableView
          displayGroup:_attributes_dg 
          forClass:[EOAttribute class]];
  [self addDefaultTableColumnsForTableView:_attributes_tableView 
                          displayGroup:_attributes_dg];
  
  /* setup the relationships table view */ 
  scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,100,100)];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setHasVerticalScroller:YES];
  _relationships_tableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0,0,100,100)];

#if OS_API_VERSION(GS_API_NONE, MAC_OS_X_VERSION_10_4)
  [_relationships_tableView setAutoresizesAllColumnsToFit:NO];
#else
  [_relationships_tableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_3, GS_API_LATEST) || GNU_GUI_LIBRARY
  [_relationships_tableView setUsesAlternatingRowBackgroundColors:YES];
  [_relationships_tableView setGridStyleMask:NSTableViewSolidVerticalGridLineMask];
#endif

  [_relationships_tableView setAllowsMultipleSelection:YES];
  [_relationships_tableView setAllowsEmptySelection:YES];
  [scrollView setDocumentView:_relationships_tableView];
  RELEASE(_relationships_tableView);
  [_mainView addSubview:scrollView];
  RELEASE(scrollView);
  
  /* and the tableViews corner view */
  cornerView = [[NSPopUpButton alloc] initWithFrame:[[_relationships_tableView cornerView] bounds] pullsDown:YES];
  [cornerView setPreferredEdge:NSMinYEdge];
  [[cornerView cell] setArrowPosition:NSPopUpNoArrow];
  [cornerView setTitle:@"+"];
  [cornerView setBezelStyle:NSShadowlessSquareBezelStyle];
  [[cornerView cell] setUsesItemFromMenu:NO];
  [[cornerView cell] setShowsFirstResponder:NO];
  [[cornerView cell] setMenuItem:mi];
  
  [_relationships_tableView setCornerView:cornerView];
  RELEASE(cornerView);
  /* and the relationships display group. */ 
  wds2 = [[KVDataSource alloc] initWithClassDescription:nil
                      editingContext:[[self document] editingContext]];
  [wds2 setKey:@"relationships"];
  _relationships_dg = [[EODisplayGroup alloc] init];
  [_relationships_dg setDataSource:wds2];
  RELEASE(wds2);
  [_relationships_dg setFetchesOnLoad:YES];
  [_relationships_dg setSelectsFirstObjectAfterFetch:NO];
  [_relationships_dg setDelegate:self];
  
  [self setupCornerView:cornerView
          tableView:_relationships_tableView
          displayGroup:_relationships_dg 
          forClass:[EORelationship class]];

  [self addDefaultTableColumnsForTableView:_relationships_tableView 
                          displayGroup:_relationships_dg];

  [[NSNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(selectionDidChange:)
	 name:EOMSelectionChangedNotification
	 object:[self document]];
  return self;
}

- (void) dealloc
{
  int i, c;

  if (_entityToObserve)
    [EOObserverCenter removeObserver:self forObject:_entityToObserve];

  c = [_oldSelection count];
  for (i = 0; i < c; i++)
    {
      [EOObserverCenter removeObserver:self 
			forObject:[_oldSelection objectAtIndex:i]];
    }

  RELEASE(_oldSelection);
  RELEASE(_mainView);
  RELEASE(_relationships_dg);
  RELEASE(_attributes_dg);
  [super dealloc];
}

- (NSView *)mainView
{
  return _mainView;
}

- (BOOL) canSupportCurrentSelection
{
  id selection = [self selectionWithinViewedObject];
  BOOL flag;

  if ([selection count] == 0)
    return NO;
  selection = [selection objectAtIndex:0];
  flag = ([selection isKindOfClass:[EOEntity class]]
          || [selection isKindOfClass:[EOAttribute class]]
          || [selection isKindOfClass:[EORelationship class]]);
  return flag;
}

- (void) needToFetch:(id)arg
{
  [_attributes_dg fetch];
  [_relationships_dg fetch];
}

- (void) activate
{
  NSArray *selPath = [self selectionPath];  
  NSArray *selWithin = [self selectionWithinViewedObject];
  id newEntityToObserve = [selPath firstSelectionOfClass:[EOEntity class]];
  if (_entityToObserve != newEntityToObserve)
    {
      if (_entityToObserve)
        [EOObserverCenter removeObserver:self forObject:_entityToObserve];

      _entityToObserve = newEntityToObserve;
      [EOObserverCenter addObserver:self forObject:_entityToObserve];
      [(KVDataSource *)[_attributes_dg dataSource] setDataObject: _entityToObserve];
      [(KVDataSource *)[_relationships_dg dataSource] setDataObject: _entityToObserve];
    }
  
  [self needToFetch:self];
  
  if (![[_attributes_dg selectedObjects] isEqual:selWithin]
      && ![_attributes_dg selectObjectsIdenticalTo:selWithin
                                  selectFirstOnNoMatch:NO])
    [_attributes_dg clearSelection];
  
  if (![[_relationships_dg selectedObjects] isEqual:selWithin]
      && ![_relationships_dg selectObjectsIdenticalTo:selWithin
                                  selectFirstOnNoMatch:NO])
    [_relationships_dg clearSelection];
}

- (NSArray *) friendEditorClasses
{
  return [NSArray arrayWithObjects: [ModelerEntityEditor class], nil];
}

- (void) selectionDidChange:(NSNotification *)notif
{
  NSArray *newSelection = [[EOMApp currentEditor] selectionWithinViewedObject];
  int i, c;

  c = [_oldSelection count];

  for (i = 0; i < c; i++)
    {
      id obj = [_oldSelection objectAtIndex:i];

      [EOObserverCenter removeObserver:self forObject:obj];
    }

  c = [newSelection count];
  for (i = 0; i < c; i++)
    {
      id obj = [newSelection objectAtIndex:i];

      [EOObserverCenter addObserver:self forObject:obj];
    }
  ASSIGN(_oldSelection, newSelection);
}

- (void) objectWillChange:(id)sender
{
  [[NSRunLoop currentRunLoop]
          performSelector:@selector(needToFetch:) 
                   target:self
                 argument:nil
                    order:999 /* this number is probably arbitrary */
                    modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

- (NSArray *)defaultColumnNamesForClass:(Class)aClass
{
  NSArray *colNames = [super defaultColumnNamesForClass:aClass];
  if (colNames == nil || [colNames count] == 0)
    {
      if (aClass == [EOAttribute class])
        return DefaultAttributeColumns; 
      else if (aClass == [EORelationship class])
        return DefaultRelationshipColumns;
      else
        return nil;
    }
    
  return colNames;
}

- (void) displayGroupDidChangeSelection:(EODisplayGroup *)displayGroup
{
  NSArray *selObj = [displayGroup selectedObjects];
  NSArray *selWithin = RETAIN([self selectionWithinViewedObject]);

  if ([selObj count] && (![selObj isEqual:selWithin]))
    {
      if ([selWithin containsObject:_entityToObserve])
        {
          NSAssert([selWithin count] == 1, @"how on earth?");
	  /* we need to turn 
	     (model, (entity)) into
	     (model, entity, ()) 
	   */
          [[self parentEditor] viewSelectedObject];
	}
      /* now select the attribute/relationship */
      [self setSelectionWithinViewedObject: selObj];
      [self activate];
    }

  RELEASE(selWithin);
}

@end

