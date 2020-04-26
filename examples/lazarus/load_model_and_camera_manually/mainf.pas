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

{ Main form. }
unit mainf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  CastleControl, CastleCameras, CastleScene, CastleViewport;

type
  TForm1 = class(TForm)
    Control1: TCastleControlBase;
    Viewport: TCastleViewport;
    procedure FormCreate(Sender: TObject);
  private
    WalkNavigation: TCastleWalkNavigation;
    Scene: TCastleScene;
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses CastleVectors, CastleSceneCore;

{ Simple demo how to load 3D scene, and set camera and navigation explicitly. }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Viewport := TCastleViewport.Create(Self);
  Viewport.FullSize := true;
  Viewport.AutoCamera := false;
  Viewport.AutoNavigation := false;
  Control1.Controls.InsertFront(Viewport);

  Scene := TCastleScene.Create(Self);
  Scene.Load('../../3d_rendering_processing/data/bridge_final.x3dv');
  Scene.Spatial := [ssRendering, ssDynamicCollisions]; // if you want collisions, and faster rendering
  Scene.ProcessEvents := true; // if you use VRML/X3D events

  Viewport.Items.MainScene := Scene;
  Viewport.Items.Add(Scene);

  Viewport.Camera.Init(
    Vector3(0, 0, 0), // position
    Vector3(1, 0, 0), // direction
    Vector3(0, 1, 0), // up
    Vector3(0, 1, 0)); // gravity up

  WalkNavigation := TCastleWalkNavigation.Create(Self);
  WalkNavigation.PreferredHeight := 2;
  WalkNavigation.Radius := 0.1;
  WalkNavigation.MoveSpeed := 10.0; // default is 1
  WalkNavigation.Gravity := true;
  Viewport.Navigation := WalkNavigation;
end;

end.
