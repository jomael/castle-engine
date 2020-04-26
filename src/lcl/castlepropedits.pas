{
  Copyright 2010-2018 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Property and component editors for components.
  These are used by object inspectors (inside Lazarus or CGE editor).

  For documentation how to create property editors, component editors etc. see
  - http://wiki.freepascal.org/How_To_Write_Lazarus_Component#Component_editors
  - comments of Lazarus ideintf/propedits.pp sources.

  @exclude This unit is not supposed to be used by normal developers.
  It should only be used to register the editors (in Lazarus, in CGE editor). }
unit CastlePropEdits;

{$I castleconf.inc}

interface

var
  PropertyEditorsAdviceDataDirectory: Boolean;

procedure Register;

implementation

uses SysUtils, Classes,
  PropEdits, ComponentEditors, LResources, Dialogs, Controls, LCLVersion,
  OpenGLContext, Graphics,
  CastleSceneCore, CastleScene, CastleLCLUtils, X3DLoad, X3DNodes, CastleCameras,
  CastleUIControls, CastleControl, CastleControls, CastleImages, CastleTransform,
  CastleVectors, CastleUtils, CastleColors, CastleViewport, CastleDialogs,
  CastleTiledMap, CastleGLImages, CastleStringUtils;

{$I castlepropedits_any_subproperties.inc}
{$I castlepropedits_autoanimation.inc}
{$I castlepropedits_url.inc}
{$I castlepropedits_color.inc}
{$I castlepropedits_vector.inc}
{$I castlepropedits_image.inc}
{$I castlepropedits_unused_controls.inc}
{$I castlepropedits_viewport_navigation.inc}

procedure Register;
begin
  { URL properties }
  RegisterPropertyEditor(TypeInfo(AnsiString), TCastleSceneCore,
    'URL', TSceneURLPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCastleImageControl,
    'URL', TImageURLPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCastleImagePersistent,
    'URL', TImageURLPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCastleDesign,
    'URL', TDesignURLPropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCastleTiledMapControl,
    'URL', TTiledMapURLPropertyEditor);

  { Properties that simply use TSubPropertiesEditor.
    Registering properties that use TSubPropertiesEditor
    (not any descendant of it) is still necessary to expand them
    in castle-editor and Lazarus design-time. }
  RegisterPropertyEditor(TypeInfo(TCastleRootTransform), TCastleViewport, 'Items',
    TSubPropertiesEditor);
  RegisterPropertyEditor(TypeInfo(TBorder), nil, '',
    TSubPropertiesEditor);
  RegisterPropertyEditor(TypeInfo(TCastleCamera), TCastleViewport, '',
    TSubPropertiesEditor);

  { Other properties }
  RegisterPropertyEditor(TypeInfo(TCastleImagePersistent), nil, '',
    TCastleImagePersistentEditor);
  RegisterPropertyEditor(TypeInfo(TCastleColorPersistent), nil, '',
    TCastleColorPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCastleColorRGBPersistent), nil, '',
    TCastleColorRGBPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCastleVector2Persistent), nil, '',
    TCastleVector2PropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCastleVector3Persistent), nil, '',
    TCastleVector3PropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCastleVector4Persistent), nil, '',
    TCastleVector4PropertyEditor);
  RegisterPropertyEditor(TypeInfo(AnsiString), TCastleSceneCore, 'AutoAnimation',
    TSceneAutoAnimationPropertyEditor);
  RegisterPropertyEditor(TypeInfo(TCastleNavigation), TCastleViewport, 'Navigation',
    TViewportNavigationEditor);
  RegisterPropertyEditor(TypeInfo(TCastleNavigation), TCastleViewport, 'Navigation',
    TViewportNavigationEditor);
end;

initialization
  { Add lrs with icons, following
    http://wiki.lazarus.freepascal.org/Lazarus_Packages#Add_a_component_icon }
  {$I icons/castleicons.lrs}
end.
