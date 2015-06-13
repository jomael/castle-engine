program generate_x3d_nodes_to_pascal;

uses SysUtils, CastleParameters, CastleClassUtils, CastleStringUtils,
  CastleTimeUtils, CastleWarnings, CastleColors, CastleUtils;

function FieldTypeX3DToPascal(const X3DName: string): string;
begin
  if X3DName = 'SFFloat' then
    Result := 'Single' else
  if X3DName = 'SFDouble' then
    Result := 'Double' else
  if X3DName = 'SFTime' then
    Result := 'TFloatTime' else
  if X3DName = 'SFVec2f' then
    Result := 'TVector2Single' else
  if X3DName = 'SFVec3f' then
    Result := 'TVector3Single' else
  if X3DName = 'SFVec4f' then
    Result := 'TVector4Single' else
  if X3DName = 'SFVec2d' then
    Result := 'TVector2Double' else
  if X3DName = 'SFVec3d' then
    Result := 'TVector3Double' else
  if X3DName = 'SFVec4d' then
    Result := 'TVector4Double' else
  if X3DName = 'SFInt32' then
    Result := 'Integer' else
  if X3DName = 'SFBool' then
    Result := 'boolean' else
  if X3DName = 'SFRotation' then
    Result := 'TVector4Single' else
  if X3DName = 'SFColor' then
    Result := 'TCastleColorRGB' else
  if X3DName = 'SFColorRGBA' then
    Result := 'TCastleColor' else
  // Note that many SFString are enums, and they should be converted to enums
  // in ObjectPascal. We capture enums outside of this function.
  if X3DName = 'SFString' then
    Result := 'string' else
//  if X3DName = 'SFNode' then // nope, because these should be typed accordingly in ObjectPascal
//    Result := 'TXxx' else
    Result := '';
end;

function FieldLooksLikeEnum(const Line: string; const Tokens: TCastleStringList): boolean;
var
  X3DFieldType{, X3DFieldName}: string;
begin
  X3DFieldType := Tokens[0];
  //X3DFieldName := Tokens[2];
  Result :=
    (X3DFieldType = 'SFString') and
    (Pos('["', Line) <> 0) and
   ((Pos('"]', Line) <> 0) or (Pos('...]', Line) <> 0));
  if Result then
    OnWarning(wtMinor, 'Input', 'Detected as enum, not converting ' + Line);
end;

function NodeTypeX3DToPascal(const X3DName: string): string;
begin
  Result := X3DName;
  if IsPrefix('X3D', X3DName) then
  begin
    { On X3DViewpointNode, we have both
      TAbstractX3DViewpointNode and TAbstractViewpointNode,
      to support also older VRML versions. Similar for grouping. }
    if (X3DName <> 'X3DViewpointNode') and
       (X3DName <> 'X3DGroupingNode') then
      Result := PrefixRemove('X3D', Result, true);
    Result := 'Abstract' + Result;
  end;
  Result := SuffixRemove('Node', Result, true);
  Result := 'T' + Result + 'Node';
end;

var
  NodePrivateInterface, NodePublicInterface, NodeImplementation,
    OutputInterface, OutputImplementation: string;

procedure ProcessFile(const InputFileName: string);
var
  F: TTextReader;
  PosComment: Integer;
  Tokens: TCastleStringList;
  Line, LineWithComment, X3DNodeType, X3DAncestorType1, X3DAncestorType2, PascalNodeType,
    X3DFieldName, PascalFieldName, X3DFieldType, PascalFieldType,
    PascalFieldNameOriginal: string;
begin
  F := TTextReader.Create(InputFileName);
  try
    while not F.Eof do
    begin
      LineWithComment := F.Readln;
      Line := LineWithComment;
      { remove comments }
      PosComment := Pos('#', Line);
      if PosComment <> 0 then
        SetLength(Line, PosComment - 1);
      { avoid empty lines (after comment removal) }
      if Trim(Line) <> '' then
      begin
        Tokens := CreateTokens(Line);
        try
          if (Tokens.Count = 2) and
             (Tokens[1] = '{') then
          begin
            X3DNodeType := Tokens[0];
            PascalNodeType := NodeTypeX3DToPascal(X3DNodeType);
            X3DAncestorType1 := '';
            X3DAncestorType2 := '';
            // Writeln('// Node begin: ', PascalNodeType, ' ', X3DAncestorType1);
          end else
          if (Tokens.Count = 4) and
             (Tokens[1] = ':') and
             (Tokens[3] = '{') then
          begin
            X3DNodeType := Tokens[0];
            PascalNodeType := NodeTypeX3DToPascal(X3DNodeType);
            X3DAncestorType1 := Tokens[2];
            X3DAncestorType2 := '';
            // Writeln('// Node begin: ', PascalNodeType, ' ', X3DAncestorType1);
          end else
          if (Tokens.Count = 5) and
             (Tokens[1] = ':') and
             (Tokens[4] = '{') then
          begin
            X3DNodeType := Tokens[0];
            PascalNodeType := NodeTypeX3DToPascal(X3DNodeType);
            X3DAncestorType1 := Tokens[2]; // TODO: remove comma
            X3DAncestorType2 := Tokens[3];
            // Writeln('// Node begin: ', PascalNodeType, ' ', X3DAncestorType1, ' ', X3DAncestorType2);
          end else
          if (Tokens.Count = 1) and
             (Tokens[0] = '}') then
           begin
             if (NodePrivateInterface <> '') or
                (NodePublicInterface <> '') or
                (NodeImplementation <> '') then
             begin
               OutputInterface +=
                 '  ' + PascalNodeType + 'Helper = class helper for ' + PascalNodeType + NL +
                 '  private' + NL +
                 NodePrivateInterface +
                 '  public' + NL +
                 NodePublicInterface +
                 '  end;' + NL +
                 NL;
               OutputImplementation +=
                 '{ ' + PascalNodeType + ' ----------------------------------------------- }' + NL +
                 NL +
                 NodeImplementation;
             end;

             X3DNodeType := '';
             X3DAncestorType1 := '';
             X3DAncestorType2 := '';
             NodePrivateInterface := '';
             NodePublicInterface := '';
             NodeImplementation := '';
           end else
           if (Tokens.Count >= 3) and
              (FieldTypeX3DToPascal(Tokens[0]) <> '') then
           begin
             if FieldLooksLikeEnum(LineWithComment, Tokens) then
               Continue;
             X3DFieldName := Tokens[2];
             if (X3DFieldName = 'ccw') or
                (X3DFieldName = 'solid') or
                (X3DFieldName = 'repeatS') or
                (X3DFieldName = 'repeatT') then
             begin
               Writeln(ErrOutput, 'NOTE: Not processing, this field has special implementation: ' + X3DFieldName);
               Continue;
             end;
             if (X3DNodeType = 'X3DMetadataObject') or
                (X3DNodeType = 'X3DFogObject') or
                (X3DNodeType = 'X3DPickableObject') or
                (X3DNodeType = 'GravityPhysicsModel' { TODO: this one is just missing in X3DNodes }) then
             begin
               Writeln(ErrOutput, 'NOTE: Not processing, this node has special implementation: ' + X3DNodeType);
               Continue;
             end;
             PascalFieldName := X3DFieldName;
             if PascalFieldName = 'on' then
               PascalFieldName := 'IsOn';
             PascalFieldName[1] := UpCase(PascalFieldName[1]);
             PascalFieldNameOriginal := X3DFieldName;
             PascalFieldNameOriginal[1] := UpCase(PascalFieldNameOriginal[1]);
             PascalFieldNameOriginal := 'Fd' + PascalFieldNameOriginal;
             X3DFieldType := Tokens[0];
             PascalFieldType := FieldTypeX3DToPascal(X3DFieldType);
             if (Tokens[1] <> '[in,out]') and
                (Tokens[1] <> '[]') then
             begin
               OnWarning(wtMinor, 'Input', 'Only fields (inputOutput or initializeOnly) are supported now: ' + X3DFieldName);
               Continue;
             end;
             if X3DNodeType = '' then
             begin
               OnWarning(wtMajor, 'Input', 'Field found, but not inside a node: ' + X3DFieldName);
               Continue;
             end;
             NodePrivateInterface +=
               '    function Get' + PascalFieldName + ': ' + PascalFieldType + ';' + NL +
               '    procedure Set' + PascalFieldName + '(const Value: ' + PascalFieldType + ');' + NL;
             NodePublicInterface +=
               '    property ' + PascalFieldName + ': ' + PascalFieldType + ' read Get' + PascalFieldName + ' write Set' + PascalFieldName + ';' + NL;
             NodeImplementation +=
               'function ' + PascalNodeType + 'Helper.Get' + PascalFieldName + ': ' + PascalFieldType + ';' + NL +
               'begin' + NL +
               '  Result := ' + PascalFieldNameOriginal + '.Value;' + NL +
               'end;' + NL +
               NL +
               'procedure ' + PascalNodeType + 'Helper.Set' + PascalFieldName + '(const Value: ' + PascalFieldType + ');' + NL +
               'begin' + NL +
               '  ' + PascalFieldNameOriginal + '.Send(Value);' + NL +
               'end;' + NL +
               NL;
           end else
           begin
             OnWarning(wtMajor, 'Input', 'Line not understood, possibly field type not handled: ' + Line);
             Continue;
           end;
        finally FreeAndNil(Tokens) end;
      end;
    end;
  finally FreeAndNil(F) end;
end;

var
  I: Integer;
begin
  OnWarning := @OnWarningWrite;

  NodePrivateInterface := '';
  NodePublicInterface := '';
  NodeImplementation := '';
  OutputInterface := '';
  OutputImplementation := '';

  Parameters.CheckHighAtLeast(1);
  for I := 1 to Parameters.High do
    ProcessFile(Parameters[I]);

  Write(
    '{ -*- buffer-read-only: t -*-' + NL +
    '' + NL +
    '  Copyright 2015-2015 Michalis Kamburelis.' + NL +
    '' + NL +
    '  This file is part of "Castle Game Engine".' + NL +
    '' + NL +
    '  "Castle Game Engine" is free software; see the file COPYING.txt,' + NL +
    '  included in this distribution, for details about the copyright.' + NL +
    '' + NL +
    '  "Castle Game Engine" is distributed in the hope that it will be useful,' + NL +
    '  but WITHOUT ANY WARRANTY; without even the implied warranty of' + NL +
    '  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.' + NL +
    '' + NL +
    '  ----------------------------------------------------------------------------' + NL +
    '}' + NL +
    '' + NL +
    '{ Automatically generated X3D node class helpers.' + NL +
    '  Do not edit manually, instead regenerate using' + NL +
    '  castle_game_engine/src/x3d/doc/generate_x3d_nodes_to_pascal.lpr . }' + NL +
    '' + NL +
    '{$ifdef read_interface}' + NL +
    NL +
    'type' + NL +
    OutputInterface +
    '{$endif read_interface}' + NL +
    '' + NL +
    '{$ifdef read_implementation}' + NL +
    NL +
    OutputImplementation +
    '{$endif read_implementation}' + NL
  );
end.
