{
  Copyright 2019-2019 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Batch shapes (combine multiple shapes into one) (TBatchShapes). }
unit CastleInternalBatchShapes;

{$I castleconf.inc}

interface

uses CastleSceneInternalShape, CastleShapes, X3DNodes, X3DFields;

type
  TCreateShapeEvent = function(const AGeometry: TAbstractGeometryNode;
    const AState: TX3DGraphTraverseState;
    const ParentInfo: PTraversingInfo): TShape of object;

  TBatchShapes = class
  strict private
    const
      { In each TMergePipeline we have a few slots,
        to account for different values of things that must match for all
        merged shapes. E.g. Material.EmissiveColor in slot 0 may be white,
        in slot 1 Material.EmissiveColor may be blue.

        We need more than 1 slot, otherwise dynamic batching could be easily
        made worthless if one shape would be e.g. blue, and then 100 others would
        be white.

        But we also cannot have too many slots,
        or the time spent in "finding the right slot to merge"
        (FindMergeable in implementation, only for PreserveShapeOrder=false)
        will grow. }
      MergeSlots = 8;
    type
      { Shapes from different pipelines cannot be merged with each other,
        and the pool shapes (in FPool) may be prepared differently for each
        TMergePipeline.
        E.g. pool shapes for mpTexCoord has TexCoord assigned,
        for mpNoTexCoord they have TexCoord=nil. }
      TMergePipeline = (mpNoTexCoord, mpTexCoord);
      TMergeSlot = 0 .. MergeSlots - 1;
      TMergingShapes = array [TMergePipeline, TMergeSlot] of TGLShape;
    var
      FCollected: TShapeList;
      FPool: TMergingShapes;
      FPoolUsed: array [TMergePipeline] of Integer;

      { FMergeTarget are copies of the respective shapes on FPool list,
        when they first become used by Merge (not only allocated by AllocateSlot). }
      FMergeTarget: TMergingShapes;

      { When PreserveShapeOrder=false, we use this. }
      FUnorderedPreviousShapes: TMergingShapes;

      { When PreserveShapeOrder=true, we use this. }
      FOrderPreviousShape: TGLShape;
      FOrderPreviousShapeMerging: Boolean;
      FOrderPreviousShapePipeline: TMergePipeline;

      FPoolGeometries: TGroupNode;
      LogIncreaseSlotsDone: Boolean;

    { Add Source into Target.
      You can assume that Target is one of our pool shapes,
      with initial state and geometry calculated by InitializePool. }
    procedure Merge(const Target, Source: TGLShape;
      const P: TMergePipeline; const FirstMerge: Boolean);

    { Clear any possible leftovers from Merge, where a given shape was Target. }
    procedure ClearMerge(const Target: TGLShape;
      const P: TMergePipeline);

    { Similar to TAbstractGeometryNode.InternalCoordinates, but for tex coords. }
    class function TexCoordinates(
      const Geometry: TAbstractGeometryNode;
      const State: TX3DGraphTraverseState): TMFVec2f;

    procedure DoLogIncreaseSlots;
    function GetPoolShapes(const Index: Integer): TGLShape;
  public
    var
      { Make sure that shapes on the @link(Collected) list have the same order
        as they are passed on @link(Collect) method.
        This makes batching less aggressive (so less effective,
        less chance of merging many shapes into few),
        but it makes sure that rendering output will be the same,
        if the order was important (e.g. you were rendering
        without Z-buffer test).

        Reset to @false in each @link(FreeCollected). }
      PreserveShapeOrder: Boolean;

    constructor Create(const CreateShape: TCreateShapeEvent);
    destructor Destroy; override;

    { Merge given shape into the @link(Collected) shapes.
      During this, the shape may merge with another shape into a single, larger
      shape. Returns @true if the shape was added to @link(Collected),
      otherwise it was not, and should be rendered by the caller immediately
      without the help of batching. }
    function Collect(const Shape: TGLShape): Boolean;

    procedure Commit;

    { Currently collected shapes by @link(Collect).
      Call @link(Commit) before reading this. }
    property Collected: TShapeList read FCollected;

    { Release all shapes and clear the @link(Collected) list. }
    procedure FreeCollected;

    procedure GLContextClose;

    { Enumerate "pool" shapes.
      This is useful to prepare them (e.g. in TCastleScene.PrepareResources),
      to make sure further usage of them will be fast. }
    property PoolShapes[const Index: Integer]: TGLShape read GetPoolShapes;
    function PoolShapesCount: Integer;
  end;

implementation

uses SysUtils,
  CastleUtils, CastleLog, CastleVectors;

{.$define CASTLE_DEBUG_BATCHING}

constructor TBatchShapes.Create(const CreateShape: TCreateShapeEvent);

  function MergePipelineToStr(const P: TBatchShapes.TMergePipeline): String;
  begin
    WriteStr(Result, P);
  end;

  procedure InitializePool;
  var
    ShapeNode: TShapeNode;
    Geometry: TIndexedFaceSetNode;
    State: TX3DGraphTraverseState;
    ParentInfo: TTraversingInfo;
    Shape: TGLShape;
    P: TMergePipeline;
    Slot: TMergeSlot;
  begin
    for P in TMergePipeline do
      for Slot in TMergeSlot do
      begin
        // initialize Geometry and ShapeNode
        Geometry := TIndexedFaceSetNode.CreateWithShape(ShapeNode);
        Geometry.Coord := TCoordinateNode.Create;
        if P = mpTexCoord then
          Geometry.TexCoord := TTextureCoordinateNode.Create;
        FPoolGeometries.AddChildren(ShapeNode);

        // initialize State
        State := TX3DGraphTraverseState.Create;
        State.ShapeNode := ShapeNode;

        // initialize ParentInfo
        ParentInfo.Node := ShapeNode;
        ParentInfo.ParentInfo := nil;

        // initialize Shape, add it to FPool
        Shape := CreateShape(Geometry, State, @ParentInfo) as TGLShape;
        Shape.DisableSharedCache := true;
        FPool[P, Slot] := Shape;

        {$ifdef CASTLE_DEBUG_BATCHING}
        Shape.Node.X3DName := 'Batched_' + MergePipelineToStr(P) + '_' + IntToStr(Slot);
        {$endif}
      end;
  end;

begin
  inherited Create;

  FCollected := TShapeList.Create;
  FCollected.OwnsObjects := false;

  FPoolGeometries := TGroupNode.Create;

  InitializePool;
end;

destructor TBatchShapes.Destroy;
var
  P: TMergePipeline;
  Slot: TMergeSlot;
begin
  { In case our GLContextClose was not called yet, but we are destroyed,
    make sure to remove our pool shapes from cache. }
  GLContextClose;

  FreeAndNil(FCollected);
  for P in TMergePipeline do
    for Slot in TMergeSlot do
      FreeAndNil(FPool[P, Slot]);
  FreeAndNil(FPoolGeometries);
  inherited;
end;

procedure TBatchShapes.DoLogIncreaseSlots;
begin
  if not LogIncreaseSlotsDone then
  begin
    LogIncreaseSlotsDone := true;
    WritelnLog('Consider increasing MergeSlots, to allow more batching');
  end;
end;

function TBatchShapes.Collect(const Shape: TGLShape): Boolean;

  { Is this Shape suitable to consider for merging with @italic(anything).
    If yes, then we also determine the proper TMergePipeline. }
  function MergeableWithAnything(const Shape: TGLShape;
    out P: TMergePipeline): Boolean;
  var
    Geometry: TAbstractGeometryNode;
    TexCoord: TAbstractTextureCoordinateNode;
    FaceSet: TIndexedFaceSetNode;
  begin
    Result := false;

    // We can only Merge geometries from VRML 2 / X3D (with TShapeNode set)
    if Shape.Node = nil then
      Exit;

    // We can only Merge TIndexedFaceSetNode for now
    Geometry := Shape.Geometry(true);
    if not (Geometry is TIndexedFaceSetNode) then
      Exit;

    FaceSet := TIndexedFaceSetNode(Geometry);

    if (FaceSet.FdTexCoordIndex.Count <> 0) or // for now we don't handle texCoordIndex
       (FaceSet.FdColorIndex.Count <> 0) or
       (FaceSet.FdNormalIndex.Count <> 0) or
       {$ifndef CASTLE_SLIM_NODES}
       (FaceSet.FdAttrib.Count <> 0) or
       (FaceSet.FdFogCoord.Value <> nil) or
       {$endif}
       (FaceSet.FdColor.Value <> nil) or
       (FaceSet.FdNormal.Value <> nil) then
      Exit;

    TexCoord := FaceSet.TexCoord;
    if TexCoord = nil then
    begin
      P := mpNoTexCoord;
      Result := true;
    end else
    if TexCoord is TTextureCoordinateNode then
    begin
      Result := true;
      P := mpTexCoord;
    end;
  end;

  { Can two given shapes be merged.
    Assumes that both shapes already passed MergeableWithAnything test,
    and have the same TMergePipeline. }
  function Mergeable(const Shape1, Shape2: TGLShape;
    const P: TMergePipeline): Boolean;

    function IndexedFaceSetMatch(const I1, I2: TIndexedFaceSetNode): Boolean;
    begin
      Result :=
        (I1 = I2) or
        (
          (I1.FdNormalPerVertex.Value = I2.FdNormalPerVertex.Value) and
          (I1.FdSolid          .Value = I2.FdSolid          .Value) and
          (I1.FdConvex         .Value = I2.FdConvex         .Value) and
          (I1.FdCcw            .Value = I2.FdCcw            .Value) and
          (I1.FdCreaseAngle    .Value = I2.FdCreaseAngle    .Value)
        );
    end;

    function MaterialTexturesEqual(const Texture1, Texture2: TX3DNode;
      const Texture1Channel, Texture2Channel: Integer): Boolean;
    begin
      Result := (Texture1 = Texture2) and (Texture1Channel = Texture2Channel);
    end;

    { Checks contents of M1 and M2,
      assuming that they are both <> nil and different references
      (so there's no point in checking their references). }
    function PhongMaterialsContentsMatch(const M1, M2: TMaterialNode): Boolean;
    begin
      Result :=
        (
          TVector3.PerfectlyEquals(M1.FdDiffuseColor    .Value, M2.FdDiffuseColor    .Value) and
          TVector3.PerfectlyEquals(M1.FdSpecularColor   .Value, M2.FdSpecularColor   .Value) and
          TVector3.PerfectlyEquals(M1.FdEmissiveColor   .Value, M2.FdEmissiveColor   .Value) and
          (M1.FdAmbientIntensity.Value = M2.FdAmbientIntensity.Value) and
          (M1.FdTransparency    .Value = M2.FdTransparency    .Value) and

          MaterialTexturesEqual(M1.FdNormalTexture  .Value, M2.FdNormalTexture  .Value, M1.FdNormalTextureChannel  .Value, M2.FdNormalTextureChannel  .Value) and
          MaterialTexturesEqual(M1.FdDiffuseTexture .Value, M2.FdDiffuseTexture .Value, M1.FdDiffuseTextureChannel .Value, M2.FdDiffuseTextureChannel .Value) and
          MaterialTexturesEqual(M1.FdSpecularTexture.Value, M2.FdSpecularTexture.Value, M1.FdSpecularTextureChannel.Value, M2.FdSpecularTextureChannel.Value) and
          MaterialTexturesEqual(M1.FdEmissiveTexture.Value, M2.FdEmissiveTexture.Value, M1.FdEmissiveTextureChannel.Value, M2.FdEmissiveTextureChannel.Value) and
          MaterialTexturesEqual(M1.FdAmbientTexture .Value, M2.FdAmbientTexture .Value, M1.FdAmbientTextureChannel .Value, M2.FdAmbientTextureChannel .Value)
        );
    end;

    function UnlitMaterialsContentsMatch(const M1, M2: TUnlitMaterialNode): Boolean;
    begin
      Result :=
        (
          TVector3.PerfectlyEquals(M1.FdEmissiveColor   .Value, M2.FdEmissiveColor   .Value) and
          (M1.FdTransparency    .Value = M2.FdTransparency    .Value) and

          // ignored: MaterialTexturesEqual(M1.FdNormalTexture  .Value, M2.FdNormalTexture  .Value, M1.FdNormalTextureChannel  .Value, M2.FdNormalTextureChannel  .Value) and
          MaterialTexturesEqual(M1.FdEmissiveTexture.Value, M2.FdEmissiveTexture.Value, M1.FdEmissiveTextureChannel.Value, M2.FdEmissiveTextureChannel.Value)
        );
    end;

    function PhysicalMaterialsContentsMatch(const M1, M2: TPhysicalMaterialNode): Boolean;
    begin
      Result :=
        (
          TVector3.PerfectlyEquals(M1.FdEmissiveColor   .Value, M2.FdEmissiveColor   .Value) and
          TVector3.PerfectlyEquals(M1.FdBaseColor       .Value, M2.FdBaseColor       .Value) and
          (M1.FdMetallic    .Value = M2.FdMetallic    .Value) and
          (M1.FdRoughness   .Value = M2.FdRoughness   .Value) and
          (M1.FdTransparency.Value = M2.FdTransparency.Value) and

          MaterialTexturesEqual(M1.FdNormalTexture           .Value, M2.FdNormalTexture           .Value, M1.FdNormalTextureChannel           .Value, M2.FdNormalTextureChannel           .Value) and
          MaterialTexturesEqual(M1.FdEmissiveTexture         .Value, M2.FdEmissiveTexture         .Value, M1.FdEmissiveTextureChannel         .Value, M2.FdEmissiveTextureChannel         .Value) and
          MaterialTexturesEqual(M1.FdBaseTexture             .Value, M2.FdBaseTexture             .Value, M1.FdBaseTextureChannel             .Value, M2.FdBaseTextureChannel             .Value) and
          MaterialTexturesEqual(M1.FdMetallicRoughnessTexture.Value, M2.FdMetallicRoughnessTexture.Value, M1.FdMetallicRoughnessTextureChannel.Value, M2.FdMetallicRoughnessTextureChannel.Value)
        );
    end;

    function AbstractMaterialsMatch(const M1, M2: TAbstractMaterialNode): Boolean;
    begin
      Result :=
        (M1 = M2) or
        (
          (M1 is TMaterialNode) and
          (M2 is TMaterialNode) and
          PhongMaterialsContentsMatch(TMaterialNode(M1), TMaterialNode(M2))
        ) or
        (
          (M1 is TUnlitMaterialNode) and
          (M2 is TUnlitMaterialNode) and
          UnlitMaterialsContentsMatch(TUnlitMaterialNode(M1), TUnlitMaterialNode(M2))
        ) or
        (
          (M1 is TPhysicalMaterialNode) and
          (M2 is TPhysicalMaterialNode) and
          PhysicalMaterialsContentsMatch(TPhysicalMaterialNode(M1), TPhysicalMaterialNode(M2))
        );
    end;

    function AppearancesMatch(const A1, A2: TAppearanceNode): Boolean;
    begin
      Result :=
        (A1 = A2) or
        (
          (A1 <> nil) and
          (A2 <> nil) and
          (A1.FdTexture.Value          = A2.FdTexture         .Value) and
          (A1.FdTextureTransform.Value = A2.FdTextureTransform.Value) and
          AbstractMaterialsMatch(A1.Material, A2.Material)
        );
    end;

    function LightsMatch(const Lights1, Lights2: TLightInstancesList): Boolean;
    begin
      Result :=
        (Lights1 = Lights2) or
        (
          (Lights1 <> nil) and
          (Lights2 <> nil) and
          Lights1.Equals(Lights2)
        );
    end;

  var
    Mesh1, Mesh2: TIndexedFaceSetNode;
    State1, State2: TX3DGraphTraverseState;
  begin
    Mesh1 := TIndexedFaceSetNode(Shape1.Geometry(true));
    Mesh2 := TIndexedFaceSetNode(Shape2.Geometry(true));
    State1 := Shape1.State(true);
    State2 := Shape2.State(true);
    Result :=
      { Checks begin from the ones most likely to be different (exit early).
        Note that everything compared here must be also assigned in Merge
        (when FirstMerge), to make sure all merged instances keep the same values
        for this stuff. }
      AppearancesMatch(Shape1.Node.Appearance, Shape2.Node.Appearance) and
      IndexedFaceSetMatch(Mesh1, Mesh2) and
      (State1.LocalFog = State2.LocalFog) and
      (Shape1.Node.Shading = Shape2.Node.Shading) and
      LightsMatch(State1.Lights, State2.Lights) and
      (State1.ClipPlanes = State2.ClipPlanes) and
      (State1.Effects = State2.Effects);
  end;

  { Find a slot in Shapes[P] which is non-nil and can be merged with Shape.
    Assumes that for Shape, we already determined given TMergePipeline. }
  function FindMergeable(const Shapes: TMergingShapes;
    const P: TMergePipeline; const Shape: TGLShape;
    out MergeSlot: TMergeSlot): Boolean;
  begin
    for MergeSlot in TMergeSlot do
      if Shapes[P, MergeSlot] <> nil then
        if Mergeable(Shape, Shapes[P, MergeSlot], P) then
          Exit(true);
    Result := false;
  end;

  { First merge of two shapes.
    Sets FMergeTarget[P, Slot] (using FPool[P, Slot]),
    adds it to FCollected,
    places there merge of Shape1 and Shape2.

    Called must first check that FPool[P, Slot] was not used for anything
    (e.g. by checking that FMergeTarget[P, Slot] is nil). }
  procedure InitialMerge(const Shape1, Shape2: TGLShape;
    const P: TMergePipeline; const Slot: TMergeSlot);
  begin
    {$ifdef CASTLE_DEBUG_BATCHING}
    if FMergeTarget[P, Slot] <> nil then
      WritelnWarning('Batching: merging to already used slot');
    {$endif}
    FMergeTarget[P, Slot] := FPool[P, Slot];
    FCollected.Add(FMergeTarget[P, Slot]);
    ClearMerge(FMergeTarget[P, Slot], P);
    Merge(FMergeTarget[P, Slot], Shape1, P, true);
    Merge(FMergeTarget[P, Slot], Shape2, P, false);
  end;

  function AllocateSlot(const P: TMergePipeline; out Slot: TMergeSlot): Boolean;
  begin
    Result := FPoolUsed[P] < MergeSlots;
    if Result then
    begin
      Slot := FPoolUsed[P];
      Inc(FPoolUsed[P]);
    end;
  end;

  { Algorithm specific for PreserveShapeOrder=true case. }
  procedure DoPreserveShapeOrder;
  var
    P: TMergePipeline;
    Handled: Boolean;
    Slot: TMergeSlot;
  begin
    Handled := false;

    { When PreserveShapeOrder, the algorithm is simpler:
      We try to merge an incoming shape with the previous shape
      (taking into account that a previous shape may be already a result
      of merging, depending on FOrderPreviousShapeMerging).
      If this is not possible, we just push previous shape to FCollected. }

    { In case of DoPreserveShapeOrder, Collect must *always* return true,
      even for non-mergeable shapes. }
    Result := true;

    if not MergeableWithAnything(Shape, P) then
    begin
      { The non-mergeable shapes have to be added
        to FCollected, to make sure they are in correct order between mergeable.
        Testcase: merging scene with indicator (IndexedFaceSet, Text and Rectangle2D) in Unholy. }
      // finish merging previous shape
      if (FOrderPreviousShape <> nil) and
         (not FOrderPreviousShapeMerging) then
        FCollected.Add(FOrderPreviousShape);
      FCollected.Add(Shape);
      FOrderPreviousShape := nil;
      FOrderPreviousShapeMerging := false;
      Handled := true;
    end else
    if (FOrderPreviousShape <> nil) and
       (FOrderPreviousShapePipeline = P) and
       Mergeable(FOrderPreviousShape, Shape, P) then
    begin
      if FOrderPreviousShapeMerging then
      begin
        Merge(FOrderPreviousShape, Shape, P, false);
        Handled := true;
      end else
      if AllocateSlot(P, Slot) then
      begin
        InitialMerge(FOrderPreviousShape, Shape, P, Slot);
        FOrderPreviousShape := FMergeTarget[P, Slot];
        FOrderPreviousShapeMerging := true;
        Handled := true;
      end else
        DoLogIncreaseSlots;
    end;

    if not Handled then
    begin
      // finish merging previous shape, and add new shape as FOrderPreviousShape
      if (FOrderPreviousShape <> nil) and
         (not FOrderPreviousShapeMerging) then
        FCollected.Add(FOrderPreviousShape);
      FOrderPreviousShape := Shape;
      FOrderPreviousShapePipeline := P;
      FOrderPreviousShapeMerging := false;
    end;
  end;

  { Algorithm specific for PreserveShapeOrder=false case. }
  procedure DoIgnoreShapeOrder;
  var
    P: TMergePipeline;
    Slot: TMergeSlot;
  begin
    Result := MergeableWithAnything(Shape, P);
    if not Result then
      Exit;

    { When not PreserveShapeOrder, we try to merge an incoming shape with
      - one of the merges "in progress" (on FUnorderedPreviousShapes and FMergeTarget)
      - or one of the previous shapes, not yet during merging (only on FUnorderedPreviousShapes)
      - or we place it in a new slot, waiting for possible merge in the future. }

    if FindMergeable(FUnorderedPreviousShapes, P, Shape, Slot) then
    begin
      if FMergeTarget[P, Slot] <> nil then
      begin
        { Slot in the middle of merging, so merge more. }
        Merge(FMergeTarget[P, Slot], Shape, P, false);
      end else
      begin
        { Slot not yet merging, so start merging.
          This will set FMergeTarget[P, Slot], so next shapes will know we are in the middle
          of merging. }
        InitialMerge(FUnorderedPreviousShapes[P, Slot], Shape, P, Slot);
        Assert(FMergeTarget[P, Slot] <> nil);
        FUnorderedPreviousShapes[P, Slot] := FMergeTarget[P, Slot];
      end;
    end else
    if AllocateSlot(P, Slot) then
    begin
      { Add shape to FUnorderedPreviousShapes.
        The corresponding FMergeTarget remains nil, so we know it is not yet in the middle of merging.

        Note that this reserves a slot, IOW we treat FPool[P, Slot] as already used.
        It may be wasteful (as we didn't start merging yet, we are not yet sure
        whether FPool[P, Slot] will be needed) but we need to reserve this pool for possible
        merging opportunity.

        TODO: Maybe the logic could be improved, to not reserve pool yet?
        Then our queue "waiting to be possibly merged" would not assign slots
        (corresponding to FPool and FMergeTarget slots).
        The advantage would be that we don't need so many MergeSlots
        in case of PreserveShapeOrder=false to be efficient, in some cases.
      }
      FUnorderedPreviousShapes[P, Slot] := Shape;
    end else
    begin
      DoLogIncreaseSlots;
      Result := false; // we would like to batch it, but MergeSlots is not enough
    end;
  end;

begin
  if PreserveShapeOrder then
    DoPreserveShapeOrder
  else
    DoIgnoreShapeOrder;
end;

procedure TBatchShapes.FreeCollected;
var
  P: TMergePipeline;
  Slot: TMergeSlot;
begin
  FCollected.Clear;
  for P in TMergePipeline do
  begin
    for Slot in TMergeSlot do
      if FMergeTarget[P, Slot] <> nil then
      begin
        // don't wait for ClearMerge for this, do this earlier to release reference count
        FMergeTarget[P, Slot].Node.FdAppearance.Value := nil;
        // make sure this is unassigned, otherwise TX3DGraphTraverseState.Destroy would free it
        FMergeTarget[P, Slot].State.Lights := nil;
        FMergeTarget[P, Slot] := nil;
      end;
    FPoolUsed[P] := 0;
  end;
  PreserveShapeOrder := false;
end;

procedure TBatchShapes.Commit;

  procedure DebugOutput;
  var
    Shape: TShape;
    RootNode: TX3DRootNode;
    Geometry: TAbstractGeometryNode;
  begin
    RootNode := TX3DRootNode.Create;
    for Shape in FCollected do
    begin
      Geometry := Shape.OriginalGeometry;
      WritelnLog('Collected shape: %s, geometry: %s, bbox: %s', [
        Shape.Node.X3DName,
        Geometry.NiceName,
        Shape.BoundingBox.ToString
      ]);
      Shape.Node.KeepExistingBegin;
      RootNode.AddChildren(Shape.Node);
    end;

    if RootNode.FdChildren.Count <> 0 then
      Save3D(RootNode, 'cge_batching_output.x3d', ApplicationName);

    for Shape in FCollected do
      Shape.Node.KeepExistingEnd;

    FreeAndNil(RootNode);
  end;

var
  P: TMergePipeline;
  Slot: TMergeSlot;
begin
  for P in TMergePipeline do
    for Slot in TMergeSlot do
    begin
      if FUnorderedPreviousShapes[P, Slot] <> nil then
      begin
        if FMergeTarget[P, Slot] = nil then
          FCollected.Add(FUnorderedPreviousShapes[P, Slot]);
        FUnorderedPreviousShapes[P, Slot] := nil;
      end;
      if FMergeTarget[P, Slot] <> nil then
      begin
        { Mark changes from
          - TIndexedFaceSetNode.FdCoordIndex,
          - TCoordinateNode.FdPoint
          - TTextureCoordinateNode.FdPoint
        }
        FMergeTarget[P, Slot].Changed(false, [chCoordinate, chTextureCoordinate, chGeometry]);
      end;
    end;

  if FOrderPreviousShape <> nil then
  begin
    if not FOrderPreviousShapeMerging then
      FCollected.Add(FOrderPreviousShape);
    FOrderPreviousShape := nil;
  end;

  {$ifdef CASTLE_DEBUG_BATCHING}
  DebugOutput;
  {$endif}
end;

procedure TBatchShapes.GLContextClose;
var
  P: TMergePipeline;
  Slot: TMergeSlot;
begin
  for P in TMergePipeline do
    for Slot in TMergeSlot do
      FPool[P, Slot].GLContextClose;
end;

procedure TBatchShapes.Merge(const Target, Source: TGLShape;
  const P: TMergePipeline; const FirstMerge: Boolean);
var
  StateTarget, StateSource: TX3DGraphTraverseState;
  MeshTarget, MeshSource: TIndexedFaceSetNode;
  CoordTarget, CoordSource: TMFVec3f;
  TexCoordTarget, TexCoordSource: TMFVec2f;
  IndexTarget, IndexSource: TLongIntList;
  OldCoordCount, I: Integer;
begin
  StateTarget := Target.State(true);
  StateSource := Source.State(true);
  MeshTarget := Target.Geometry(true) as TIndexedFaceSetNode;
  MeshSource := Source.Geometry(true) as TIndexedFaceSetNode;

  // no vertexes in source mesh, ignore it
  if MeshSource.Coord = nil then
    Exit;

  if FirstMerge then
  begin
    // assign things that should be equal when merging
    Assert(Source.Node <> nil); // only such source nodes are passed to Merge
    Target.Node.FdShading.Value := Source.Node.FdShading.Value;
    StateTarget.Lights := StateSource.Lights;
    StateTarget.LocalFog := StateSource.LocalFog;
    // using here FdAppearance.Value is marginally faster than Appearance, it matters a bit
    Target.Node.FdAppearance.Value := Source.Node.Appearance;
    MeshTarget.FdNormalPerVertex.Value := MeshSource.FdNormalPerVertex.Value;
    MeshTarget.FdSolid          .Value := MeshSource.FdSolid          .Value;
    MeshTarget.FdConvex         .Value := MeshSource.FdConvex         .Value;
    MeshTarget.FdCreaseAngle    .Value := MeshSource.FdCreaseAngle    .Value;
  end;

  CoordTarget := MeshTarget.InternalCoordinates(StateTarget);
  CoordSource := MeshSource.InternalCoordinates(StateSource);
  OldCoordCount := CoordTarget.Count;
  CoordTarget.Items.AddRangeTransformed(CoordSource.Items, StateSource.Transform);

  if P = mpTexCoord then
  begin
    TexCoordTarget := TexCoordinates(MeshTarget, StateTarget);
    TexCoordSource := TexCoordinates(MeshSource, StateSource);
    TexCoordTarget.Items.AddRange(TexCoordSource.Items);
    Check(CoordTarget.Count = TexCoordTarget.Count); // TODO: secure from it
  end;

  IndexTarget := MeshTarget.FdCoordIndex.Items;
  IndexSource := MeshSource.FdCoordIndex.Items;
  if (IndexTarget.Count <> 0) and
     (IndexTarget.Last >= 0) then
    IndexTarget.Add(-1); // separate from next polygons
  for I := 0 to IndexSource.Count - 1 do
  begin
    if IndexSource[I] >= 0 then
      IndexTarget.Add(IndexSource[I] + OldCoordCount)
    else
      IndexTarget.Add(IndexSource[I]); // don't modify source negative indexes
  end;
end;

procedure TBatchShapes.ClearMerge(const Target: TGLShape;
  const P: TMergePipeline);
var
  StateTarget: TX3DGraphTraverseState;
  MeshTarget: TIndexedFaceSetNode;
  CoordTarget: TMFVec3f;
  TexCoordTarget: TMFVec2f;
  IndexTarget: TLongIntList;
begin
  StateTarget := Target.State(true);
  MeshTarget := Target.Geometry(true) as TIndexedFaceSetNode;
  CoordTarget := MeshTarget.InternalCoordinates(StateTarget);
  CoordTarget.Items.Clear;
  IndexTarget := MeshTarget.FdCoordIndex.Items;
  IndexTarget.Clear;
  if P = mpTexCoord then
  begin
    TexCoordTarget := TexCoordinates(MeshTarget, StateTarget);
    TexCoordTarget.Items.Clear;
  end;
end;

class function TBatchShapes.TexCoordinates(
  const Geometry: TAbstractGeometryNode;
  const State: TX3DGraphTraverseState): TMFVec2f;
var
  TexCoordNode: TX3DNode;
begin
  if Geometry.InternalTexCoord(State, TexCoordNode) and
     (TexCoordNode is TTextureCoordinateNode) then
  begin
    Result := TTextureCoordinateNode(TexCoordNode).FdPoint;
  end else
    raise Exception.CreateFmt('Node %s does not have texture coordinates',
      [Geometry.NiceName]);
end;

function TBatchShapes.GetPoolShapes(const Index: Integer): TGLShape;
var
  PipelinesCount: Integer;
begin
  PipelinesCount := Ord(High(TMergePipeline)) + 1;
  Assert(Index div MergeSlots < PipelinesCount);
  Result := FPool[TMergePipeline(Index div MergeSlots), Index mod MergeSlots];
end;

function TBatchShapes.PoolShapesCount: Integer;
var
  PipelinesCount: Integer;
begin
  PipelinesCount := Ord(High(TMergePipeline)) + 1;
  Result := MergeSlots * PipelinesCount;
end;

end.
