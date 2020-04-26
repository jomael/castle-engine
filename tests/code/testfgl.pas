{
  Copyright 2004-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Test FGL unit. }
unit TestFGL;

interface

uses
  Classes, SysUtils, FpcUnit, TestUtils, TestRegistry, FGL;

type
  TTestObjectsList = class(TTestCase)
    procedure TestObjectsList;
  end;

implementation

uses CastleUtils, CastleClassUtils;

type
  TItem = class
    Str: string;
  end;

  TItemList = class(specialize TFPGObjectList<TItem>)
    { For each item of the list, delete all it's duplicates. }
    procedure DeleteDuplicates;
    procedure AddList(Source: TItemList);
  end;

procedure TItemList.DeleteDuplicates;

  function IndexOf(Item: TItem; StartIndex: Integer): Integer;
  begin
    for result := StartIndex to Count - 1 do
      if Item = Items[result] then exit;
    result := -1;
  end;

  { Set to @nil (never freeing) given item on TFPGObjectList. }
  procedure FPGObjectList_NilItem(List: TFPSList; I: Integer);
  begin
    { Do not set the list item by normal List.Items, as it will cause
      freeing the item, once http://bugs.freepascal.org/view.php?id=19854
      is fixed (it is fixed in FPC > 2.6.0). }
    PPointer(List.List)[I] := nil;
  end;

var
  I, Index: integer;
begin
  I := 0;
  while I < Count do
  begin
    Index := I + 1;
    repeat
      Index := IndexOf(Items[I], Index);
      if Index = -1 then Break;
      // even in case the list has FreeObjects, this needs to nil *without freeing*
      if FreeObjects then
        FPGObjectList_NilItem(Self, Index)
      else
        // we could use FPGObjectList_NilItem(Self, Index) here too,
        // but we can also make non-hacky assignment to nil.
        Items[Index] := nil;
      Delete(Index);
    until false;

    Inc(I);
  end;
end;

procedure TItemList.AddList(Source: TItemList);
var
  OldCount: Integer;
begin
  OldCount := Count;
  Count := Count + Source.Count;
  if Source.Count <> 0 then
    System.Move(Source.List^[0], List^[OldCount], SizeOf(Pointer) * Source.Count);
end;

procedure TTestObjectsList.TestObjectsList;
var ol, ol2: TItemList;
begin
 ol := TItemList.Create(false);
 try ol.Add(TItem.Create); ol[0].Str := 'foo'; ol[0].Free;
 finally ol.Free end;

 ol := TItemList.Create(false);
 try ol.Add(TItem($454545)); ol.Delete(0);
 finally ol.Free end;

 ol := TItemList.Create(true);
 try ol.Add(TItem.Create); ol.Clear;
 finally ol.Free end;

 ol := TItemList.Create(true);
 try ol.Add(nil); ol.Clear;
 finally ol.Free end;

 ol := TItemList.Create(true);
 try
  ol.Add(TItem.Create); ol.Last.Str := 'first item';

  ol2 := TItemList.Create(false);
  try
   ol2.Add(TItem.Create); ol2.Last.Str := 'one';
   ol2.Add(TItem.Create); ol2.Last.Str := 'two';
   ol.AddList(ol2);
  finally ol2.Free end;
  ol.Clear;
 finally ol.Free end;

 ol := TItemList.Create(true);
 try
  ol.Add(TItem.Create); ol.Last.Str := 'first item';

  ol2 := TItemList.Create(false);
  try
   ol2.Add(TItem.Create); ol2.Last.Str := 'one';
   ol2.Add(TItem.Create); ol2.Last.Str := 'two';
   ol.AddList(ol2);
   ol.AddList(ol2);
  finally ol2.Free end;

  AssertTrue(ol.Count = 5);
  AssertTrue(ol[0].Str = 'first item');
  AssertTrue(ol[1].Str = 'one');
  AssertTrue(ol[2].Str = 'two');
  AssertTrue(ol[3].Str = 'one');
  AssertTrue(ol[4].Str = 'two');

  AssertTrue(ol[1] = ol[3]); { (1 i 3) i (2 i 4) to te same obiekty. }
  AssertTrue(ol[2] = ol[4]);

  { delete dups, preventing Clear from Freeing two times the same reference }
  ol.DeleteDuplicates;
  ol.Clear;
 finally ol.Free end;
end;

initialization
 RegisterTest(TTestObjectsList);
end.
