{
  Copyright 2018-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Game initialization and logic. }
unit GameInitialize;

interface

implementation

uses SysUtils, Classes,
  CastleWindow, CastleScene, CastleControls, CastleLog, CastleVectors,
  CastleFilesUtils, CastleSceneCore, CastleViewport, CastleColors,
  CastleUIControls, CastleApplicationProperties, CastleCameras, X3DNodes;

var
  Window: TCastleWindowBase;
  Viewport: TCastleViewport;

{ buttons to change headlight ------------------------------------------------ }

type
  TButtons = class(TCastleVerticalGroup)
    ButtonHeadlightOn, ButtonHeadlightOff: TCastleButton;
    ButtonHeadlightDirectional: TCastleButton;
    ButtonHeadlightSpot: TCastleButton;
    ButtonHeadlightSpotSharp: TCastleButton;
    ButtonHeadlightPoint: TCastleButton;

    procedure ClickOn(Sender: TObject);
    procedure ClickOff(Sender: TObject);
    procedure ClickDirectional(Sender: TObject);
    procedure ClickSpot(Sender: TObject);
    procedure ClickSpotSharp(Sender: TObject);
    procedure ClickPoint(Sender: TObject);
    constructor Create(AOwner: TComponent); override;
  end;

constructor TButtons.Create(AOwner: TComponent);
begin
  inherited;

  ButtonHeadlightOn := TCastleButton.Create(Self);
  ButtonHeadlightOn.Caption := 'Headlight: On';
  ButtonHeadlightOn.OnClick := @ClickOn;
  InsertFront(ButtonHeadlightOn);

  ButtonHeadlightOff := TCastleButton.Create(Self);
  ButtonHeadlightOff.Caption := 'Headlight: Off';
  ButtonHeadlightOff.OnClick := @ClickOff;
  InsertFront(ButtonHeadlightOff);

  ButtonHeadlightDirectional := TCastleButton.Create(Self);
  ButtonHeadlightDirectional.Caption := 'Headlight Type: Directional (Like Sun)';
  ButtonHeadlightDirectional.OnClick := @ClickDirectional;
  InsertFront(ButtonHeadlightDirectional);

  ButtonHeadlightSpot := TCastleButton.Create(Self);
  ButtonHeadlightSpot.Caption := 'Headlight Type: Spot (Cone with Direction)';
  ButtonHeadlightSpot.OnClick := @ClickSpot;
  InsertFront(ButtonHeadlightSpot);

  ButtonHeadlightSpotSharp := TCastleButton.Create(Self);
  ButtonHeadlightSpotSharp.Caption := 'Headlight Type: Spot (Cone with Direction), Sharp Edge';
  ButtonHeadlightSpotSharp.OnClick := @ClickSpotSharp;
  InsertFront(ButtonHeadlightSpotSharp);

  ButtonHeadlightPoint := TCastleButton.Create(Self);
  ButtonHeadlightPoint.Caption := 'Headlight Type: Point (Uniform In All Directions)';
  ButtonHeadlightPoint.OnClick := @ClickPoint;
  InsertFront(ButtonHeadlightPoint);
end;

procedure TButtons.ClickOn(Sender: TObject);
begin
  Viewport.Items.UseHeadlight := hlOn;
end;

procedure TButtons.ClickOff(Sender: TObject);
begin
  Viewport.Items.UseHeadlight := hlOff;
end;

procedure TButtons.ClickDirectional(Sender: TObject);
begin
  Viewport.Items.HeadlightNode := TDirectionalLightNode.Create;
end;

procedure TButtons.ClickSpot(Sender: TObject);
var
  Spot: TSpotLightNode;
begin
  Spot := TSpotLightNode.Create;
  Spot.AmbientIntensity := 0.5; // make stuff outside light also a bit brighter
  Spot.CutOffAngle := 0.4;
  Spot.BeamWidth := 0.35;
  Viewport.Items.HeadlightNode := Spot;
end;

procedure TButtons.ClickSpotSharp(Sender: TObject);
var
  Spot: TSpotLightNode;
begin
  Spot := TSpotLightNode.Create;
  Spot.AmbientIntensity := 0.5; // make stuff outside light also a bit brighter
  Spot.CutOffAngle := 0.4;
  Spot.BeamWidth := 0.4;
  Viewport.Items.HeadlightNode := Spot;
end;

procedure TButtons.ClickPoint(Sender: TObject);
begin
  Viewport.Items.HeadlightNode := TPointLightNode.Create;
end;

{ routines ------------------------------------------------------------------- }

{ One-time initialization of resources. }
procedure ApplicationInitialize;
var
  LevelScene: TCastleScene;
  Buttons: TButtons;
begin
  { For a scalable UI (adjusts to any window size in a smart way), use UIScaling }
  Window.Container.UIReferenceWidth := 1024;
  Window.Container.UIReferenceHeight := 768;
  Window.Container.UIScaling := usEncloseReferenceSize;

  Viewport := TCastleViewport.Create(Application);
  Viewport.FullSize := true;
  Viewport.AutoCamera := true;
  Viewport.AutoNavigation := true;
  Window.Controls.InsertFront(Viewport);

  { Load level }
  LevelScene := TCastleScene.Create(Application);
  LevelScene.Load('castle-data:/level.x3d');
  LevelScene.Spatial := [ssRendering, ssDynamicCollisions];
  LevelScene.ProcessEvents := true;
  LevelScene.Attributes.PhongShading := true; // prettier lights

  Viewport.Items.Add(LevelScene);
  Viewport.Items.MainScene := LevelScene;

  { level.x3d, exported from Blender, has initially camera in Examine
    mode, with non-perfect gravity up.
    Change camera properties to be good for walking. }
  Viewport.NavigationType := ntWalk;
  Viewport.WalkNavigation.MoveSpeed := 5;
  Viewport.WalkNavigation.GravityUp := Vector3(0, 1, 0);

  { Make (initially) headlight "on".
    Default value of UseHeadlight is hlMainScene, which makes it dependent
    on MainScene settings. (see TCastleRootTransform.UseHeadlight docs for details) }
  Viewport.Items.UseHeadlight := hlOn;

  Buttons := TButtons.Create(Application);
  Buttons.Anchor(vpBottom, 10);
  Buttons.Anchor(hpLeft, 10);
  Buttons.Spacing := 10;
  Buttons.Padding := 10;
  Window.Controls.InsertFront(Buttons);
end;

initialization
  ApplicationProperties.ApplicationName := 'headlight_test';

  { For programs, InitializeLog is not called here.
    Instead InitializeLog is done by the program main file,
    after command-line parameters are parsed. }
  if IsLibrary then
    InitializeLog;

  Application.OnInitialize := @ApplicationInitialize;
  Window := TCastleWindowBase.Create(Application);
  Application.MainWindow := Window;
end.
