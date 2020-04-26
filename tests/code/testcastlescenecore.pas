unit TestCastleSceneCore;

{$I tests.inc}

interface

uses
  Classes, SysUtils, FpcUnit, TestUtils, TestRegistry, X3DNodes;

type
  TTestSceneCore = class(TTestCase)
  strict private
    SearchingForDescription: string;
    function SearchingForDescriptionCallback(Node: TX3DNode): Pointer;
    procedure NodeMultipleTimesWarning(const Category, S: string);
    procedure OnWarningRaiseException(const Category, S: string);
  published
    procedure TestBorderManifoldEdges;
    procedure TestIterator;
    { $define ITERATOR_SPEED_TEST}
    {$ifdef ITERATOR_SPEED_TEST}
    procedure TestIteratorSpeed;
    {$endif ITERATOR_SPEED_TEST}
    procedure TestFind;
    procedure TestViewpointBillboardTricky;
    procedure TestManifold;
    procedure TestMultipleScenesOneNodeIncorrect;
    procedure TestMultipleScenesOneNodeCorrect;
    procedure TestSpineUtf8Names;
  end;

implementation

uses CastleSceneCore, X3DLoad, CastleVectors, CastleShapes,
  CastleTimeUtils, CastleStringUtils, X3DFields, CastleSceneManager,
  CastleFilesUtils, CastleScene, CastleTransform, CastleApplicationProperties;

procedure TTestSceneCore.TestBorderManifoldEdges;
var
  Scene: TCastleSceneCore;
  Manifold, Border: Cardinal;
begin
  Scene := TCastleSceneCore.Create(nil);
  try
    Scene.Load('data/model_manifold.wrl');
    Scene.EdgesCount(Manifold, Border);
    AssertEquals(0, Border);
  finally FreeAndNil(Scene) end;
end;

{$ifdef ITERATOR_SPEED_TEST}
procedure TTestSceneCore.TestIteratorSpeed;

  procedure CheckIteratorSpeed(const FileName: string;
    const TestCount: Integer = 1000);
  var
    Scene: TCastleSceneCore;
    List: TShapesList;
    SI: TShapeTreeIterator;
    OnlyActive: boolean;
    I: Integer;
    Test: Integer;
  begin
    Writeln('CheckIteratorSpeed on ', FileName);

    Scene := TCastleSceneCore.Create(nil);
    try
      Scene.Load(FileName);
      for OnlyActive := false to true do
      begin
        ProcessTimerBegin;
        for Test := 0 to TestCount - 1 do
        begin
          List := TShapesList.Create(Scene.Shapes, OnlyActive);
          for I := 0 to List.Count - 1 do
            { Just do anything that requires access to List[I] }
            PointerToStr(List[I].Geometry);
          FreeAndNil(List);
        end;
        Writeln('TShapesList traverse: ', ProcessTimerEnd:1:2);

        ProcessTimerBegin;
        for Test := 0 to TestCount - 1 do
        begin
          SI := TShapeTreeIterator.Create(Scene.Shapes, OnlyActive);
          while SI.GetNext do
            PointerToStr(SI.Current.Geometry);
          FreeAndNil(SI);
        end;
        Writeln('TShapeTreeIterator: ', ProcessTimerEnd:1:2);

      end;
    finally FreeAndNil(Scene) end;
  end;

begin
  CheckIteratorSpeed('../../demo_models/x3d/deranged_house_final.x3dv');
  CheckIteratorSpeed('../../demo_models/x3d/anchor_test.x3dv');
  CheckIteratorSpeed('../../demo_models/x3d/switches_and_transforms.x3dv');
  CheckIteratorSpeed('../../demo_models/x3d/key_sensor.x3dv');

  CheckIteratorSpeed('data/switches_and_transforms_2.x3dv');
  CheckIteratorSpeed('data/key_sensor_2.x3dv');

  CheckIteratorSpeed('/home/michalis/sources/rrtankticks2/rrtankticks3/rrtt.wrl',
    10); { smaller TestCount, as it's quite slow }
end;
{$endif ITERATOR_SPEED_TEST}

procedure TTestSceneCore.TestIterator;

  procedure CheckIterator(const FileName: string);
  var
    Scene: TCastleSceneCore;
    List: TShapeList;
    SI: TShapeTreeIterator;
    OnlyActive: boolean;
    I: Integer;
  begin
    Scene := TCastleSceneCore.Create(nil);
    try
      Scene.Load(FileName);
      for OnlyActive := false to true do
      begin
        { Compare the simple iterator implementation (that just calls
          Traverse and gathers results to the list) with actual sophisticated
          implementation in TShapeTreeIterator. }
        List := TShapeList.Create(Scene.Shapes, OnlyActive);
        SI := TShapeTreeIterator.Create(Scene.Shapes, OnlyActive);
        for I := 0 to List.Count - 1 do
        begin
          Check(SI.GetNext, 'SI.GetNext');
          Check(SI.Current = List[I], 'SI.Current');
        end;
        Check(not SI.GetNext, 'not SI.GetNext');

//        writeln('done for ', FileName, ' active: ', OnlyActive, ' count is ', List.Count);

        FreeAndNil(List);
        FreeAndNil(SI);
      end;
    finally FreeAndNil(Scene) end;
  end;

begin
  CheckIterator('data/demo-models-copy/deranged_house_final.x3dv');
  CheckIterator('data/demo-models-copy/anchor_test.x3dv');
  CheckIterator('data/switches_and_transforms_2.x3dv');
  CheckIterator('data/key_sensor_2.x3dv');
  CheckIterator('data/extrusion_empty_spine.x3dv');
  CheckIterator('data/extrusion_empty_spine_concave.x3dv');
  CheckIterator('data/extrusion_empty_spine_smooth.x3dv');

  // This once failed to be read with FPC 3.1.1
  CheckIterator('data/spine/escape_from_the_universe_boss/boss.json');

  // This once failed to be read, as the Spine has DefaultSkin = nil
  CheckIterator('data/spine/empty_spine.json');

  // This once failed with access violation because TClippingAttachment.BuildNodes didn't assign Material
  CheckIterator('data/spine/clip_region/skeleton.json');
end;

procedure TTestSceneCore.TestFind;
var
  Scene: TCastleSceneCore;
begin
  Scene := TCastleSceneCore.Create(nil);
  try
    try
      Scene.Node('Left');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    try
      Scene.Field('Left', 'translation');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    try
      Scene.Event('Left', 'addChildren');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    Scene.URL := 'data/switches_and_transforms_2.x3dv';
    Scene.Node('Left');
    Scene.Field('Left', 'translation');
    Scene.Event('Left', 'addChildren');

    try
      Scene.Node('Blah');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    try
      Scene.Field('Blah', 'translation');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    try
      Scene.Event('Blah', 'addChildren');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    try
      Scene.Field('Left', 'blah');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;

    try
      Scene.Event('Left', 'blah');
      Fail('Should fail with EX3DNotFound');
    except on EX3DNotFound do ; end;
  finally FreeAndNil(Scene) end;
end;

function TTestSceneCore.SearchingForDescriptionCallback(Node: TX3DNode): Pointer;
begin
  if (Node is TAbstractViewpointNode) and
     (TAbstractViewpointNode(Node).SmartDescription = SearchingForDescription) then
    Result := Node else
    Result := nil;
end;

procedure TTestSceneCore.TestViewpointBillboardTricky;
{ Unfortunately, it cannot reproduce bug #38 for some reason...
  Probably it misses something that triggers it interactively. }
var
  Scene: TCastleScene;

  function FindViewpointByDescription(const Description: string): TAbstractViewpointNode;
  begin
    SearchingForDescription := Description;
    AssertTrue(Scene.RootNode <> nil);
    Result := TAbstractViewpointNode(
      Scene.RootNode.SearchNodes(@SearchingForDescriptionCallback, true));
    AssertTrue(Result <> nil);
  end;

var
  Viewpoint: TAbstractViewpointNode;
  SceneManager: TCastleSceneManager;
  FakeRemoveMe: TRemoveType;
begin
  SceneManager := TCastleSceneManager.Create(nil);
  try
    Scene := TCastleScene.Create(nil);
    try
      Scene.URL := 'castle-data:/city_from_bugreport_38.x3dv';
      Scene.ProcessEvents := true;
      Scene.Spatial := [ssRendering, ssDynamicCollisions];
      SceneManager.Items.Add(Scene);
      SceneManager.MainScene := Scene;

      Scene.CameraChanged(SceneManager.RequiredCamera);
      FakeRemoveMe := rtNone;
      Scene.Update(1, FakeRemoveMe);

      Viewpoint := FindViewpointByDescription('City plan');
      Viewpoint.Bound := true;

      Scene.CameraChanged(SceneManager.Camera);
      FakeRemoveMe := rtNone;
      Scene.Update(1, FakeRemoveMe);
    finally FreeAndNil(Scene) end;
  finally FreeAndNil(SceneManager) end;
end;

procedure TTestSceneCore.TestManifold;
var
  Scene: TCastleSceneCore;
  ManifoldEdges, BorderEdges: Cardinal;
begin
  Scene := TCastleSceneCore.Create(nil);
  try
    Scene.URL := 'castle-data:/shadow_volumes_tests/should_be_manifold.x3d';
    Scene.EdgesCount(ManifoldEdges, BorderEdges);
    AssertEquals(0, BorderEdges);
    AssertEquals(210, ManifoldEdges);
  finally FreeAndNil(Scene) end;
end;

type
  ENodeMultipleTimes = class(Exception);

procedure TTestSceneCore.NodeMultipleTimesWarning(const Category, S: string);
begin
  if Pos('is already part of another TCastleScene instance', S) <> 0 then
    raise ENodeMultipleTimes.Create('We want this warning, good: ' + S)
  else
    raise Exception.Create('Some invalid warning: ' + S);
end;

procedure TTestSceneCore.TestMultipleScenesOneNodeIncorrect;

{ Deliberately do something incorrect: place the same TX3DRootNode
  in multiple TCastleScene instances.
  Check that we make a warning about it. }

var
  Node: TX3DRootNode;
  Scene1, Scene2: TCastleScene;
begin
  ApplicationProperties.OnWarning.Add(@NodeMultipleTimesWarning);
  try
    try
      Node := nil;
      Scene1 := nil;
      Scene2 := nil;
      try
        Node := LoadNode('castle-data:/game/scene.x3d');
        Scene1 := TCastleScene.Create(nil);
        Scene2 := TCastleScene.Create(nil);
        Scene1.Load(Node, false);
        Scene2.Load(Node, false);
        raise Exception.Create('We should not get here, expected ENodeMultipleTimes on the way');
      finally
        FreeAndNil(Scene1);
        FreeAndNil(Scene2);
        // Note: you must free Node after freeing Scene1,2
        FreeAndNil(Node);
      end;
    except
      on ENodeMultipleTimes do ; { good, silence this for the sake of test }
    end;
  finally
    ApplicationProperties.OnWarning.Remove(@NodeMultipleTimesWarning);
  end;
end;

procedure TTestSceneCore.TestMultipleScenesOneNodeCorrect;
var
  Node: TX3DRootNode;
  Scene1, Scene2, SceneTemplate: TCastleScene;
begin
  // When using Static=true, it is allowed to have the same TX3DRootNode reused:

  Node := nil;
  Scene1 := nil;
  Scene2 := nil;
  try
    Node := LoadNode('castle-data:/game/scene.x3d');
    Scene1 := TCastleScene.Create(nil);
    Scene1.Static := true;
    Scene2 := TCastleScene.Create(nil);
    Scene2.Static := true;
    Scene1.Load(Node, false);
    Scene2.Load(Node, false);
  finally
    FreeAndNil(Scene1);
    FreeAndNil(Scene2);
    // Note: you must free Node after freeing Scene1,2
    FreeAndNil(Node);
  end;

  // Using DeepCopy you can overcome this limitation:

  Node := nil;
  Scene1 := nil;
  Scene2 := nil;
  try
    Node := LoadNode('castle-data:/game/scene.x3d');
    Scene1 := TCastleScene.Create(nil);
    Scene2 := TCastleScene.Create(nil);
    Scene1.Load(Node.DeepCopy as TX3DRootNode, true);
    Scene2.Load(Node.DeepCopy as TX3DRootNode, true);
  finally
    FreeAndNil(Node);
    FreeAndNil(Scene1);
    FreeAndNil(Scene2);
  end;

  // Using Clone you can overcome this limitation:

  SceneTemplate := nil;
  Scene1 := nil;
  Scene2 := nil;
  try
    SceneTemplate := TCastleScene.Create(nil);
    SceneTemplate.Load('castle-data:/game/scene.x3d');
    Scene1 := SceneTemplate.Clone(nil);
    Scene2 := SceneTemplate.Clone(nil);
  finally
    FreeAndNil(SceneTemplate);
    FreeAndNil(Scene1);
    FreeAndNil(Scene2);
  end;
end;

procedure TTestSceneCore.OnWarningRaiseException(const Category, S: string);
begin
  raise Exception.CreateFmt('TTestSceneCore made a warning, and any warning here is an error: %s: %s', [Category, S]);
end;

procedure TTestSceneCore.TestSpineUtf8Names;
var
  Scene: TCastleScene;
begin
  ApplicationProperties.OnWarning.Add(@OnWarningRaiseException);
  try
    Scene := TCastleScene.Create(nil);
    try
      Scene.Load('castle-data:/spine/uhholy_chapter_one_end/skeleton.json');
      Scene.Load('castle-data:/spine/unholy_transition/phone.json');
    finally FreeAndNil(Scene) end;
  finally
    ApplicationProperties.OnWarning.Remove(@OnWarningRaiseException);
  end;
end;

initialization
  RegisterTest(TTestSceneCore);
end.
