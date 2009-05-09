///////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/cocoa/dataview.mm
// Purpose:     wxDataView
// Author:      
// Modified by:
// Created:     2009-01-31
// RCS-ID:      $Id: dataview.mm$
// Copyright:   
// Licence:     wxWindows licence
///////////////////////////////////////////////////////////////////////////////

#include "wx/wxprec.h"

#if (wxUSE_DATAVIEWCTRL == 1) && !defined(wxUSE_GENERICDATAVIEWCTRL)

#ifndef WX_PRECOMP
    #include "wx/app.h"
    #include "wx/toplevel.h"
    #include "wx/font.h"
    #include "wx/settings.h"
    #include "wx/utils.h"
#endif

#include "wx/osx/cocoa/dataview.h"
#include "wx/osx/private.h"
#include "wx/renderer.h"


// ============================================================================
// Constants used locally
// ============================================================================
#define DataViewPboardType @"OutlineViewItem"

// ============================================================================
// Classes used locally in dataview.mm
// ============================================================================
@interface wxCustomRendererObject : NSObject <NSCopying>
{
@public
  NSTableColumn* tableColumn; // not owned by the class

  wxDataViewCustomRenderer* customRenderer; // not owned by the class
  
  wxPointerObject* item; // not owned by the class
}

 //
 // initialization
 //
  -(id) init;
  -(id) initWithRenderer:(wxDataViewCustomRenderer*)initRenderer item:(wxPointerObject*)initItem column:(NSTableColumn*)initTableColumn;

@end

@implementation wxCustomRendererObject
//
// initialization
//
-(id) init
{
  self = [super init];
  if (self != nil)
  {
    customRenderer = NULL;
    item           = NULL;
    tableColumn    = NULL;
  }
  return self;
}

-(id) initWithRenderer:(wxDataViewCustomRenderer*)initRenderer item:(wxPointerObject*)initItem column:(NSTableColumn*)initTableColumn
{
  self = [super init];
  if (self != nil)
  {
    customRenderer = initRenderer;
    item           = initItem;
    tableColumn    = initTableColumn;
  }
  return self;
}

-(id) copyWithZone:(NSZone*)zone
{
  wxCustomRendererObject* copy;
  
  
  copy = [[[self class] allocWithZone:zone] init];
  copy->customRenderer = customRenderer;
  copy->item           = item;
  copy->tableColumn    = tableColumn;

  return copy;
}

@end

// ============================================================================
// Functions used locally in dataview.mm
// ============================================================================
static NSInteger CompareItems(id item1, id item2, void* context)
{
  NSArray* const sortDescriptors = (NSArray*) context;
  
  NSUInteger const noOfDescriptors = [sortDescriptors count];

  NSInteger result(NSOrderedAscending);


  for (NSUInteger i=0; i<noOfDescriptors; ++i)
  {
   // constant definition for abbreviational purposes:
    wxSortDescriptorObject* const sortDescriptor = (wxSortDescriptorObject*)[sortDescriptors objectAtIndex:i];

    int wxComparisonResult;
    
    wxComparisonResult = [sortDescriptor modelPtr]->Compare(wxDataViewItem([((wxPointerObject*) item1) pointer]),
                                                            wxDataViewItem([((wxPointerObject*) item2) pointer]),
                                                            [sortDescriptor columnPtr]->GetModelColumn(),
                                                            [sortDescriptor ascending] == YES);
    if (wxComparisonResult < 0)
    {
      result = NSOrderedAscending;
      break;
    }
    else if (wxComparisonResult > 0)
    {
      result = NSOrderedDescending;
      break;
    }
    else
      result = NSOrderedSame;
  }
  return result;
}

static NSTextAlignment ConvertToNativeHorizontalTextAlignment(int alignment)
{
  if (alignment & wxALIGN_CENTER_HORIZONTAL) // center alignment is chosen also if alignment is equal to -1
    return NSCenterTextAlignment;
  else if (alignment & wxALIGN_RIGHT)
    return NSRightTextAlignment;
  else
    return NSLeftTextAlignment;
}

static NSTableColumn* CreateNativeColumn(wxDataViewColumn const* columnPtr)
{
  NSTableColumn* nativeColumn([[NSTableColumn alloc] initWithIdentifier:[[[wxPointerObject alloc] initWithPointer:const_cast<wxDataViewColumn*>(columnPtr)] autorelease]]);


 // initialize the native column:
  if ((nativeColumn != NULL) && (columnPtr->GetRenderer() != NULL))
  {
   // setting the size related parameters:
    if (columnPtr->IsResizeable())
    {
      [nativeColumn setResizingMask:NSTableColumnUserResizingMask];
      [nativeColumn setMinWidth:columnPtr->GetMinWidth()];
      [nativeColumn setMaxWidth:columnPtr->GetMaxWidth()];
    }
    else
    {
      [nativeColumn setResizingMask:NSTableColumnNoResizing];
      [nativeColumn setMinWidth:columnPtr->GetWidth()];
      [nativeColumn setMaxWidth:columnPtr->GetWidth()];
    }
    [nativeColumn setWidth:columnPtr->GetWidth()];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
   // setting the visibility:
    [nativeColumn setHidden:static_cast<BOOL>(columnPtr->IsHidden())];
#endif
   // setting the header:
    [[nativeColumn headerCell] setAlignment:ConvertToNativeHorizontalTextAlignment(columnPtr->GetAlignment())];
    [[nativeColumn headerCell] setStringValue:[[wxCFStringRef(columnPtr->GetTitle()).AsNSString() retain] autorelease]];
   // setting data cell's properties:
    [[nativeColumn dataCell] setWraps:NO];
   // setting the default data cell:
    [nativeColumn setDataCell:columnPtr->GetRenderer()->GetNativeData()->GetColumnCell()];
   // setting the editablility:
    bool const dataCellIsEditable = (columnPtr->GetRenderer()->GetMode() == wxDATAVIEW_CELL_EDITABLE);

     [nativeColumn           setEditable:dataCellIsEditable];
    [[nativeColumn dataCell] setEditable:dataCellIsEditable];
  }
 // done:
  return nativeColumn;
}

// ============================================================================
// Public helper functions for dataview implementation on OSX
// ============================================================================
wxWidgetImplType* CreateDataView(wxWindowMac* wxpeer, wxWindowMac* WXUNUSED(parent),  wxWindowID WXUNUSED(id), wxPoint const& pos, wxSize const& size,
                                 long style, long WXUNUSED(extraStyle))
{
  return new wxCocoaDataViewControl(wxpeer,pos,size,style);
}

// ============================================================================
// wxPointerObject
// ============================================================================
//
// This is a helper class to store a pointer in an object.
//
@implementation wxPointerObject
//
// object initialization
//
-(id) init
{
  self = [super init];
  if (self != nil)
    self.pointer = NULL;
  return self;
}

-(id) initWithPointer:(void*) initPointer
{
  self = [super init];
  if (self != nil)
    self.pointer = initPointer;
  return self;
}

//
// inherited methods from NSObject
//
-(BOOL) isEqual:(id)object
{
  return (object != nil) && ([object isKindOfClass:[wxPointerObject class]]) && (pointer == [((wxPointerObject*) object) pointer]);
}

-(NSUInteger) hash
{
  return (NSUInteger) pointer;
}

//
// access to pointer
//
-(void*) pointer
{
  return pointer;
}

-(void) setPointer:(void*) newPointer
{
  pointer = newPointer;
}

@end

// ============================================================================
// wxSortDescriptorObject
// ============================================================================
@implementation wxSortDescriptorObject
//
// initialization
//
-(id) init
{
  self = [super init];
  if (self != nil)
  {
    columnPtr = NULL;
    modelPtr  = NULL;
  }
  return self;
}

-(id) initWithModelPtr:(wxDataViewModel*)initModelPtr sortingColumnPtr:(wxDataViewColumn*)initColumnPtr ascending:(BOOL)sortAscending
{
  self = [super initWithKey:@"dummy" ascending:sortAscending];
  if (self != nil)
  {
    columnPtr = initColumnPtr;
    modelPtr  = initModelPtr;
  }
  return self;
}

-(id) copyWithZone:(NSZone*)zone
{
  wxSortDescriptorObject* copy;
  
  
  copy = [super copyWithZone:zone];
  copy->columnPtr = columnPtr;
  copy->modelPtr  = modelPtr;

  return copy;
}

//
// access to model column's index
//
-(wxDataViewColumn*) columnPtr
{
  return columnPtr;
}

-(wxDataViewModel*) modelPtr
{
  return modelPtr;
}

-(void) setColumnPtr:(wxDataViewColumn*)newColumnPtr
{
  columnPtr = newColumnPtr;
}

-(void) setModelPtr:(wxDataViewModel*)newModelPtr
{
  modelPtr = newModelPtr;
}

@end

// ============================================================================
// wxCocoaOutlineDataSource
// ============================================================================
@implementation wxCocoaOutlineDataSource

//
// constructors / destructor
//
-(id) init
{
  self = [super init];
  if (self != nil)
  {
    implementation = NULL;
    model          = NULL;

    currentParentItem = nil;

    children = [[NSMutableArray alloc] init];
    items    = [[NSMutableSet   alloc] init];
  }
  return self;
}

-(void) dealloc
{
  [currentParentItem release];

  [children release];
  [items    release];
  
  [super dealloc];
}

//
// methods of informal protocol:
//
-(BOOL) outlineView:(NSOutlineView*)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
  bool dragSuccessful;

  NSArray* supportedTypes([NSArray arrayWithObjects:DataViewPboardType,NSStringPboardType,nil]);

  NSPasteboard* pasteboard([info draggingPasteboard]);

  NSString* bestType([pasteboard availableTypeFromArray:supportedTypes]);

  
  if (bestType != nil)
  {
    wxDataViewCtrl* const  dataViewCtrlPtr(implementation->GetDataViewCtrl());

    wxCHECK_MSG(dataViewCtrlPtr != NULL,            false,_("Pointer to data view control not set correctly."));
    wxCHECK_MSG(dataViewCtrlPtr->GetModel() != NULL,false,_("Pointer to model not set correctly."));
  // create wxWidget's event:
    wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_DROP,dataViewCtrlPtr->GetId());

    dataViewEvent.SetEventObject(dataViewCtrlPtr);
    dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) item) pointer]));
    dataViewEvent.SetModel(dataViewCtrlPtr->GetModel());
    if ([bestType compare:DataViewPboardType] == NSOrderedSame)
    {
      NSArray*   dataArray((NSArray*)[pasteboard propertyListForType:DataViewPboardType]);
      NSUInteger indexDraggedItem, noOfDraggedItems([dataArray count]);
      
      indexDraggedItem = 0;
      while (indexDraggedItem < noOfDraggedItems)
      {
        wxDataObjectComposite* dataObjects(implementation->GetDnDDataObjects((NSData*)[dataArray objectAtIndex:indexDraggedItem]));

        if ((dataObjects != NULL) && (dataObjects->GetFormatCount() > 0))
        {
          wxMemoryBuffer buffer;

         // copy data into data object:
          dataViewEvent.SetDataObject(dataObjects);
          dataViewEvent.SetDataFormat(implementation->GetDnDDataFormat(dataObjects));
         // copy data into buffer:
          dataObjects->GetDataHere(dataViewEvent.GetDataFormat().GetType(),buffer.GetWriteBuf(dataViewEvent.GetDataSize()));
          buffer.UngetWriteBuf(dataViewEvent.GetDataSize());
          dataViewEvent.SetDataBuffer(buffer.GetData());
         // finally, send event:
          if (dataViewCtrlPtr->HandleWindowEvent(dataViewEvent) && dataViewEvent.IsAllowed())
          {
            dragSuccessful = true;
            ++indexDraggedItem;
          }
          else
          {
            dragSuccessful   = true;
            indexDraggedItem = noOfDraggedItems; // stop loop
          }
        }
        else
        {
          dragSuccessful   = false;
          indexDraggedItem = noOfDraggedItems; // stop loop
        }
       // clean-up:
        delete dataObjects;
      }
    }
    else
    {
      CFDataRef              osxData; // needed to convert internally used UTF-16 representation to a UTF-8 representation
      wxDataObjectComposite* dataObjects   (new wxDataObjectComposite());
      wxTextDataObject*      textDataObject(new wxTextDataObject());
      
      osxData = ::CFStringCreateExternalRepresentation(kCFAllocatorDefault,(CFStringRef)[pasteboard stringForType:NSStringPboardType],kCFStringEncodingUTF8,32);
      if (textDataObject->SetData(::CFDataGetLength(osxData),::CFDataGetBytePtr(osxData)))
        dataObjects->Add(textDataObject);
      else
        delete textDataObject;
     // send event if data could be copied:
      if (dataObjects->GetFormatCount() > 0)
      {
        dataViewEvent.SetDataObject(dataObjects);
        dataViewEvent.SetDataFormat(implementation->GetDnDDataFormat(dataObjects));
        if (dataViewCtrlPtr->HandleWindowEvent(dataViewEvent) && dataViewEvent.IsAllowed())
          dragSuccessful = true;
        else
          dragSuccessful = false;
      }
      else
        dragSuccessful = false;
     // clean up:
      ::CFRelease(osxData);
      delete dataObjects;
    }
  }
  else
    dragSuccessful = false;
  return dragSuccessful;
}

-(id) outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
  if ((item == currentParentItem) && (index < ((NSInteger) [self getChildCount])))
    return [self getChild:index];
  else
  {
    wxDataViewItemArray dataViewChildren;

    wxCHECK_MSG(model != NULL,0,_("Valid model in data source does not exist."));
    (void) model->GetChildren((item == nil) ? wxDataViewItem() : wxDataViewItem([((wxPointerObject*) item) pointer]),dataViewChildren);
    [self bufferItem:item withChildren:&dataViewChildren];
    if ([sortDescriptors count] > 0)
      [children sortUsingFunction:CompareItems context:sortDescriptors];
    return [self getChild:index];
  }
}

-(BOOL) outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
  wxCHECK_MSG(model != NULL,0,_("Valid model in data source does not exist."));
  return model->IsContainer(wxDataViewItem([((wxPointerObject*) item) pointer]));
}

-(NSInteger) outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
  NSInteger noOfChildren;

  wxDataViewItemArray dataViewChildren;


  wxCHECK_MSG(model != NULL,0,_("Valid model in data source does not exist."));
  noOfChildren = model->GetChildren((item == nil) ? wxDataViewItem() : wxDataViewItem([((wxPointerObject*) item) pointer]),dataViewChildren);
  [self bufferItem:item withChildren:&dataViewChildren];
  if ([sortDescriptors count] > 0)
    [children sortUsingFunction:CompareItems context:sortDescriptors];
  return noOfChildren;
}

-(id) outlineView:(NSOutlineView*)outlineView objectValueForTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
  wxDataViewColumn* dataViewColumnPtr(reinterpret_cast<wxDataViewColumn*>([[tableColumn identifier] pointer]));

  wxDataViewItem dataViewItem([((wxPointerObject*) item) pointer]);

  wxVariant value;


  wxCHECK_MSG(model != NULL,0,_("Valid model in data source does not exist."));
  model->GetValue(value,dataViewItem,dataViewColumnPtr->GetModelColumn());
  dataViewColumnPtr->GetRenderer()->SetValue(value);
  return nil;
}

-(void) outlineView:(NSOutlineView*)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
  wxDataViewColumn* dataViewColumnPtr(reinterpret_cast<wxDataViewColumn*>([[tableColumn identifier] pointer]));

  wxDataViewItem dataViewItem([((wxPointerObject*) item) pointer]);


  if (((dynamic_cast<wxDataViewTextRenderer*>(dataViewColumnPtr->GetRenderer()) != NULL) || (dynamic_cast<wxDataViewIconTextRenderer*>(dataViewColumnPtr->GetRenderer()) != NULL)) &&
      ([object isKindOfClass:[NSString class]] == YES))
  {
    model->SetValue(wxVariant(wxCFStringRef([((NSString*) object) retain]).AsString()),dataViewItem,dataViewColumnPtr->GetModelColumn()); // the string has to be retained before being passed to wxCFStringRef
    model->ValueChanged(dataViewItem,dataViewColumnPtr->GetModelColumn());
  }
  else if (dynamic_cast<wxDataViewChoiceRenderer*>(dataViewColumnPtr->GetRenderer()) != NULL)
  {
    if ([object isKindOfClass:[NSNumber class]] == YES)
    {
      model->SetValue(wxVariant(dynamic_cast<wxDataViewChoiceRenderer*>(dataViewColumnPtr->GetRenderer())->GetChoice([((NSNumber*) object) intValue])),
                      dataViewItem,dataViewColumnPtr->GetModelColumn());
      model->ValueChanged(dataViewItem,dataViewColumnPtr->GetModelColumn());
    }
    else if ([object isKindOfClass:[NSString class]] == YES) // do not know if this case can occur but initializing using strings works
    {
      model->SetValue(wxVariant(wxCFStringRef((NSString*) object).AsString()),dataViewItem,dataViewColumnPtr->GetModelColumn());
      model->ValueChanged(dataViewItem,dataViewColumnPtr->GetModelColumn());
    }
  }
  else if ((dynamic_cast<wxDataViewDateRenderer*>(dataViewColumnPtr->GetRenderer()) != NULL) && ([object isKindOfClass:[NSDate class]] == YES))
  {
    wxDateTime wxDateTimeValue(1,wxDateTime::Jan,1970);

    wxLongLong seconds;

    seconds.Assign([((NSDate*) object) timeIntervalSince1970]); // get the number of seconds since 1970-01-01 UTC and this is
                                                                // the only way to convert a double to a wxLongLong
   // the user has entered a date in the local timezone but seconds contains the number of seconds from date in the local timezone since 1970-01-01 UTC;
   // therefore, the timezone information has to be transferred to wxWidgets, too:
    wxDateTimeValue.Add(wxTimeSpan(0,0,seconds));
    wxDateTimeValue.MakeFromTimezone(wxDateTime::UTC);
    model->SetValue(wxVariant(wxDateTimeValue),dataViewItem,dataViewColumnPtr->GetModelColumn());
    model->ValueChanged(dataViewItem,dataViewColumnPtr->GetModelColumn());
  }
  else if ((dynamic_cast<wxDataViewToggleRenderer*>(dataViewColumnPtr->GetRenderer()) != NULL) && ([object isKindOfClass:[NSNumber class]] == YES))
  {
    model->SetValue(wxVariant((bool) [((NSNumber*) object) boolValue]),dataViewItem,dataViewColumnPtr->GetModelColumn());
    model->ValueChanged(dataViewItem,dataViewColumnPtr->GetModelColumn());
  }
}

-(void) outlineView:(NSOutlineView*)outlineView sortDescriptorsDidChange:(NSArray*)oldDescriptors
 // Warning: the new sort descriptors are guaranteed to be only of type NSSortDescriptor! Therefore, the
 // sort descriptors for the data source have to be converted.
{
  NSArray* newDescriptors;

  NSMutableArray* wxSortDescriptors;
  
  NSUInteger noOfDescriptors;

  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();


 // convert NSSortDescriptors to wxSortDescriptorObjects:
  newDescriptors    = [outlineView sortDescriptors];
  noOfDescriptors   = [newDescriptors count];
  wxSortDescriptors = [NSMutableArray arrayWithCapacity:noOfDescriptors];
  for (NSUInteger i=0; i<noOfDescriptors; ++i)
  {
   // constant definition for abbreviational purposes:
    NSSortDescriptor* const newDescriptor = [newDescriptors objectAtIndex:i];

    [wxSortDescriptors addObject:[[[wxSortDescriptorObject alloc] initWithModelPtr:model
                                                                  sortingColumnPtr:dataViewCtrlPtr->GetColumn([[newDescriptor key] intValue])
                                                                         ascending:[newDescriptor ascending]] autorelease]];
  }
  [[outlineView dataSource] setSortDescriptors:wxSortDescriptors];

 // send first the event to wxWidgets that the sorting has changed so that the program can do special actions before
 // the sorting actually starts:
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_COLUMN_SORTED,dataViewCtrlPtr->GetId()); // variable defintion

  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  if (noOfDescriptors > 0)
  {
   // constant definition for abbreviational purposes:
    wxDataViewColumn* const dataViewColumnPtr = [[wxSortDescriptors objectAtIndex:0] columnPtr];

    dataViewEvent.SetColumn(dataViewCtrlPtr->GetColumnPosition(dataViewColumnPtr));
    dataViewEvent.SetDataViewColumn(dataViewColumnPtr);
  }
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);

 // start re-ordering the data;
 // children's buffer must be cleared first because it contains the old order:
  [self clearChildren];
 // sorting is done while reloading the data:
  [outlineView reloadData];
}

-(NSDragOperation) outlineView:(NSOutlineView*)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
  NSArray* supportedTypes([NSArray arrayWithObjects:DataViewPboardType,NSStringPboardType,nil]);

  NSDragOperation dragOperation;

  NSPasteboard* pasteboard([info draggingPasteboard]);

  NSString* bestType([pasteboard availableTypeFromArray:supportedTypes]);

  
  if (bestType != nil)
  {
    wxDataViewCtrl* const  dataViewCtrlPtr(implementation->GetDataViewCtrl());

    wxCHECK_MSG(dataViewCtrlPtr != NULL,            false,_("Pointer to data view control not set correctly."));
    wxCHECK_MSG(dataViewCtrlPtr->GetModel() != NULL,false,_("Pointer to model not set correctly."));
  // create wxWidget's event:
    wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_DROP_POSSIBLE,dataViewCtrlPtr->GetId());

    dataViewEvent.SetEventObject(dataViewCtrlPtr);
    dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) item) pointer]));
    dataViewEvent.SetModel(dataViewCtrlPtr->GetModel());
    if ([bestType compare:DataViewPboardType] == NSOrderedSame)
    {
      NSArray*               dataArray((NSArray*)[pasteboard propertyListForType:DataViewPboardType]);
      NSUInteger             indexDraggedItem, noOfDraggedItems([dataArray count]);
      
      indexDraggedItem = 0;
      while (indexDraggedItem < noOfDraggedItems)
      {
        wxDataObjectComposite* dataObjects(implementation->GetDnDDataObjects((NSData*)[dataArray objectAtIndex:indexDraggedItem]));

        if ((dataObjects != NULL) && (dataObjects->GetFormatCount() > 0))
        {
          wxMemoryBuffer buffer;

         // copy data into data object:
          dataViewEvent.SetDataObject(dataObjects);
          dataViewEvent.SetDataFormat(implementation->GetDnDDataFormat(dataObjects));
         // copy data into buffer:
          dataObjects->GetDataHere(dataViewEvent.GetDataFormat().GetType(),buffer.GetWriteBuf(dataViewEvent.GetDataSize()));
          buffer.UngetWriteBuf(dataViewEvent.GetDataSize());
          dataViewEvent.SetDataBuffer(buffer.GetData());
         // finally, send event:
          if (dataViewCtrlPtr->HandleWindowEvent(dataViewEvent) && dataViewEvent.IsAllowed())
          {
            dragOperation = NSDragOperationEvery;
            ++indexDraggedItem;
          }
          else
          {
            dragOperation    = NSDragOperationNone;
            indexDraggedItem = noOfDraggedItems; // stop loop
          }
        }
        else
        {
          dragOperation    = NSDragOperationNone;
          indexDraggedItem = noOfDraggedItems; // stop loop
        }
       // clean-up:
        delete dataObjects;
      }
    }
    else
    {
      CFDataRef              osxData; // needed to convert internally used UTF-16 representation to a UTF-8 representation
      wxDataObjectComposite* dataObjects   (new wxDataObjectComposite());
      wxTextDataObject*      textDataObject(new wxTextDataObject());
      
      osxData = ::CFStringCreateExternalRepresentation(kCFAllocatorDefault,(CFStringRef)[pasteboard stringForType:NSStringPboardType],kCFStringEncodingUTF8,32);
      if (textDataObject->SetData(::CFDataGetLength(osxData),::CFDataGetBytePtr(osxData)))
        dataObjects->Add(textDataObject);
      else
        delete textDataObject;
     // send event if data could be copied:
      if (dataObjects->GetFormatCount() > 0)
      {
        dataViewEvent.SetDataObject(dataObjects);
        dataViewEvent.SetDataFormat(implementation->GetDnDDataFormat(dataObjects));
        if (dataViewCtrlPtr->HandleWindowEvent(dataViewEvent) && dataViewEvent.IsAllowed())
          dragOperation = NSDragOperationEvery;
        else
          dragOperation = NSDragOperationNone;
      }
      else
        dragOperation = NSDragOperationNone;
     // clean up:
      ::CFRelease(osxData);
      delete dataObjects;
    }
  }
  else
    dragOperation = NSDragOperationNone;
  return dragOperation;
}

-(BOOL) outlineView:(NSOutlineView*)outlineView writeItems:(NSArray*)writeItems toPasteboard:(NSPasteboard*)pasteboard
 // the pasteboard will be filled up with an array containing the data as returned by the events (including the data type)
 // and a concatenation of text (string) data; the text data will only be put onto the pasteboard if for all items a
 // string representation exists
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
  
  wxDataViewItemArray dataViewItems;


  wxCHECK_MSG(dataViewCtrlPtr != NULL,            false,_("Pointer to data view control not set correctly."));
  wxCHECK_MSG(dataViewCtrlPtr->GetModel() != NULL,false,_("Pointer to model not set correctly."));

  if ([writeItems count] > 0)
  {
    bool            dataStringAvailable(true); // a flag indicating if for all items a data string is available
    NSMutableArray* dataArray = [[NSMutableArray arrayWithCapacity:[writeItems count]] retain]; // data of all items
    wxString        dataString; // contains the string data of all items

   // send a begin drag event for all selected items and proceed with dragging unless the event is vetoed:
    wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_BEGIN_DRAG,dataViewCtrlPtr->GetId());

    dataViewEvent.SetEventObject(dataViewCtrlPtr);
    dataViewEvent.SetModel(dataViewCtrlPtr->GetModel());
    for (size_t itemCounter=0; itemCounter<[writeItems count]; ++itemCounter)
    {
      bool                   itemStringAvailable(false);              // a flag indicating if for the current item a string is available
      wxDataObjectComposite* itemObject(new wxDataObjectComposite()); // data object for current item
      wxString               itemString;                              // contains the TAB concatenated data of an item

      dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) [writeItems objectAtIndex:itemCounter]) pointer]));
      itemString = ::ConcatenateDataViewItemValues(dataViewCtrlPtr,dataViewEvent.GetItem());
      itemObject->Add(new wxTextDataObject(itemString));
      dataViewEvent.SetDataObject(itemObject);
     // check if event has not been vetoed:
      if (dataViewCtrlPtr->HandleWindowEvent(dataViewEvent) && dataViewEvent.IsAllowed() && (dataViewEvent.GetDataObject()->GetFormatCount() > 0))
      {
       // constant definition for abbreviational purposes:
        size_t const noOfFormats = dataViewEvent.GetDataObject()->GetFormatCount();
       // variable definition and initialization:
        wxDataFormat* dataFormats(new wxDataFormat[noOfFormats]);

        dataViewEvent.GetDataObject()->GetAllFormats(dataFormats,wxDataObject::Get);
        for (size_t formatCounter=0; formatCounter<noOfFormats; ++formatCounter)
        {
         // constant definitions for abbreviational purposes:
          wxDataFormatId const idDataFormat = dataFormats[formatCounter].GetType();
          size_t const dataSize       = dataViewEvent.GetDataObject()->GetDataSize(idDataFormat);
          size_t const dataBufferSize = sizeof(wxDataFormatId)+dataSize;
         // variable definitions (used in all case statements):
          wxMemoryBuffer dataBuffer(dataBufferSize);
          
          dataBuffer.AppendData(&idDataFormat,sizeof(wxDataFormatId));
          switch (idDataFormat)
          {
            case wxDF_TEXT:
              if (!itemStringAvailable) // otherwise wxDF_UNICODETEXT already filled up the string; and the UNICODE representation has priority
              {
                dataViewEvent.GetDataObject()->GetDataHere(wxDF_TEXT,dataBuffer.GetAppendBuf(dataSize));
                dataBuffer.UngetAppendBuf(dataSize);
                [dataArray addObject:[NSData dataWithBytes:dataBuffer.GetData() length:dataBufferSize]];
                itemString = wxString(reinterpret_cast<char const*>(dataBuffer.GetData())+sizeof(wxDataFormatId),wxConvLocal);
                itemStringAvailable = true;
              }
              break;
            case wxDF_UNICODETEXT:
              {
                dataViewEvent.GetDataObject()->GetDataHere(wxDF_UNICODETEXT,dataBuffer.GetAppendBuf(dataSize));
                dataBuffer.UngetAppendBuf(dataSize);
                if (itemStringAvailable) // does an object already exist as an ASCII text (see wxDF_TEXT case statement)?
                  [dataArray replaceObjectAtIndex:itemCounter withObject:[NSData dataWithBytes:dataBuffer.GetData() length:dataBufferSize]];
                else
                  [dataArray addObject:[NSData dataWithBytes:dataBuffer.GetData() length:dataBufferSize]];
                itemString = wxString::FromUTF8(reinterpret_cast<char const*>(dataBuffer.GetData())+sizeof(wxDataFormatId),dataSize);
                itemStringAvailable = true;
              } /* block */
              break;
            default:
              wxFAIL_MSG(_("Data object has invalid or unsupported data format"));
              [dataArray release];
              return NO;
          }
        }
        delete[] dataFormats;
        delete itemObject;
        if (dataStringAvailable)
          if (itemStringAvailable)
          {
            if (itemCounter > 0)
              dataString << wxT('\n');
            dataString << itemString;
          }
          else
            dataStringAvailable = false;
      }
      else
      {
        [dataArray release];
        delete itemObject;
        return NO; // dragging was vetoed or no data available
      }
    }
    if (dataStringAvailable)
    {
      wxCFStringRef osxString(dataString);
      
      [pasteboard declareTypes:[NSArray arrayWithObjects:DataViewPboardType,NSStringPboardType,nil] owner:nil];
      [pasteboard setPropertyList:dataArray forType:DataViewPboardType];
      [pasteboard setString:osxString.AsNSString() forType:NSStringPboardType];
    }
    else
    {
      [pasteboard declareTypes:[NSArray arrayWithObject:DataViewPboardType] owner:nil];
      [pasteboard setPropertyList:dataArray forType:DataViewPboardType];
    }
    return YES;
  }
  else
    return NO; // no items to drag (should never occur)
}

//
// buffer handling
//
-(void) addToBuffer:(wxPointerObject*)item
{
  [items addObject:item];
}

-(void) clearBuffer
{
  [items removeAllObjects];
}

-(wxPointerObject*) getDataViewItemFromBuffer:(wxDataViewItem const&)item
{
  return [items member:[[[wxPointerObject alloc] initWithPointer:item.GetID()] autorelease]];
}

-(wxPointerObject*) getItemFromBuffer:(wxPointerObject*)item
{
  return [items member:item];
}

-(BOOL) isInBuffer:(wxPointerObject*)item
{
  return [items containsObject:item];
}

-(void) removeFromBuffer:(wxPointerObject*)item
{
  [items removeObject:item];
}

//
// children handling
//
-(void) appendChild:(wxPointerObject*)item
{
  [children addObject:item];
}

-(void) clearChildren
{
  [children removeAllObjects];
}

-(wxPointerObject*) getChild:(NSUInteger)index
{
  return [children objectAtIndex:index];
}

-(NSUInteger) getChildCount
{
  return [children count];
}

-(void) removeChild:(NSUInteger)index
{
  [children removeObjectAtIndex:index];
}

//
// buffer handling
//
-(void) clearBuffers
{
  [self clearBuffer];
  [self clearChildren];
  [self setCurrentParentItem:nil];
}

//
// sorting
//
-(NSArray*) sortDescriptors
{
  return sortDescriptors;
}

-(void) setSortDescriptors:(NSArray*)newSortDescriptors
{
  [newSortDescriptors retain];
  [sortDescriptors release];
  sortDescriptors = newSortDescriptors;
}

//
// access to wxWidget's implementation
//
-(wxPointerObject*) currentParentItem
{
  return currentParentItem;
}

-(wxCocoaDataViewControl*) implementation
{
  return implementation;
}

-(wxDataViewModel*) model
{
  return model;
}

-(void) setCurrentParentItem:(wxPointerObject*)newCurrentParentItem
{
  [newCurrentParentItem retain];
  [currentParentItem release];
  currentParentItem = newCurrentParentItem;
}

-(void) setImplementation:(wxCocoaDataViewControl*) newImplementation
{
  implementation = newImplementation;
}

-(void) setModel:(wxDataViewModel*) newModel
{
  model = newModel;
}

//
// other methods
//
-(void) bufferItem:(wxPointerObject*)parentItem withChildren:(wxDataViewItemArray*)dataViewChildrenPtr
{
  NSInteger const noOfChildren = (*dataViewChildrenPtr).GetCount();

  [self setCurrentParentItem:parentItem];
  [self clearChildren];
  for (NSInteger indexChild=0; indexChild<noOfChildren; ++indexChild)
  {
    wxPointerObject* bufferedPointerObject;
    wxPointerObject* newPointerObject([[wxPointerObject alloc] initWithPointer:(*dataViewChildrenPtr)[indexChild].GetID()]);

   // The next statement and test looks strange but there is unfortunately no workaround:
   // due to the fact that two pointer objects are identical if their pointers are identical - because the method isEqual
   // has been overloaded - the set operation will only add a new pointer object if there is not already one in the set
   // having the same pointer. On the other side the children's array would always add the new pointer object. This means
   // that different pointer objects are stored in the set and array. This will finally lead to a crash as objects diverge.
   // To solve this issue it is first tested if the child already exists in the set and if it is the case the sets object
   // is going to be appended to the array, otheriwse the new pointer object is added to the set and array:
    bufferedPointerObject = [self getItemFromBuffer:newPointerObject];
    if (bufferedPointerObject == nil)
    {
      [items    addObject:newPointerObject];
      [children addObject:newPointerObject];
    }
    else
      [children addObject:bufferedPointerObject];
    [newPointerObject release];
  }
}

@end

// ============================================================================
// wxCustomCell
// ============================================================================
@implementation wxCustomCell
//
// other methods
//
-(NSSize) cellSize
{
  wxCustomRendererObject* customRendererObject(((wxCustomRendererObject*)[self objectValue]));


  return NSMakeSize(customRendererObject->customRenderer->GetSize().GetWidth(),customRendererObject->customRenderer->GetSize().GetHeight());
}

//
// implementations
//
-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  wxCustomRendererObject* customRendererObject(((wxCustomRendererObject*)[self objectValue]));


 // draw its own background:
  [[self backgroundColor] set];
  NSRectFill(cellFrame);

  (void) (customRendererObject->customRenderer->Render(wxFromNSRect(controlView,cellFrame),customRendererObject->customRenderer->GetDC(),0));
  customRendererObject->customRenderer->SetDC(NULL);
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
-(NSUInteger) hitTestForEvent:(NSEvent*)event inRect:(NSRect)cellFrame ofView:(NSView*)controlView
{
  NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];

  wxCustomRendererObject* customRendererObject((wxCustomRendererObject*)[self objectValue]);



  customRendererObject->customRenderer->LeftClick(wxFromNSPoint(controlView,point),wxFromNSRect(controlView,cellFrame),
                                                  customRendererObject->GetOwner()->GetOwner(),wxDataViewItem([customRendererObject->item pointer]),
                                                  [this->m_OutlineView columnWithIdentifier:[customRendererObject->GetColumnPtr() identifier]]);
  return NSCellHitContentArea;
}
#endif

-(NSRect) imageRectForBounds:(NSRect)cellFrame
{
  return cellFrame;
}

-(NSRect) titleRectForBounds:(NSRect)cellFrame
{
   return cellFrame;
}

@end

// ============================================================================
// wxImageTextCell
// ============================================================================
@implementation wxImageTextCell
//
// initialization
//
-(id) init
{
  self = [super init];
  if (self != nil)
  {
   // initializing the text part:
    [self setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [self setSelectable:YES];
   // initializing the image part:
    image       = nil;
    imageSize   = NSMakeSize(16,16);
    spaceImageText = 5.0;
    xImageShift    = 5.0;
  }
  return self;
}

-(id) copyWithZone:(NSZone*)zone
{
  wxImageTextCell* cell;
  
  
  cell = (wxImageTextCell*) [super copyWithZone:zone];
  cell->image          = [image retain];
  cell->imageSize      = imageSize;
  cell->spaceImageText = spaceImageText;
  cell->xImageShift    = xImageShift;

  return cell;
}

-(void) dealloc
{
  [image release];

  [super dealloc];
}

//
// alignment
//
-(NSTextAlignment) alignment
{
  return cellAlignment;
}

-(void) setAlignment:(NSTextAlignment)newAlignment
{
  cellAlignment = newAlignment;
  switch (newAlignment)
  {
    case NSCenterTextAlignment:
    case NSLeftTextAlignment:
    case NSJustifiedTextAlignment:
    case NSNaturalTextAlignment:
      [super setAlignment:NSLeftTextAlignment];
      break;
    case NSRightTextAlignment:
      [super setAlignment:NSRightTextAlignment];
      break;
    default:
      wxFAIL_MSG(_("Unknown alignment type."));
  }
}

//
// image access
//
-(NSImage*) image
{
  return image;
}

-(void) setImage:(NSImage*)newImage
{
  [newImage retain];
  [image release];
  image = newImage;
}

-(NSSize) imageSize
{
  return imageSize;
}

-(void) setImageSize:(NSSize) newImageSize
{
  imageSize = newImageSize;
}

//
// other methods
//
-(NSSize) cellImageSize
{
  return NSMakeSize(imageSize.width+xImageShift+spaceImageText,imageSize.height);
}

-(NSSize) cellSize
{
  NSSize cellSize([super cellSize]);


  if (imageSize.height > cellSize.height)
    cellSize.height = imageSize.height;
  cellSize.width += imageSize.width+xImageShift+spaceImageText;

  return cellSize;
}

-(NSSize) cellTextSize
{
  return [super cellSize];
}

//
// implementations
//
-(void) determineCellParts:(NSRect)cellFrame imagePart:(NSRect*)imageFrame textPart:(NSRect*)textFrame
{
  switch (cellAlignment)
  {
    case NSCenterTextAlignment:
      {
        CGFloat const cellSpace = cellFrame.size.width-[self cellSize].width;

        if (cellSpace <= 0) // if the cell's frame is smaller than its contents (at least in x-direction) make sure that the image is visible:
          NSDivideRect(cellFrame,imageFrame,textFrame,xImageShift+imageSize.width+spaceImageText,NSMinXEdge);
        else // otherwise center the image and text in the cell's frame
          NSDivideRect(cellFrame,imageFrame,textFrame,xImageShift+imageSize.width+spaceImageText+0.5*cellSpace,NSMinXEdge);
      }
      break;
    case NSJustifiedTextAlignment:
    case NSLeftTextAlignment:
    case NSNaturalTextAlignment: // how to determine the natural writing direction? TODO
      NSDivideRect(cellFrame,imageFrame,textFrame,xImageShift+imageSize.width+spaceImageText,NSMinXEdge);
      break;
    case NSRightTextAlignment:
      {
        CGFloat const cellSpace = cellFrame.size.width-[self cellSize].width;

        if (cellSpace <= 0) // if the cell's frame is smaller than its contents (at least in x-direction) make sure that the image is visible:
          NSDivideRect(cellFrame,imageFrame,textFrame,xImageShift+imageSize.width+spaceImageText,NSMinXEdge);
        else // otherwise right align the image and text in the cell's frame
          NSDivideRect(cellFrame,imageFrame,textFrame,xImageShift+imageSize.width+spaceImageText+cellSpace,NSMinXEdge);
      }
      break;
    default:
      *imageFrame = NSZeroRect;
      *textFrame  = NSZeroRect;
      wxFAIL_MSG(_("Unhandled alignment type."));
  }
}

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  NSRect textFrame, imageFrame;


  [self determineCellParts:cellFrame imagePart:&imageFrame textPart:&textFrame];
// draw the image part by ourselves;
 // check if the cell has to draw its own background (checking is done by the parameter of the textfield's cell):
  if ([self drawsBackground])
  {
    [[self backgroundColor] set];
    NSRectFill(imageFrame);
  }
  if (image != nil)
  {
   // the image is slightly shifted (xImageShift) and has a fixed size but the image's frame might be larger and starts
   // currently on the left side of the cell's frame; therefore, the origin and the image's frame size have to be adjusted:
    if (imageFrame.size.width >= xImageShift+imageSize.width+spaceImageText)
    {
      imageFrame.origin.x += imageFrame.size.width-imageSize.width-spaceImageText;
      imageFrame.size.width = imageSize.width;
    }
    else
    {
      imageFrame.origin.x   += xImageShift;
      imageFrame.size.width -= xImageShift+spaceImageText;
    }
   // ...and the image has to be centered in the y-direction:
    if (imageFrame.size.height > imageSize.height)
      imageFrame.size.height = imageSize.height;
    imageFrame.origin.y += ceil(0.5*(cellFrame.size.height-imageFrame.size.height));

   // according to the documentation the coordinate system should be flipped for NSTableViews (y-coordinate goes from top to bottom);
   // to draw an image correctly the coordinate system has to be transformed to a bottom-top coordinate system, otherwise the image's
   // content is flipped:
    NSAffineTransform* coordinateTransform([NSAffineTransform transform]);
    
    if ([controlView isFlipped])
    {
      [coordinateTransform scaleXBy: 1.0 yBy:-1.0]; // first the coordinate system is brought back to bottom-top orientation
      [coordinateTransform translateXBy:0.0 yBy:(-2.0)*imageFrame.origin.y-imageFrame.size.height]; // the coordinate system has to be moved to compensate for the
      [coordinateTransform concat];                                                                 // other orientation and the position of the image's frame
    }
    [image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0]; // suggested method to draw the image
                                                                                                    // instead of compositeToPoint:operation:
   // take back previous transformation (if the view is not flipped the coordinate transformation matrix contains the identity matrix
   // and the next two operations do not change the content's transformation matrix):
    [coordinateTransform invert];
    [coordinateTransform concat];
  }
 // let the textfield cell draw the text part:
  if (textFrame.size.width > [self cellTextSize].width) // for unknown reasons the alignment of the text cell is ignored; therefore change the size so that
    textFrame.size.width = [self cellTextSize].width;   // alignment does not influence the visualization anymore
  [super drawWithFrame:textFrame inView:controlView];
}

-(void) editWithFrame:(NSRect)aRect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject event:(NSEvent*)theEvent
{
  NSRect textFrame, imageFrame;


  [self determineCellParts:aRect imagePart:&imageFrame textPart:&textFrame];
  [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
-(NSUInteger) hitTestForEvent:(NSEvent*)event inRect:(NSRect)cellFrame ofView:(NSView*)controlView
{
  NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];

  NSRect imageFrame, textFrame;


  [self determineCellParts:cellFrame imagePart:&imageFrame textPart:&textFrame];
  if (image != nil)
  {
   // the image is shifted...
    if (imageFrame.size.width >= xImageShift+imageSize.width+spaceImageText)
    {
      imageFrame.origin.x += imageFrame.size.width-imageSize.width-spaceImageText;
      imageFrame.size.width = imageSize.width;
    }
    else
    {
      imageFrame.origin.x   += xImageShift;
      imageFrame.size.width -= xImageShift+spaceImageText;
    }
   // ...and centered:
    if (imageFrame.size.height > imageSize.height)
      imageFrame.size.height = imageSize.height;
    imageFrame.origin.y += ceil(0.5*(cellFrame.size.height-imageFrame.size.height));
    // If the point is in the image rect, then it is a content hit (see documentation for hitTestForEvent:inRect:ofView):
    if (NSMouseInRect(point, imageFrame, [controlView isFlipped]))
      return NSCellHitContentArea;
  }
 // if the image was not hit let's try the text part:
  if (textFrame.size.width > [self cellTextSize].width) // for unknown reasons the alignment of the text cell is ignored; therefore change the size so that
    textFrame.size.width = [self cellTextSize].width;   // alignment does not influence the visualization anymore
  return [super hitTestForEvent:event inRect:textFrame ofView:controlView];    
}
#endif

-(NSRect) imageRectForBounds:(NSRect)cellFrame
{
  NSRect textFrame, imageFrame;


  [self determineCellParts:cellFrame imagePart:&imageFrame textPart:&textFrame];
  if (imageFrame.size.width >= xImageShift+imageSize.width+spaceImageText)
  {
    imageFrame.origin.x += imageFrame.size.width-imageSize.width-spaceImageText;
    imageFrame.size.width = imageSize.width;
  }
  else
  {
    imageFrame.origin.x   += xImageShift;
    imageFrame.size.width -= xImageShift+spaceImageText;
  }
 // ...and centered:
  if (imageFrame.size.height > imageSize.height)
    imageFrame.size.height = imageSize.height;
  imageFrame.origin.y += ceil(0.5*(cellFrame.size.height-imageFrame.size.height));
  
  return imageFrame;
}

-(void) selectWithFrame:(NSRect)aRect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
  NSRect textFrame, imageFrame;


  [self determineCellParts:aRect imagePart:&imageFrame textPart:&textFrame];
  [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

-(NSRect) titleRectForBounds:(NSRect)cellFrame
{
  NSRect textFrame, imageFrame;


  [self determineCellParts:cellFrame imagePart:&imageFrame textPart:&textFrame];
   return textFrame;
}

@end

// ============================================================================
// wxCocoaOutlineView
// ============================================================================
@implementation wxCocoaOutlineView

//
// initializers / destructor
//
-(id) init
{
  self = [super init];
  if (self != nil)
  {
    isEditingCell = NO;
    [self registerForDraggedTypes:[NSArray arrayWithObjects:DataViewPboardType,NSStringPboardType,nil]];
    [self setDelegate:self];
    [self setDoubleAction:@selector(actionDoubleClick:)];
    [self setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    [self setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [self setTarget:self];
  }
  return self;
}

//
// access to wxWidget's implementation
//
-(wxCocoaDataViewControl*) implementation
{
  return implementation;
}

-(void) setImplementation:(wxCocoaDataViewControl*) newImplementation
{
  implementation = newImplementation;
}

//
// actions
//
-(void) actionDoubleClick:(id)sender
 // actually the documentation (NSTableView 2007-10-31) for doubleAction: and setDoubleAction: seems to be wrong as this action message is always sent
 // whether the cell is editable or not
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();

  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_ACTIVATED,dataViewCtrlPtr->GetId()); // variable definition


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) [self itemAtRow:[self clickedRow]]) pointer]));
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
}


//
// contextual menus
//
-(NSMenu*) menuForEvent:(NSEvent*)theEvent
 // this method does not do any special menu event handling but only sends an event message; therefore, the user
 // has full control if a context menu should be shown or not
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
            
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_CONTEXT_MENU,dataViewCtrlPtr->GetId());

  wxDataViewItemArray selectedItems;


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetModel(dataViewCtrlPtr->GetModel());
 // get the item information;
 // theoretically more than one ID can be returned but the event can only handle one item, therefore only the first
 // item of the array is returned:
  if (dataViewCtrlPtr->GetSelections(selectedItems) > 0)
    dataViewEvent.SetItem(selectedItems[0]);
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
 // nothing is done:
  return nil;
}

//
// delegate methods
//
-(void) outlineView:(NSOutlineView*)outlineView mouseDownInHeaderOfTableColumn:(NSTableColumn*)tableColumn
{
  wxDataViewColumn* const dataViewColumnPtr(reinterpret_cast<wxDataViewColumn*>([[tableColumn identifier] pointer]));

  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
            
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_COLUMN_HEADER_CLICK,dataViewCtrlPtr->GetId());


 // first, send an event that the user clicked into a column's header:
  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetColumn(dataViewCtrlPtr->GetColumnPosition(dataViewColumnPtr));
  dataViewEvent.SetDataViewColumn(dataViewColumnPtr);
  dataViewCtrlPtr->HandleWindowEvent(dataViewEvent);

 // now, check if the click may have had an influence on sorting, too;
 // the sorting setup has to be done only if the clicked table column is sortable and has not been used for
 // sorting before the click; if the column is already responsible for sorting the native control changes
 // the sorting direction automatically and informs the data source via outlineView:sortDescriptorsDidChange:
  if (dataViewColumnPtr->IsSortable() && ([tableColumn sortDescriptorPrototype] == nil))
  {
   // remove the sort order from the previously sorted column table (it can also be that
   // no sorted column table exists):
    UInt32 const noOfColumns = [outlineView numberOfColumns];
    
    for (UInt32 i=0; i<noOfColumns; ++i)
      [[[outlineView tableColumns] objectAtIndex:i] setSortDescriptorPrototype:nil];
   // make column table sortable:
    NSArray*          sortDescriptors;
    NSSortDescriptor* sortDescriptor;
    
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:[NSString stringWithFormat:@"%d",[outlineView columnWithIdentifier:[tableColumn identifier]]]
                                                 ascending:YES];
    sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    [tableColumn setSortDescriptorPrototype:sortDescriptor];
    [outlineView setSortDescriptors:sortDescriptors];
    [sortDescriptor release];
  }
}

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldCollapseItem:(id)item
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
            
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_COLLAPSING,dataViewCtrlPtr->GetId()); // variable definition


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetItem       (wxDataViewItem([((wxPointerObject*) item) pointer]));
  dataViewEvent.SetModel      (dataViewCtrlPtr->GetModel());
 // finally send the equivalent wxWidget event:
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
 // opening the container is allowed if not vetoed:
  return dataViewEvent.IsAllowed();
}

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldExpandItem:(id)item
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
            
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_EXPANDING,dataViewCtrlPtr->GetId()); // variable definition


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetItem       (wxDataViewItem([((wxPointerObject*) item) pointer]));
  dataViewEvent.SetModel      (dataViewCtrlPtr->GetModel());
 // finally send the equivalent wxWidget event:
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
 // opening the container is allowed if not vetoed:
  return dataViewEvent.IsAllowed();
}

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldSelectTableColumn:(NSTableColumn*)tableColumn
{
  return NO;
}

-(void) outlineView:(NSOutlineView*)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*) tableColumn item:(id)item
{
  wxDataViewColumn* dataViewColumnPtr(reinterpret_cast<wxDataViewColumn*>([[tableColumn identifier] pointer]));


  dataViewColumnPtr->GetRenderer()->GetNativeData()->SetColumnPtr(tableColumn);
  dataViewColumnPtr->GetRenderer()->GetNativeData()->SetItem(item);
  dataViewColumnPtr->GetRenderer()->GetNativeData()->SetItemCell(cell);
  (void) dataViewColumnPtr->GetRenderer()->Render();
}

//
// notifications
//
-(void) outlineViewColumnDidMove:(NSNotification*)notification
{
  int const newColumnPosition = [[[notification userInfo] objectForKey:@"NSNewColumn"] intValue];

  wxDataViewColumn* const dataViewColumnPtr(reinterpret_cast<wxDataViewColumn*>([[[[self tableColumns] objectAtIndex:newColumnPosition] identifier] pointer]));

  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
  
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_COLUMN_REORDERED,dataViewCtrlPtr->GetId());


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetColumn(dataViewCtrlPtr->GetColumnPosition(dataViewColumnPtr));
  dataViewEvent.SetDataViewColumn(dataViewColumnPtr);
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
}

-(void) outlineViewItemDidCollapse:(NSNotification*)notification
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
            
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_COLLAPSED,dataViewCtrlPtr->GetId());


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) [[notification userInfo] objectForKey:@"NSObject"]) pointer]));
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
}

-(void) outlineViewItemDidExpand:(NSNotification*)notification
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();
            
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_EXPANDED,dataViewCtrlPtr->GetId());


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) [[notification userInfo] objectForKey:@"NSObject"]) pointer]));
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
}

-(void) outlineViewSelectionDidChange:(NSNotification*)notification
{
  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();

  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_SELECTION_CHANGED,dataViewCtrlPtr->GetId()); // variable definition


  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetModel      (dataViewCtrlPtr->GetModel());
 // finally send the equivalent wxWidget event:
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
}

-(void) textDidBeginEditing:(NSNotification*)notification
 // this notification is only sent if the user started modifying the cell (not when the user clicked into the cell
 // and the cell's editor is called!)
{
 // call method of superclass (otherwise editing does not work correctly - the outline data source class is not
 // informed about a change of data):
  [super textDidBeginEditing:notification];

  wxDataViewColumn* const dataViewColumnPtr = reinterpret_cast<wxDataViewColumn*>([[[[self tableColumns] objectAtIndex:[self editedColumn]] identifier] pointer]);

  wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();


 // stop editing of a custom item first (if necessary)
  dataViewCtrlPtr->FinishCustomItemEditing();
 // set the flag that currently a cell is being edited (see also textDidEndEditing:):
  isEditingCell = YES;

 // now, send the event:
  wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_EDITING_STARTED,dataViewCtrlPtr->GetId()); // variable definition

  dataViewEvent.SetEventObject(dataViewCtrlPtr);
  dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) [self itemAtRow:[self editedRow]]) pointer]));
  dataViewEvent.SetColumn(dataViewCtrlPtr->GetColumnPosition(dataViewColumnPtr));
  dataViewEvent.SetDataViewColumn(dataViewColumnPtr);
  dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
}

-(void) textDidEndEditing:(NSNotification*)notification
{
 // call method of superclass (otherwise editing does not work correctly - the outline data source class is not
 // informed about a change of data):
  [super textDidEndEditing:notification];

 // under OSX an event indicating the end of an editing session can be sent even if no event indicating a start of an
 // editing session has been sent (see Documentation for NSControl controlTextDidEndEditing:); this is not expected by a user
 // of the wxWidgets library and therefore an wxEVT_COMMAND_DATAVIEW_ITEM_EDITING_DONE event is only sent if a corresponding
 // wxEVT_COMMAND_DATAVIEW_ITEM_EDITING_STARTED has been sent before; to check if a wxEVT_COMMAND_DATAVIEW_ITEM_EDITING_STARTED
 // has been sent the flag isEditingCell is used:
  if (isEditingCell == YES)
  {
    wxDataViewColumn* const dataViewColumnPtr = reinterpret_cast<wxDataViewColumn*>([[[[self tableColumns] objectAtIndex:[self editedColumn]] identifier] pointer]);

    wxDataViewCtrl* const dataViewCtrlPtr = implementation->GetDataViewCtrl();

   // send event to wxWidgets:
    wxDataViewEvent dataViewEvent(wxEVT_COMMAND_DATAVIEW_ITEM_EDITING_DONE,dataViewCtrlPtr->GetId()); // variable definition

    dataViewEvent.SetEventObject(dataViewCtrlPtr);
    dataViewEvent.SetItem(wxDataViewItem([((wxPointerObject*) [self itemAtRow:[self editedRow]]) pointer]));
    dataViewEvent.SetColumn(dataViewCtrlPtr->GetColumnPosition(dataViewColumnPtr));
    dataViewEvent.SetDataViewColumn(dataViewColumnPtr);
    dataViewCtrlPtr->GetEventHandler()->ProcessEvent(dataViewEvent);
   // set flag to the inactive state:
    isEditingCell = NO;
  }
}

@end
// ============================================================================
// wxCocoaDataViewControl
// ============================================================================
//
// constructors / destructor
//
wxCocoaDataViewControl::wxCocoaDataViewControl(wxWindow* peer, wxPoint const& pos, wxSize const& size, long style)
                       :wxWidgetCocoaImpl(peer,[[NSScrollView alloc] initWithFrame:wxOSXGetFrameForControl(peer,pos,size)]),
                        m_DataSource(NULL), m_OutlineView([[wxCocoaOutlineView alloc] init])
{
 // initialize scrollview (the outline view is part of a scrollview):
  NSScrollView* scrollview = (NSScrollView*) this->GetWXWidget(); // definition for abbreviational purposes
  

  [scrollview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [scrollview setBorderType:NSNoBorder];
  [scrollview setHasVerticalScroller:YES];
  [scrollview setHasHorizontalScroller:YES];
  [scrollview setAutohidesScrollers:YES];
  [scrollview setDocumentView:this->m_OutlineView];

 // setting up the native control itself
  NSUInteger maskGridStyle(NSTableViewGridNone);

  [this->m_OutlineView setImplementation:this];
  [this->m_OutlineView setColumnAutoresizingStyle:NSTableViewSequentialColumnAutoresizingStyle];
  [this->m_OutlineView setIndentationPerLevel:this->GetDataViewCtrl()->GetIndent()];
  if (style & wxDV_HORIZ_RULES)
    maskGridStyle |= NSTableViewSolidHorizontalGridLineMask;
  if (style & wxDV_VERT_RULES)
    maskGridStyle |= NSTableViewSolidVerticalGridLineMask;
  [this->m_OutlineView setGridStyleMask:maskGridStyle];
  [this->m_OutlineView setAllowsMultipleSelection:           (style & wxDV_MULTIPLE)  != 0];
  [this->m_OutlineView setUsesAlternatingRowBackgroundColors:(style & wxDV_ROW_LINES) != 0];
}

wxCocoaDataViewControl::~wxCocoaDataViewControl(void)
{
  [this->m_DataSource  release];
  [this->m_OutlineView release];
}

//
// column related methods (inherited from wxDataViewWidgetImpl)
//
bool wxCocoaDataViewControl::ClearColumns(void)
{
  bool const bufAllowsMultipleSelection = [this->m_OutlineView allowsMultipleSelection];


 // as there is a bug in NSOutlineView version (OSX 10.5.6 #6555162) the columns cannot be deleted if there is an outline column in the view;
 // therefore, the whole view is deleted and newly constructed:
  [this->m_OutlineView release];
  this->m_OutlineView = [[wxCocoaOutlineView alloc] init];
  [((NSScrollView*) this->GetWXWidget()) setDocumentView:this->m_OutlineView];

 // setting up the native control itself
  [this->m_OutlineView setImplementation:this];
  [this->m_OutlineView setColumnAutoresizingStyle:NSTableViewSequentialColumnAutoresizingStyle];
  [this->m_OutlineView setIndentationPerLevel:this->GetDataViewCtrl()->GetIndent()];
  if (bufAllowsMultipleSelection)
    [this->m_OutlineView setAllowsMultipleSelection:YES];
  [this->m_OutlineView setDataSource:this->m_DataSource];
 // done:
  return true;
}

bool wxCocoaDataViewControl::DeleteColumn(wxDataViewColumn* columnPtr)
{
  if ([this->m_OutlineView outlineTableColumn] == columnPtr->GetNativeData()->GetNativeColumnPtr())
    [this->m_OutlineView setOutlineTableColumn:nil]; // due to a bug this does not work
  [this->m_OutlineView removeTableColumn:columnPtr->GetNativeData()->GetNativeColumnPtr()]; // due to a confirmed bug #6555162 the deletion does not work for
                                                                                            // outline table columns (... and there is no workaround)
  return (([this->m_OutlineView columnWithIdentifier:[[[wxPointerObject alloc] initWithPointer:columnPtr] autorelease]]) == -1);
}

void wxCocoaDataViewControl::DoSetExpanderColumn(wxDataViewColumn const* columnPtr)
{
  [this->m_OutlineView setOutlineTableColumn:columnPtr->GetNativeData()->GetNativeColumnPtr()];
}

wxDataViewColumn* wxCocoaDataViewControl::GetColumn(unsigned int pos) const
{
  return reinterpret_cast<wxDataViewColumn*>([[[[this->m_OutlineView tableColumns] objectAtIndex:pos] identifier] pointer]);
}

int wxCocoaDataViewControl::GetColumnPosition(wxDataViewColumn const* columnPtr) const
{
  return [this->m_OutlineView columnWithIdentifier:[[[wxPointerObject alloc] initWithPointer:const_cast<wxDataViewColumn*>(columnPtr)] autorelease]];
}

bool wxCocoaDataViewControl::InsertColumn(unsigned int pos, wxDataViewColumn* columnPtr)
{
  NSTableColumn* nativeColumn;


 // create column and set the native data of the dataview column:
  nativeColumn = ::CreateNativeColumn(columnPtr);
  columnPtr->GetNativeData()->SetNativeColumnPtr(nativeColumn);
 // as the native control does not allow the insertion of a column at a specified position the column is first appended and
 // - if necessary - moved to its final position:
  [this->m_OutlineView addTableColumn:nativeColumn];
  if (pos != static_cast<unsigned int>([this->m_OutlineView numberOfColumns]-1))
    [this->m_OutlineView moveColumn:[this->m_OutlineView numberOfColumns]-1 toColumn:pos];
 // done:
  return true;
}

//
// item related methods (inherited from wxDataViewWidgetImpl)
//
bool wxCocoaDataViewControl::Add(wxDataViewItem const& parent, wxDataViewItem const& WXUNUSED(item))
{
  if (parent.IsOk())
    [this->m_OutlineView reloadItem:[this->m_DataSource getDataViewItemFromBuffer:parent] reloadChildren:YES];
  else
    [this->m_OutlineView reloadData];
  return true;
}

bool wxCocoaDataViewControl::Add(wxDataViewItem const& parent, wxDataViewItemArray const& WXUNUSED(items))
{
  if (parent.IsOk())
    [this->m_OutlineView reloadItem:[this->m_DataSource getDataViewItemFromBuffer:parent] reloadChildren:YES];
  else
    [this->m_OutlineView reloadData];
  return true;
}

void wxCocoaDataViewControl::Collapse(wxDataViewItem const& item)
{
  [this->m_OutlineView collapseItem:[this->m_DataSource getDataViewItemFromBuffer:item]];
}

void wxCocoaDataViewControl::EnsureVisible(wxDataViewItem const& item, wxDataViewColumn const* columnPtr)
{
  if (item.IsOk())
  {
    [this->m_OutlineView scrollRowToVisible:[this->m_OutlineView rowForItem:[this->m_DataSource getDataViewItemFromBuffer:item]]];
    if (columnPtr != NULL)
      [this->m_OutlineView scrollColumnToVisible:this->GetColumnPosition(columnPtr)];
  }
}

void wxCocoaDataViewControl::Expand(wxDataViewItem const& item)
{
  [this->m_OutlineView expandItem:[this->m_DataSource getDataViewItemFromBuffer:item]];
}

unsigned int wxCocoaDataViewControl::GetCount(void) const
{
  return [this->m_OutlineView numberOfRows];
}

wxRect wxCocoaDataViewControl::GetRectangle(wxDataViewItem const& item, wxDataViewColumn const* columnPtr)
{
  return wxFromNSRect([m_osxView superview],[this->m_OutlineView frameOfCellAtColumn:this->GetColumnPosition(columnPtr)
                                             row:[this->m_OutlineView rowForItem:[this->m_DataSource getDataViewItemFromBuffer:item]]]);
}

bool wxCocoaDataViewControl::IsExpanded(wxDataViewItem const& item) const
{
  return [this->m_OutlineView isItemExpanded:[this->m_DataSource getDataViewItemFromBuffer:item]];
}

bool wxCocoaDataViewControl::Reload(void)
{
  [this->m_DataSource clearBuffers];
  [this->m_OutlineView scrollColumnToVisible:0];
  [this->m_OutlineView scrollRowToVisible:0];
  [this->m_OutlineView reloadData];
  return true;
}

bool wxCocoaDataViewControl::Remove(wxDataViewItem const& parent, wxDataViewItem const& WXUNUSED(item))
{
  if (parent.IsOk())
    [this->m_OutlineView reloadItem:[this->m_DataSource getDataViewItemFromBuffer:parent] reloadChildren:YES];
  else
    [this->m_OutlineView reloadData];
  return true;
}

bool wxCocoaDataViewControl::Remove(wxDataViewItem const& parent, wxDataViewItemArray const& WXUNUSED(item))
{
  if (parent.IsOk())
    [this->m_OutlineView reloadItem:[this->m_DataSource getDataViewItemFromBuffer:parent] reloadChildren:YES];
  else
    [this->m_OutlineView reloadData];
  return true;
}

bool wxCocoaDataViewControl::Update(wxDataViewColumn const* columnPtr)
{
  return false;
}

bool wxCocoaDataViewControl::Update(wxDataViewItem const& WXUNUSED(parent), wxDataViewItem const& item)
{
  [this->m_OutlineView reloadItem:[this->m_DataSource getDataViewItemFromBuffer:item]];
  return true;
}

bool wxCocoaDataViewControl::Update(wxDataViewItem const& WXUNUSED(parent), wxDataViewItemArray const& items)
{
  for (size_t i=0; i<items.GetCount(); ++i)
    [this->m_OutlineView reloadItem:[this->m_DataSource getDataViewItemFromBuffer:items[i]]];
  return true;
}

//
// model related methods
//
bool wxCocoaDataViewControl::AssociateModel(wxDataViewModel* model)
{
  [this->m_DataSource release];
  if (model != NULL)
  {
    this->m_DataSource = [[wxCocoaOutlineDataSource alloc] init];
    [this->m_DataSource setImplementation:this];
    [this->m_DataSource setModel:model];
  }
  else
    this->m_DataSource = NULL;
  [this->m_OutlineView setDataSource:this->m_DataSource]; // if there is a data source the data is immediately going to be requested
  return true;
}

//
// selection related methods (inherited from wxDataViewWidgetImpl)
//
int wxCocoaDataViewControl::GetSelections(wxDataViewItemArray& sel) const
{
  NSIndexSet* selectedRowIndexes([this->m_OutlineView selectedRowIndexes]);
  
  NSUInteger indexRow;

  
  sel.Empty();
  sel.Alloc([selectedRowIndexes count]);
  indexRow = [selectedRowIndexes firstIndex];
  while (indexRow != NSNotFound)
  {
    sel.Add(wxDataViewItem([[this->m_OutlineView itemAtRow:indexRow] pointer]));
    indexRow = [selectedRowIndexes indexGreaterThanIndex:indexRow];
  }
  return sel.GetCount();
}

bool wxCocoaDataViewControl::IsSelected(wxDataViewItem const& item) const
{
  return [this->m_OutlineView isRowSelected:[this->m_OutlineView rowForItem:[this->m_DataSource getDataViewItemFromBuffer:item]]];
}

void wxCocoaDataViewControl::Select(wxDataViewItem const& item)
{
  if (item.IsOk())
    [this->m_OutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[this->m_OutlineView rowForItem:[this->m_DataSource getDataViewItemFromBuffer:item]]]
                        byExtendingSelection:NO];
}

void wxCocoaDataViewControl::SelectAll(void)
{
  [this->m_OutlineView selectAll:this->m_OutlineView];
}

void wxCocoaDataViewControl::Unselect(wxDataViewItem const& item)
{
  if (item.IsOk())
    [this->m_OutlineView deselectRow:[this->m_OutlineView rowForItem:[this->m_DataSource getDataViewItemFromBuffer:item]]];
}

void wxCocoaDataViewControl::UnselectAll(void)
{
  [this->m_OutlineView deselectAll:this->m_OutlineView];
}

//
// sorting related methods
//
wxDataViewColumn* wxCocoaDataViewControl::GetSortingColumn(void) const
{
  NSArray* const columns = [this->m_OutlineView tableColumns];

  UInt32 const noOfColumns = [columns count];


  for (UInt32 i=0; i<noOfColumns; ++i)
    if ([[columns objectAtIndex:i] sortDescriptorPrototype] != nil)
      return reinterpret_cast<wxDataViewColumn*>([[[columns objectAtIndex:i] identifier] pointer]);
  return NULL;
}

void wxCocoaDataViewControl::Resort(void)
{
  [this->m_DataSource clearChildren];
  [this->m_OutlineView reloadData];
}

//
// other methods (inherited from wxDataViewWidgetImpl)
//
void wxCocoaDataViewControl::DoSetIndent(int indent)
{
  [this->m_OutlineView setIndentationPerLevel:static_cast<CGFloat>(indent)];
}

void wxCocoaDataViewControl::HitTest(wxPoint const& point, wxDataViewItem& item, wxDataViewColumn*& columnPtr) const
{
  NSPoint const nativePoint = wxToNSPoint((NSScrollView*) this->GetWXWidget(),point);

  int indexColumn;
  int indexRow;

  
  indexColumn = [this->m_OutlineView columnAtPoint:nativePoint];
  indexRow    = [this->m_OutlineView rowAtPoint:   nativePoint];
  if ((indexColumn >= 0) && (indexRow >= 0))
  {
    columnPtr = reinterpret_cast<wxDataViewColumn*>([[[[this->m_OutlineView tableColumns] objectAtIndex:indexColumn] identifier] pointer]);
    item      = wxDataViewItem([[this->m_OutlineView itemAtRow:indexRow] pointer]);
  }
  else
  {
    columnPtr = NULL;
    item      = wxDataViewItem();
  }
}

void wxCocoaDataViewControl::SetRowHeight(wxDataViewItem const& WXUNUSED(item), unsigned int WXUNUSED(height))
 // Not supported by the native control
{
}

void wxCocoaDataViewControl::OnSize(void)
{
  if ([this->m_OutlineView numberOfColumns] == 1)
    [this->m_OutlineView sizeLastColumnToFit];
}

//
// drag & drop helper methods
//
wxDataFormat wxCocoaDataViewControl::GetDnDDataFormat(wxDataObjectComposite* dataObjects)
{
  wxDataFormat resultFormat;


  if (dataObjects != NULL)
  {
    bool compatible(true);

    size_t const noOfFormats = dataObjects->GetFormatCount();
    size_t       indexFormat;

    wxDataFormat* formats;
    
   // get all formats and check afterwards if the formats are compatible; if they are compatible the preferred format is returned otherwise
   // wxDF_INVALID is returned;
   // currently compatible types (ordered by priority are):
   //  - wxDF_UNICODETEXT - wxDF_TEXT
    formats = new wxDataFormat[noOfFormats];
    dataObjects->GetAllFormats(formats);
    indexFormat = 0;
    while ((indexFormat < noOfFormats) && compatible)
    {
      switch (resultFormat.GetType())
      {
        case wxDF_INVALID:
          resultFormat.SetType(formats[indexFormat].GetType()); // first format (should only be reached if indexFormat == 0)
          break;
        case wxDF_TEXT:
          if (formats[indexFormat].GetType() == wxDF_UNICODETEXT)
            resultFormat.SetType(wxDF_UNICODETEXT);
          else // incompatible
          {
            resultFormat.SetType(wxDF_INVALID);
            compatible = false;
          }
          break;
        case wxDF_UNICODETEXT:
          if (formats[indexFormat].GetType() != wxDF_TEXT)
          {
            resultFormat.SetType(wxDF_INVALID);
            compatible = false;
          }
          break;
        default:
          resultFormat.SetType(wxDF_INVALID); // not (yet) supported format
          compatible = false;
      }
      ++indexFormat;
    } /* while */
   // clean up:
    delete[] formats;
  }
  return resultFormat;
}

wxDataObjectComposite* wxCocoaDataViewControl::GetDnDDataObjects(NSData* dataObject) const
{
  wxDataFormatId dataFormatID;

  
  [dataObject getBytes:&dataFormatID length:sizeof(wxDataFormatId)];
  switch (dataFormatID)
  {
    case wxDF_TEXT:
    case wxDF_UNICODETEXT:
      {
        wxTextDataObject* textDataObject(new wxTextDataObject());
        
        if (textDataObject->SetData(wxDataFormat(dataFormatID),[dataObject length]-sizeof(wxDataFormatId),reinterpret_cast<char const*>([dataObject bytes])+sizeof(wxDataFormatId)))
        {
          wxDataObjectComposite* dataObjectComposite(new wxDataObjectComposite());

          dataObjectComposite->Add(textDataObject);
          return dataObjectComposite;
        }
        else
        {
          delete textDataObject;
          return NULL;
        }
      }
      break;
    default:
      return NULL;
  }
}

// ---------------------------------------------------------
// wxDataViewRenderer
// ---------------------------------------------------------
wxDataViewRenderer::wxDataViewRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                   :wxDataViewRendererBase(varianttype,mode,align), m_alignment(align), m_mode(mode), m_NativeDataPtr(NULL)
{
}

wxDataViewRenderer::~wxDataViewRenderer(void)
{
  delete this->m_NativeDataPtr;
}

void wxDataViewRenderer::SetAlignment(int align)
{
  this->m_alignment = align;
  [this->GetNativeData()->GetColumnCell() setAlignment:ConvertToNativeHorizontalTextAlignment(align)];
}

void wxDataViewRenderer::SetMode(wxDataViewCellMode mode)
{
  this->m_mode = mode;
  if (this->GetOwner() != NULL)
    [this->GetOwner()->GetNativeData()->GetNativeColumnPtr() setEditable:(mode == wxDATAVIEW_CELL_EDITABLE)];
}

void wxDataViewRenderer::SetNativeData(wxDataViewRendererNativeData* newNativeDataPtr)
{
  delete this->m_NativeDataPtr;
  this->m_NativeDataPtr = newNativeDataPtr;
}

IMPLEMENT_ABSTRACT_CLASS(wxDataViewRenderer,wxDataViewRendererBase)

// ---------------------------------------------------------
// wxDataViewCustomRenderer
// ---------------------------------------------------------
wxDataViewCustomRenderer::wxDataViewCustomRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                         :wxDataViewRenderer(varianttype,mode,align), m_editorCtrlPtr(NULL), m_DCPtr(NULL)
{
  this->SetNativeData(new wxDataViewRendererNativeData([[wxCustomCell alloc] init]));
}

bool wxDataViewCustomRenderer::Render()
{
  [this->GetNativeData()->GetItemCell() setObjectValue:[[[wxCustomRendererObject alloc] initWithRenderer:this
                                                                                                    item:this->GetNativeData()->GetItem()
                                                                                                  column:this->GetNativeData()->GetColumnPtr()] autorelease]];
  return true;
}

IMPLEMENT_ABSTRACT_CLASS(wxDataViewCustomRenderer, wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewTextRenderer
// ---------------------------------------------------------
wxDataViewTextRenderer::wxDataViewTextRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                       :wxDataViewRenderer(varianttype,mode,align)
{
  NSTextFieldCell* cell;
  
  
  cell = [[NSTextFieldCell alloc] init];
  [cell setAlignment:ConvertToNativeHorizontalTextAlignment(align)];
  [cell setLineBreakMode:NSLineBreakByTruncatingMiddle];
  this->SetNativeData(new wxDataViewRendererNativeData(cell));
  [cell release];
}

bool wxDataViewTextRenderer::Render()
{
  if (this->GetValue().GetType() == this->GetVariantType())
  {
    [this->GetNativeData()->GetItemCell() setObjectValue:wxCFStringRef(this->GetValue().GetString()).AsNSString()];
    return true;
  }
  else
  {
    wxFAIL_MSG(wxString(_("Text renderer cannot render value because of wrong value type; value type: ")) << this->GetValue().GetType());
    return false;
  }
}

IMPLEMENT_CLASS(wxDataViewTextRenderer,wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewBitmapRenderer
// ---------------------------------------------------------
wxDataViewBitmapRenderer::wxDataViewBitmapRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                         :wxDataViewRenderer(varianttype,mode,align)
{
  NSImageCell* cell;
  
  
  cell = [[NSImageCell alloc] init];
  this->SetNativeData(new wxDataViewRendererNativeData(cell));
  [cell release];
}

bool wxDataViewBitmapRenderer::Render()
 // This method returns 'true' if
 //  - the passed bitmap is valid and it could be assigned to the native data browser;
 //  - the passed bitmap is invalid (or is not initialized); this case simulates a non-existing bitmap.
 // In all other cases the method returns 'false'.
{
  wxCHECK_MSG(this->GetValue().GetType() == this->GetVariantType(),false,wxString(_("Bitmap renderer cannot render value; value type: ")) << this->GetValue().GetType());

  wxBitmap bitmap;

  bitmap << this->GetValue();
  if (bitmap.IsOk())
    [this->GetNativeData()->GetItemCell() setObjectValue:[[bitmap.GetNSImage() retain] autorelease]];
  return true;
}

IMPLEMENT_CLASS(wxDataViewBitmapRenderer,wxDataViewRenderer)

// -------------------------------------
// wxDataViewChoiceRenderer
// -------------------------------------
wxDataViewChoiceRenderer::wxDataViewChoiceRenderer(wxArrayString const& choices, wxDataViewCellMode mode, int alignment)
                         :wxDataViewRenderer(wxT("string"),mode,alignment), m_Choices(choices)
{
  NSPopUpButtonCell* cell;
  
  
  cell = [[NSPopUpButtonCell alloc] init];
  [cell setControlSize:NSMiniControlSize];
  [cell setFont:[[NSFont fontWithName:[[cell font] fontName] size:[NSFont systemFontSizeForControlSize:NSMiniControlSize]] autorelease]];
  for (size_t i=0; i<choices.GetCount(); ++i)
    [cell addItemWithTitle:[[wxCFStringRef(choices[i]).AsNSString() retain] autorelease]];
  this->SetNativeData(new wxDataViewRendererNativeData(cell));
  [cell release];
}

bool wxDataViewChoiceRenderer::Render()
{
  if (this->GetValue().GetType() == this->GetVariantType())
  {
    [((NSPopUpButtonCell*) this->GetNativeData()->GetItemCell()) selectItemWithTitle:[[wxCFStringRef(this->GetValue().GetString()).AsNSString() retain] autorelease]];
    return true;
  }
  else
  {
    wxFAIL_MSG(wxString(_("Choice renderer cannot render value because of wrong value type; value type: ")) << this->GetValue().GetType());
    return false;
  }
}

IMPLEMENT_CLASS(wxDataViewChoiceRenderer,wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewDateRenderer
// ---------------------------------------------------------
wxDataViewDateRenderer::wxDataViewDateRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                       :wxDataViewRenderer(varianttype,mode,align)
{
  NSTextFieldCell* cell;

  NSDateFormatter* dateFormatter;

  
  dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
  [dateFormatter setDateStyle:NSDateFormatterShortStyle];
  cell = [[NSTextFieldCell alloc] init];
  [cell setFormatter:dateFormatter];
  [cell setLineBreakMode:NSLineBreakByTruncatingMiddle];
  this->SetNativeData(new wxDataViewRendererNativeData(cell,[NSDate dateWithString:@"2000-12-30 20:00:00 +0000"]));
  [cell          release];
  [dateFormatter release];
}

bool wxDataViewDateRenderer::Render()
{
  if (this->GetValue().GetType() == this->GetVariantType())
  {
    if (this->GetValue().GetDateTime().IsValid())
    {
     // -- find best fitting style to show the date --
     // as the style should be identical for all cells a reference date instead of the actual cell's date
     // value is used for all cells; this reference date is stored in the renderer's native data section
     // for speed purposes; otherwise, the reference date's string has to be recalculated for each item that
     // may become timewise long if a lot of rows using dates exist;
     // the algorithm has the preference to display as much information as possible in the first instance;
     // but as this is often impossible due to space restrictions the style is shortened per loop; finally,
     // if the shortest time and date format does not fit into the cell the time part is dropped;
     // remark: the time part itself is not modified per iteration loop and only uses the short style,
     //         means that only the hours and minutes are being shown
      [this->GetNativeData()->GetItemCell() setObjectValue:this->GetNativeData()->GetObject()]; // GetObject() returns a date for testing the size of a date object
      [[this->GetNativeData()->GetItemCell() formatter] setTimeStyle:NSDateFormatterShortStyle];
      for (int dateFormatterStyle=4; dateFormatterStyle>0; --dateFormatterStyle)
      {
        [[this->GetNativeData()->GetItemCell() formatter] setDateStyle:(NSDateFormatterStyle)dateFormatterStyle];
        if (dateFormatterStyle == 1)
        {
         // if the shortest style for displaying the date and time is too long to be fully visible remove the time part of the date:
          if ([this->GetNativeData()->GetItemCell() cellSize].width > [this->GetNativeData()->GetColumnPtr() width])
            [[this->GetNativeData()->GetItemCell() formatter] setTimeStyle:NSDateFormatterNoStyle];
          break; // basically not necessary as the loop would end anyway but let's save the last comparison
        }
        else if ([this->GetNativeData()->GetItemCell() cellSize].width <= [this->GetNativeData()->GetColumnPtr() width])
          break;
      }
     // set data (the style is set by the previous loop);
     // on OSX the date has to be specified with respect to UTC; in wxWidgets the date is always entered in the local timezone; so, we have to do a conversion
     // from the local to UTC timezone when adding the seconds to 1970-01-01 UTC:
      [this->GetNativeData()->GetItemCell() setObjectValue:[NSDate dateWithTimeIntervalSince1970:this->GetValue().GetDateTime().ToUTC().Subtract(wxDateTime(1,wxDateTime::Jan,1970)).GetSeconds().ToDouble()]];
    }
    return true;
  }
  else
  {
    wxFAIL_MSG(wxString(_("Date renderer cannot render value because of wrong value type; value type: ")) << this->GetValue().GetType());
    return false;
  }
}

IMPLEMENT_ABSTRACT_CLASS(wxDataViewDateRenderer,wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewIconTextRenderer
// ---------------------------------------------------------
wxDataViewIconTextRenderer::wxDataViewIconTextRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                           :wxDataViewRenderer(varianttype,mode)
{
  wxImageTextCell* cell;
  
  
  cell = [[wxImageTextCell alloc] init];
  [cell setAlignment:ConvertToNativeHorizontalTextAlignment(align)];
  this->SetNativeData(new wxDataViewRendererNativeData(cell));
  [cell release];
}

bool wxDataViewIconTextRenderer::Render()
{
  if (this->GetValue().GetType() == this->GetVariantType())
  {
    wxDataViewIconText iconText;
    
    wxImageTextCell* cell;

    cell = (wxImageTextCell*) this->GetNativeData()->GetItemCell();
    iconText << this->GetValue();
    if (iconText.GetIcon().IsOk())
      [cell setImage:[[wxBitmap(iconText.GetIcon()).GetNSImage() retain] autorelease]];
    [cell setStringValue:[[wxCFStringRef(iconText.GetText()).AsNSString() retain] autorelease]];
    return true;
  }
  else
  {
    wxFAIL_MSG(wxString(_("Icon & text renderer cannot render value because of wrong value type; value type: ")) << this->GetValue().GetType());
    return false;
  }
}

IMPLEMENT_ABSTRACT_CLASS(wxDataViewIconTextRenderer,wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewToggleRenderer
// ---------------------------------------------------------
wxDataViewToggleRenderer::wxDataViewToggleRenderer(wxString const& varianttype, wxDataViewCellMode mode, int align)
                         :wxDataViewRenderer(varianttype,mode)
{
  NSButtonCell* cell;
  
  
  cell = [[NSButtonCell alloc] init];
  [cell setAlignment:ConvertToNativeHorizontalTextAlignment(align)];
  [cell setButtonType:NSSwitchButton];
  [cell setImagePosition:NSImageOnly];
  this->SetNativeData(new wxDataViewRendererNativeData(cell));
  [cell release];
}

bool wxDataViewToggleRenderer::Render()
{
  if (this->GetValue().GetType() == this->GetVariantType())
  {
    [this->GetNativeData()->GetItemCell() setIntValue:this->GetValue().GetLong()];
    return true;
  }
  else
  {
    wxFAIL_MSG(wxString(_("Toggle renderer cannot render value because of wrong value type; value type: ")) << this->GetValue().GetType());
    return false;
  }
}

IMPLEMENT_ABSTRACT_CLASS(wxDataViewToggleRenderer,wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewProgressRenderer
// ---------------------------------------------------------
wxDataViewProgressRenderer::wxDataViewProgressRenderer(wxString const& label, wxString const& varianttype, wxDataViewCellMode mode, int align)
                           :wxDataViewRenderer(varianttype,mode,align)
{
  NSLevelIndicatorCell* cell;
  
  
  cell = [[NSLevelIndicatorCell alloc] initWithLevelIndicatorStyle:NSContinuousCapacityLevelIndicatorStyle];
  [cell setMinValue:0];
  [cell setMaxValue:100];
  this->SetNativeData(new wxDataViewRendererNativeData(cell));
  [cell release];
}

bool wxDataViewProgressRenderer::Render()
{
  if (this->GetValue().GetType() == this->GetVariantType())
  {
    [this->GetNativeData()->GetItemCell() setIntValue:this->GetValue().GetLong()];
    return true;
  }
  else
  {
    wxFAIL_MSG(wxString(_("Progress renderer cannot render value because of wrong value type; value type: ")) << this->GetValue().GetType());
    return false;
  }
}

IMPLEMENT_ABSTRACT_CLASS(wxDataViewProgressRenderer,wxDataViewRenderer)

// ---------------------------------------------------------
// wxDataViewColumn
// ---------------------------------------------------------
wxDataViewColumn::wxDataViewColumn(const wxString& title, wxDataViewRenderer* renderer, unsigned int model_column, int width, wxAlignment align, int flags)
                 :wxDataViewColumnBase(renderer, model_column), m_NativeDataPtr(new wxDataViewColumnNativeData()), m_title(title)
{
  this->InitCommon(width, align, flags);
  if ((renderer != NULL) && (renderer->GetAlignment() == wxDVR_DEFAULT_ALIGNMENT))
    renderer->SetAlignment(align);
}

wxDataViewColumn::wxDataViewColumn(const wxBitmap& bitmap, wxDataViewRenderer* renderer, unsigned int model_column, int width, wxAlignment align, int flags)
                 :wxDataViewColumnBase(bitmap, renderer, model_column), m_NativeDataPtr(new wxDataViewColumnNativeData())
{
  this->InitCommon(width, align, flags);
  if ((renderer != NULL) && (renderer->GetAlignment() == wxDVR_DEFAULT_ALIGNMENT))
    renderer->SetAlignment(align);
}

wxDataViewColumn::~wxDataViewColumn(void)
{
  delete this->m_NativeDataPtr;
}

bool wxDataViewColumn::IsSortKey() const
{
  return ((this->GetNativeData()->GetNativeColumnPtr() != NULL) && ([this->GetNativeData()->GetNativeColumnPtr() sortDescriptorPrototype] != nil));
}

void wxDataViewColumn::SetAlignment(wxAlignment align)
{
  this->m_alignment = align;
  [[this->m_NativeDataPtr->GetNativeColumnPtr() headerCell] setAlignment:ConvertToNativeHorizontalTextAlignment(align)];
  if ((this->m_renderer != NULL) && (this->m_renderer->GetAlignment() == wxDVR_DEFAULT_ALIGNMENT))
    this->m_renderer->SetAlignment(align);
}

void wxDataViewColumn::SetBitmap(wxBitmap const& bitmap)
{
 // bitmaps and titles cannot exist at the same time - if the bitmap is set the title is removed:
  this->m_title = wxEmptyString;
  this->wxDataViewColumnBase::SetBitmap(bitmap);
  [[this->m_NativeDataPtr->GetNativeColumnPtr() headerCell] setImage:[[bitmap.GetNSImage() retain] autorelease]];
}

void wxDataViewColumn::SetMaxWidth(int maxWidth)
{
  this->m_maxWidth = maxWidth;
  [this->m_NativeDataPtr->GetNativeColumnPtr() setMaxWidth:maxWidth];
}

void wxDataViewColumn::SetMinWidth(int minWidth)
{
  this->m_minWidth = minWidth;
  [this->m_NativeDataPtr->GetNativeColumnPtr() setMinWidth:minWidth];
}

void wxDataViewColumn::SetReorderable(bool reorderable)
{
}

void wxDataViewColumn::SetResizeable(bool resizeable)
{
  this->wxDataViewColumnBase::SetResizeable(resizeable);
  if (resizeable)
    [this->m_NativeDataPtr->GetNativeColumnPtr() setResizingMask:NSTableColumnUserResizingMask];
  else
    [this->m_NativeDataPtr->GetNativeColumnPtr() setResizingMask:NSTableColumnNoResizing];
}

void wxDataViewColumn::SetSortable(bool sortable)
{
  this->wxDataViewColumnBase::SetSortable(sortable);
}

void wxDataViewColumn::SetSortOrder(bool ascending)
{
  if (m_ascending != ascending)
  {
    m_ascending = ascending;
    if (this->IsSortKey())
    {
     // change sorting order:
      NSArray*          sortDescriptors;
      NSSortDescriptor* sortDescriptor;
      NSTableColumn*    tableColumn;
      
      tableColumn     = this->m_NativeDataPtr->GetNativeColumnPtr();
      sortDescriptor  = [[NSSortDescriptor alloc] initWithKey:[[tableColumn sortDescriptorPrototype] key] ascending:m_ascending];
      sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
      [tableColumn setSortDescriptorPrototype:sortDescriptor];
      [[tableColumn tableView] setSortDescriptors:sortDescriptors];
      [sortDescriptor release];
    }
  }
}

void wxDataViewColumn::SetTitle(wxString const& title)
{
 // bitmaps and titles cannot exist at the same time - if the title is set the bitmap is removed:
  this->wxDataViewColumnBase::SetBitmap(wxBitmap());
  this->m_title = title;
  [[this->m_NativeDataPtr->GetNativeColumnPtr() headerCell] setStringValue:[[wxCFStringRef(title).AsNSString() retain] autorelease]];
}

void wxDataViewColumn::SetWidth(int width)
{
  [this->m_NativeDataPtr->GetNativeColumnPtr() setWidth:width];
  this->m_width = width;
}

void wxDataViewColumn::SetAsSortKey(bool WXUNUSED(sort))
{
 // see wxGTK native wxDataViewColumn implementation
  wxFAIL_MSG(_("not implemented"));
}

void wxDataViewColumn::SetNativeData(wxDataViewColumnNativeData* newNativeDataPtr)
{
  delete this->m_NativeDataPtr;
  this->m_NativeDataPtr = newNativeDataPtr;
}
#endif // (wxUSE_DATAVIEWCTRL == 1) && !defined(wxUSE_GENERICDATAVIEWCTRL)