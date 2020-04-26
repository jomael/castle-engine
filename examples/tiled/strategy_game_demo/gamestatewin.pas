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

{ Display instructions. }
unit GameStateWin;

interface

uses CastleUIState, CastleControls, CastleWindow, CastleUIControls,
  CastleKeysMouse;

type
  TStateWin = class(TUIState)
  public
    HumansWin: Boolean; //< Set this before starting this state.
    procedure Start; override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

var
  StateWin: TStateWin;

implementation

uses SysUtils, Classes,
  CastleComponentSerialize,
  GameStateMainMenu;

procedure TStateWin.Start;
var
  UiOwner: TComponent;
begin
  inherited;

  { Load designed user interface }
  if HumansWin then
    InsertUserInterface('castle-data:/state_win_humans.castle-user-interface', FreeAtStop, UiOwner)
  else
    InsertUserInterface('castle-data:/state_win_aliens.castle-user-interface', FreeAtStop, UiOwner);

  { do not pass clicks to state underneath }
  InterceptInput := true;
end;

function TStateWin.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;

  if Event.IsMouseButton(mbLeft) then
  begin
    TUIState.Current := StateMainMenu;
    Exit(ExclusiveEvents);
  end;
end;

end.
