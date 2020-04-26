{
  Copyright 2003-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Shape class for OpenGL rendering.
  @exclude Internal unit for CastleScene. }
unit CastleSceneInternalShape;

{$I castleconf.inc}

interface

uses X3DNodes, X3DFields, CastleImages,
  {$ifdef CASTLE_OBJFPC} CastleGL, {$else} GL, GLExt, {$endif}
  CastleRenderer;

type
  { Shape within a scene rendered using OpenGL.
    This is TShape extended with some information needed by TCastleScene.
    Non-internal units never expose instances of this class. }
  TGLShape = class abstract(TX3DRendererShape)
  public
    { Keeps track if this shape was passed to Renderer.Prepare. }
    PreparedForRenderer: boolean;

    UseAlphaChannel: TAlphaChannel;
    { Is UseAlphaChannel calculated and current. }
    PreparedUseAlphaChannel: boolean;

    PassedShapeCulling: Boolean;

    { Used only when Attributes.ReallyUseOcclusionQuery.
      OcclusionQueryId is 0 if not initialized yet.
      When it's 0, value of OcclusionQueryAsked doesn't matter,
      OcclusionQueryAsked is always reset to @false when initializing
      OcclusionQueryId. }
    OcclusionQueryId: TGLint;
    OcclusionQueryAsked: boolean;

    { For Hierarchical Occlusion Culling. }
    RenderedFrameId: Cardinal;

    { Do not share the cache of this shape with other shapes.
      Offers tiny optimization when you know that this shape cannot be shared anyway.
      Never change it after initial render. }
    DisableSharedCache: Boolean;

    procedure Changed(const InactiveOnly: boolean;
      const Changes: TX3DChanges); override;
    procedure PrepareResources;
    procedure GLContextClose;

    { Access the Renderer of parent TCastleScene. }
    function Renderer: TGLRenderer; virtual; abstract;

    { Request from parent TCastleScene to call our PrepareResources at next time. }
    procedure SchedulePrepareResources; virtual; abstract;

    function UseBlending: Boolean;
  end;

implementation

uses CastleScene, CastleVectors;

{ TGLShape --------------------------------------------------------------- }

procedure TGLShape.Changed(const InactiveOnly: boolean;
  const Changes: TX3DChanges);

  { Assuming Cache <> nil, try to update the Cache VBOs fast
    (without the need to recreate them).

    This detects now for changes limited to coordinate/normal,
    and tries using FastCoordinateNormalUpdate. }
  function FastCacheUpdate: Boolean;
  var
    Coords, Normals: TVector3List;
  begin
    Result := false;

    if { We only changed Cooordinate.coord or Normal.vector. }
       (Changes * [chCoordinate, chVisibleVRML1State] = Changes) and
       { Shape has coordinates and normals exposed in most common way,
         by Coordinate and Normal nodes. }
       (Geometry.CoordField <> nil) and
       (Geometry.CoordField.Value <> nil) and
       (Geometry.CoordField.Value is TCoordinateNode) and
       (Geometry.NormalField <> nil) and
       (Geometry.NormalField.Value <> nil) and
       (Geometry.NormalField.Value is TNormalNode) then
    begin
      Coords := TCoordinateNode(Geometry.CoordField.Value).FdPoint.Items;
      Normals := TNormalNode(Geometry.NormalField.Value).FdVector.Items;
      Result := Cache.FastCoordinateNormalUpdate(Coords, Normals);
    end;
  end;

begin
  inherited;

  if (Cache <> nil) and (not FastCacheUpdate) then
  begin
    { Ignore changes that don't affect prepared arrays,
      like transformation, clip planes and everything else that is applied
      by renderer every time, and doesn't affect TGeometryArrays. }
    if Changes * [chCoordinate] <> [] then
      Cache.FreeArrays([vtCoordinate]);
    { Note that Changes may contain both chCoordinate and chTextureCoordinate
      (e.g. in case of batching)
      in which case both "if" clauses should be entered. }
    if Changes * [chVisibleVRML1State, chGeometryVRML1State,
      chColorNode, chTextureCoordinate, chGeometry, chFontStyle, chWireframe] <> [] then
      Cache.FreeArrays(AllVboTypes);
  end;

  if Changes * [chTextureImage, chTextureRendererProperties] <> [] then
  begin
    Renderer.UnprepareTexture(State.MainTexture);
    PreparedForRenderer := false;
    PreparedUseAlphaChannel := false;
    SchedulePrepareResources;
  end;

  { When Material.transparency changes, recalculate UseAlphaChannel. }
  if chAlphaChannel in Changes then
  begin
    PreparedUseAlphaChannel := false;
    SchedulePrepareResources;
  end;
end;

procedure TGLShape.PrepareResources;
begin
  if not PreparedForRenderer then
  begin
    Renderer.Prepare(Self);
    PreparedForRenderer := true;
  end;

  if not PreparedUseAlphaChannel then
  begin
    { UseAlphaChannel is used by RenderScene to decide is Blending used for given
      shape. }
    UseAlphaChannel := AlphaChannel;
    PreparedUseAlphaChannel := true;
  end;

  {$ifndef OpenGLES}
  if TCastleScene(ParentScene).Attributes.ReallyUseOcclusionQuery and
     (OcclusionQueryId = 0) then
  begin
    glGenQueriesARB(1, @OcclusionQueryId);
    OcclusionQueryAsked := false;
  end;
  {$endif}
end;

procedure TGLShape.GLContextClose;
var
  Pass: TTotalRenderingPass;
begin
  PreparedForRenderer := false;
  PreparedUseAlphaChannel := false;

  {$ifndef OpenGLES}
  if OcclusionQueryId <> 0 then
  begin
    glDeleteQueriesARB(1, @OcclusionQueryId);
    OcclusionQueryId := 0;
  end;
  {$endif}

  { Free Arrays and Vbo of all shapes. }
  if Cache <> nil then
    Renderer.Cache.Shape_DecReference(Self, Cache);
  for Pass := Low(Pass) to High(Pass) do
    if ProgramCache[Pass] <> nil then
      Renderer.Cache.Program_DecReference(ProgramCache[Pass]);
end;

function TGLShape.UseBlending: Boolean;
begin
  Result := UseAlphaChannel = acBlending;
end;

end.
