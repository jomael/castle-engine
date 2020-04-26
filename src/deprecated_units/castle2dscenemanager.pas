{
  Copyright 2014-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Scene manager (TCastle2DSceneManager) and scene (TCastle2DScene) best suited for 2D worlds. }
unit Castle2DSceneManager;

{$I castleconf.inc}

interface

uses Classes,
  CastleScene, CastleSceneManager, CastleUIControls, CastleCameras,
  CastleProjection, CastleVectors;

type
  { Scene manager best suited for 2D worlds.

    @unorderedList(
      @item(
        See @link(TCastleViewport.Setup2D) for a description what it does.
      )

      @item(Also, the navigation by default remains @nil,
        because @link(AutoNavigation) is by default @false.

        That is because you typically want to
        code yourself all camera movement for 2D games.

        Of course, just like with any @link(TCastleViewport), you can set
        @link(Navigation) to any custom navigation component.
      )
    )
  }
  TCastle2DSceneManager = class(TCastleSceneManager)
  strict private
    function GetProjectionAutoSize: Boolean;
    function GetProjectionWidth: Single;
    function GetProjectionHeight: Single;
    function GetProjectionSpan: Single;
    function GetProjectionOriginCenter: Boolean;
    procedure SetProjectionAutoSize(const Value: Boolean);
    procedure SetProjectionWidth(const Value: Single);
    procedure SetProjectionHeight(const Value: Single);
    procedure SetProjectionSpan(const Value: Single);
    procedure SetProjectionOriginCenter(const Value: Boolean);
  public
    const
      DefaultProjectionSpan = Default2DProjectionFar deprecated 'use Default2DProjectionFar';
      DefaultCameraZ = Default2DCameraZ deprecated 'use Default2DCameraZ';

    constructor Create(AOwner: TComponent); override;

    function CurrentProjectionWidth: Single; deprecated 'use Camera.Orthographic.EffectiveWidth';
    function CurrentProjectionHeight: Single; deprecated 'use Camera.Orthographic.EffectiveHeight';
  published
    property AutoCamera default false;
    property AutoNavigation default false;

    { When ProjectionAutoSize is @true, the size of the world visible
      in our viewport depends on scene manager size.
      ProjectionHeight and ProjectionWidth are ignored then.

      When ProjectionAutoSize is @false, ProjectionHeight and ProjectionWidth
      are used to determine the world visible in our viewport.
      If one of them is zero, the other is automatically adjusted to
      follow aspect ratio of viewport size.
      If both of them are zero, projection is automatically calculated just as
      if ProjectionAutoSize was @true.

      In all cases, CurrentProjectionWidth and CurrentProjectionHeight
      can be checked to see actual projection dimensions. }
    property ProjectionAutoSize: boolean
      read GetProjectionAutoSize write SetProjectionAutoSize default true;
      deprecated 'use Camera.Orthographic.Width and Height; only when both are zero, it is auto-sized';
    property ProjectionHeight: Single
      read GetProjectionHeight write SetProjectionHeight default 0;
      deprecated 'use Camera.Orthographic.Height, and note that ProjectionAutoSize is ignored';
    property ProjectionWidth: Single
      read GetProjectionWidth write SetProjectionWidth default 0;
      deprecated 'use Camera.Orthographic.Width, and note that ProjectionAutoSize is ignored';

    property ProjectionSpan: Single
      read GetProjectionSpan write SetProjectionSpan default Default2DProjectionFar;
      deprecated 'use Camera.ProjectionFar';

    { Where is the (0,0) world point with respect to the viewport.

      If @false, the (0,0) is in the left-bottom corner, which matches
      the typical 2D drawing coordinates used throughout our engine.
      In other words, if the camera is at position (0,0,whatever),
      then the (0,0) position in 2D is in the left-bottom corner of the scene manager
      rectangle.

      If @true, the (0,0) is in the middle of the viewport.
      In other words, if the camera is at position (0,0,whatever),
      then the (0,0) position is in the center of the scene manager
      rectangle.

      Both values of @name make sense,
      it depends on the game type and how you prefer to think in 2D coordinates.
      And how do you want the result to behave when aspect ratio changes:

      @unorderedList(
        @item(With ProjectionOriginCenter = @true, things will stay "glued"
          to the center.)
        @item(With ProjectionOriginCenter = @false, things will stay "glued"
          to the left-bottom corner.)
      )
    }
    property ProjectionOriginCenter: boolean
      read GetProjectionOriginCenter write SetProjectionOriginCenter default false;
      deprecated 'use Camera.Orthographic.Origin';
  end deprecated 'use TCastleViewport. To have the same initial behavior call Setup2D method, and set FullSize:=true';

  T2DSceneManager = class(TCastle2DSceneManager)
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Transparent default true;
  end deprecated 'use TCastleViewport. To have the same initial behavior call Setup2D method, and set FullSize:=true, and set Transparent:=true';

  { Scene best suited for 2D models. Sets BlendingSort := bs2D,
    good when your transparent objects have proper order along the Z axis
    (useful e.g. for Spine animations). }
  TCastle2DScene = class(TCastleScene)
  public
    constructor Create(AOwner: TComponent); override;

    { Create a scene with the same contents (X3D scene graph) as this one.
      Note that this @bold(does not copy other scene attributes),
      like @link(ProcessEvents) or @link(Spatial) or rendering attributes
      in @link(Attributes). }
    function Clone(const AOwner: TComponent): TCastle2DScene;
  end deprecated 'use TCastleScene, and call Setup2D right after creating';

  T2DScene = TCastle2DScene deprecated 'use TCastleScene, and call Setup2D right after creating';

implementation

uses SysUtils,
  CastleBoxes, CastleGLUtils, X3DNodes, CastleComponentSerialize, CastleUtils,
  CastleRectangles, CastleLog;

{ TCastle2DSceneManager -------------------------------------------------------- }

constructor TCastle2DSceneManager.Create(AOwner: TComponent);
begin
  inherited;
  Setup2D;
  AutoNavigation := false;
end;

function TCastle2DSceneManager.CurrentProjectionWidth: Single;
begin
  Result := Camera.Orthographic.EffectiveWidth;
end;

function TCastle2DSceneManager.CurrentProjectionHeight: Single;
begin
  Result := Camera.Orthographic.EffectiveHeight;
end;

function TCastle2DSceneManager.GetProjectionAutoSize: Boolean;
begin
  Result := false; // it behaves like always false, now
end;

function TCastle2DSceneManager.GetProjectionWidth: Single;
begin
  Result := Camera.Orthographic.Width;
end;

function TCastle2DSceneManager.GetProjectionHeight: Single;
begin
  Result := Camera.Orthographic.Height;
end;

function TCastle2DSceneManager.GetProjectionSpan: Single;
begin
  Result := Camera.ProjectionFar;
end;

function TCastle2DSceneManager.GetProjectionOriginCenter: Boolean;
begin
  Result := not Camera.Orthographic.Origin.IsPerfectlyZero;
end;

procedure TCastle2DSceneManager.SetProjectionAutoSize(const Value: Boolean);
begin
  if Value then
    WritelnWarning('TCastle2DSceneManager always behaves as if ProjectionAutoSize = false. We will automatically calculate projection width or height if one (or both) of Camera.Orthographic.Width/Height are zero.');
end;

procedure TCastle2DSceneManager.SetProjectionWidth(const Value: Single);
begin
  Camera.Orthographic.Width := Value;
end;

procedure TCastle2DSceneManager.SetProjectionHeight(const Value: Single);
begin
  Camera.Orthographic.Height := Value;
end;

procedure TCastle2DSceneManager.SetProjectionSpan(const Value: Single);
begin
  Camera.ProjectionFar := Value;
end;

procedure TCastle2DSceneManager.SetProjectionOriginCenter(const Value: Boolean);
begin
  if Value then
    Camera.Orthographic.Origin := Vector2(0.5, 0.5)
  else
    Camera.Orthographic.Origin := TVector2.Zero;
end;

{ T2DSceneManager ------------------------------------------------------------ }

constructor T2DSceneManager.Create(AOwner: TComponent);
begin
  inherited;
  Transparent := true;
end;

{ TCastle2DScene --------------------------------------------------------------- }

constructor TCastle2DScene.Create(AOwner: TComponent);
begin
  inherited;
  Attributes.BlendingSort := bs2D;
end;

function TCastle2DScene.Clone(const AOwner: TComponent): TCastle2DScene;
begin
  Result := TCastle2DScene.Create(AOwner);
  if RootNode <> nil then
    Result.Load(RootNode.DeepCopy as TX3DRootNode, true);
end;

var
  R: TRegisteredComponent;
initialization
  R := TRegisteredComponent.Create;
  {$warnings off} // using deprecated, to keep reading it from castle-user-interface working
  R.ComponentClass := TCastle2DSceneManager;
  {$warnings on}
  R.Caption := '2D Scene Manager';
  R.IsDeprecated := true;
  RegisterSerializableComponent(R);

  RegisterSerializableComponent(TCastle2DScene, '2D Scene');
end.
