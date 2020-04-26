{
  Copyright 2018-2019 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Project form (@link(TProjectForm)). }
unit FormProject;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DOM, FileUtil, Forms, Controls, Graphics, Dialogs, Menus,
  ExtCtrls, ComCtrls, CastleShellCtrls, StdCtrls, ValEdit, ActnList, ProjectUtils,
  Types, Contnrs,
  CastleControl, CastleUIControls, CastlePropEdits, CastleDialogs, X3DNodes,
  EditorUtils, FrameDesign, FrameViewFile;

type
  { Main project management. }
  TProjectForm = class(TForm)
    LabelNoDesign: TLabel;
    ListWarnings: TListBox;
    MenuItemPreferences: TMenuItem;
    N1: TMenuItem;
    MenuItemDuplicateComponent: TMenuItem;
    MenuItemPasteComponent: TMenuItem;
    MenuItemCopyComponent: TMenuItem;
    MenuItemSupport: TMenuItem;
    MenuItemSeparator788: TMenuItem;
    MenuItemRestartRebuildEditor: TMenuItem;
    MenuItemSeparator1300: TMenuItem;
    MenuItemSeparator170: TMenuItem;
    MenuItemDesignNewUserInterfaceCustomRoot: TMenuItem;
    MenuItemDesignNewTransformCustomRoot: TMenuItem;
    MenuItemDesignDeleteComponent: TMenuItem;
    MenuItemDesignAddTransform: TMenuItem;
    MenuItemDesignAddUserInterface: TMenuItem;
    MenuItemSeparator150: TMenuItem;
    MenuItemDesignClose: TMenuItem;
    MenuItemDesign: TMenuItem;
    OpenDesignDialog: TCastleOpenDialog;
    MenuItemOpenDesign: TMenuItem;
    MenuItemSeparator201: TMenuItem;
    MenuItemDesignNewTransform: TMenuItem;
    MenuItemDesignNewUserInterfaceRect: TMenuItem;
    SaveDesignDialog: TCastleSaveDialog;
    MenuItemSaveAsDesign: TMenuItem;
    MenuItemSaveDesign: TMenuItem;
    ListOutput: TListBox;
    MainMenu1: TMainMenu;
    MenuItemSeparator101: TMenuItem;
    MenuItemBreakProcess: TMenuItem;
    MenuItemSeprator100: TMenuItem;
    MenuItemAutoGenerateClean: TMenuItem;
    MenuItemAutoGenerateTextures: TMenuItem;
    MenuItemPackageSource: TMenuItem;
    MenuItemModeRelease: TMenuItem;
    MenuItemPackage: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItemModeDebug: TMenuItem;
    MenuItemSeparator3: TMenuItem;
    MenuItemSeparator2: TMenuItem;
    MenuItemReference: TMenuItem;
    MenuItemManual: TMenuItem;
    MenuItemCgeWww: TMenuItem;
    MenuItemAbout: TMenuItem;
    MenuItemSeparator: TMenuItem;
    MenuItemHelp: TMenuItem;
    MenuItemClean: TMenuItem;
    MenuItemOnlyRun: TMenuItem;
    MenuItemCompileRun: TMenuItem;
    MenuItemCompile: TMenuItem;
    MenuItemSwitchProject: TMenuItem;
    MenuItemRun: TMenuItem;
    MenuItemFile: TMenuItem;
    MenuItemQuit: TMenuItem;
    PageControlBottom: TPageControl;
    PanelAboveTabs: TPanel;
    SplitterBetweenFiles: TSplitter;
    Splitter2: TSplitter;
    TabFiles: TTabSheet;
    TabOutput: TTabSheet;
    ProcessUpdateTimer: TTimer;
    TabWarnings: TTabSheet;
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ListOutputClick(Sender: TObject);
    procedure MenuItemPreferencesClick(Sender: TObject);
    procedure MenuItemAutoGenerateCleanClick(Sender: TObject);
    procedure MenuItemAboutClick(Sender: TObject);
    procedure MenuItemAutoGenerateTexturesClick(Sender: TObject);
    procedure MenuItemBreakProcessClick(Sender: TObject);
    procedure MenuItemCgeWwwClick(Sender: TObject);
    procedure MenuItemCleanClick(Sender: TObject);
    procedure MenuItemCompileClick(Sender: TObject);
    procedure MenuItemCompileRunClick(Sender: TObject);
    procedure MenuItemCopyComponentClick(Sender: TObject);
    procedure MenuItemDesignCloseClick(Sender: TObject);
    procedure MenuItemDesignDeleteComponentClick(Sender: TObject);
    procedure MenuItemDuplicateComponentClick(Sender: TObject);
    procedure MenuItemManualClick(Sender: TObject);
    procedure MenuItemModeDebugClick(Sender: TObject);
    procedure MenuItemDesignNewUserInterfaceRectClick(Sender: TObject);
    procedure MenuItemDesignNewTransformClick(Sender: TObject);
    procedure MenuItemOnlyRunClick(Sender: TObject);
    procedure MenuItemOpenDesignClick(Sender: TObject);
    procedure MenuItemPackageClick(Sender: TObject);
    procedure MenuItemPackageSourceClick(Sender: TObject);
    procedure MenuItemPasteComponentClick(Sender: TObject);
    procedure MenuItemQuitClick(Sender: TObject);
    procedure MenuItemReferenceClick(Sender: TObject);
    procedure MenuItemModeReleaseClick(Sender: TObject);
    procedure MenuItemRestartRebuildEditorClick(Sender: TObject);
    procedure MenuItemSaveAsDesignClick(Sender: TObject);
    procedure MenuItemSaveDesignClick(Sender: TObject);
    procedure MenuItemSupportClick(Sender: TObject);
    procedure MenuItemSwitchProjectClick(Sender: TObject);
    procedure ProcessUpdateTimerTimer(Sender: TObject);
  private
    ProjectName: String;
    ProjectPath, ProjectPathUrl, ProjectStandaloneSource, ProjectLazarus: String;
    BuildMode: TBuildMode;
    OutputList: TOutputList;
    RunningProcess: TAsynchronousProcessQueue;
    Design: TDesignFrame;
    ShellListView1: TCastleShellListView;
    ShellTreeView1: TCastleShellTreeView;
    ViewFileFrame: TViewFileFrame;
    SplitterBetweenViewFile: TSplitter;
    procedure BuildToolCall(const Commands: array of String;
        const ExitOnSuccess: Boolean = false);
    procedure MenuItemAddComponentClick(Sender: TObject);
    procedure MenuItemDesignNewCustomRootClick(Sender: TObject);
    procedure SetEnabledCommandRun(const AEnabled: Boolean);
    procedure FreeProcess;
    procedure ShellListViewDoubleClick(Sender: TObject);
    procedure ShellListViewSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure UpdateFormCaption(Sender: TObject);
    { Propose saving the hierarchy.
      Returns should we continue (user did not cancel). }
    function ProposeSaveDesign: Boolean;
    { Call always when Design<>nil value changed. }
    procedure DesignExistenceChanged;
    { Create Design, if nil. }
    procedure NeedsDesignFrame;
    procedure WarningNotification(const Category, Message: string);
  public
    { Open a project, given an absolute path to CastleEngineManifest.xml }
    procedure OpenProject(const ManifestUrl: String);
  end;

var
  ProjectForm: TProjectForm;

implementation

{$R *.lfm}

uses TypInfo, LCLType,
  CastleXMLUtils, CastleLCLUtils, CastleOpenDocument, CastleURIUtils,
  CastleFilesUtils, CastleUtils, CastleVectors, CastleColors,
  CastleScene, CastleViewport, Castle2DSceneManager, CastleCameras,
  CastleTransform, CastleControls, CastleDownload, CastleApplicationProperties,
  CastleLog, CastleComponentSerialize, CastleSceneCore, CastleStringUtils,
  CastleFonts, X3DLoad, CastleFileFilters, CastleImages, CastleSoundEngine,
  FormChooseProject, ToolCommonUtils, FormAbout, FormPreferences,
  ToolCompilerInfo;

procedure TProjectForm.MenuItemQuitClick(Sender: TObject);
begin
  if ProposeSaveDesign then
    Application.Terminate;
end;

procedure TProjectForm.MenuItemReferenceClick(Sender: TObject);
begin
  OpenURL('https://castle-engine.io/apidoc/html/index.html');
end;

procedure TProjectForm.MenuItemModeReleaseClick(Sender: TObject);
begin
  BuildMode := bmRelease;
  MenuItemModeRelease.Checked := true;
end;

procedure TProjectForm.MenuItemRestartRebuildEditorClick(Sender: TObject);
begin
  BuildToolCall(['editor'], true);
end;

procedure TProjectForm.MenuItemSaveAsDesignClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise

  if Design.DesignRoot is TCastleUserInterface then
    SaveDesignDialog.DefaultExt := 'castle-user-interface'
  else
  if Design.DesignRoot is TCastleTransform then
    SaveDesignDialog.DefaultExt := 'castle-transform'
  else
    raise EInternalError.Create('DesignRoot does not descend from TCastleUserInterface or TCastleTransform');

  SaveDesignDialog.Url := Design.DesignUrl;
  if SaveDesignDialog.Execute then
    Design.SaveDesign(SaveDesignDialog.Url);
    // TODO: save DesignUrl somewhere? CastleEditorSettings.xml?
end;

procedure TProjectForm.MenuItemSaveDesignClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise

  if Design.DesignUrl = '' then
    MenuItemSaveAsDesignClick(Sender)
  else
    Design.SaveDesign(Design.DesignUrl);
end;

procedure TProjectForm.MenuItemSupportClick(Sender: TObject);
begin
  OpenURL('https://patreon.com/castleengine/');
end;

procedure TProjectForm.MenuItemCgeWwwClick(Sender: TObject);
begin
  OpenURL('https://castle-engine.io/');
end;

procedure TProjectForm.MenuItemAboutClick(Sender: TObject);
begin
  AboutForm.ShowModal;
end;

procedure TProjectForm.MenuItemAutoGenerateTexturesClick(Sender: TObject);
begin
  BuildToolCall(['auto-generate-textures']);
end;

procedure TProjectForm.MenuItemBreakProcessClick(Sender: TObject);
begin
  if RunningProcess = nil then
    raise EInternalError.Create('It should not be possible to call this when RunningProcess = nil');

  OutputList.AddSeparator;
  OutputList.AddLine('Forcefully killing the process.', okError);
  FreeProcess;
end;

procedure TProjectForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if ProposeSaveDesign then
    Application.Terminate
  else
    CanClose := false;
end;

procedure TProjectForm.FormCreate(Sender: TObject);

  function CreateMenuItemForComponent(const R: TRegisteredComponent): TMenuItem;
  var
    S: String;
  begin
    Result := TMenuItem.Create(Self);
    S := R.Caption + ' (' + R.ComponentClass.ClassName + ')';
    if R.IsDeprecated then
      S := '(Deprecated) ' + S;
    Result.Caption := S;
    Result.Tag := PtrInt(Pointer(R));
  end;

  procedure BuildComponentsMenu;
  var
    MenuItem: TMenuItem;
    R: TRegisteredComponent;
  begin
    { add non-deprecated components }
    for R in RegisteredComponents do
      if not R.IsDeprecated then
      begin
        if R.ComponentClass.InheritsFrom(TCastleUserInterface) and
           not R.ComponentClass.InheritsFrom(TCastleNavigation) then
        begin
          MenuItem := CreateMenuItemForComponent(R);
          MenuItem.OnClick := @MenuItemDesignNewCustomRootClick;
          MenuItemDesignNewUserInterfaceCustomRoot.Add(MenuItem);

          MenuItem := CreateMenuItemForComponent(R);
          MenuItem.OnClick := @MenuItemAddComponentClick;
          MenuItemDesignAddUserInterface.Add(MenuItem);
        end else
        if R.ComponentClass.InheritsFrom(TCastleTransform) then
        begin
          MenuItem := CreateMenuItemForComponent(R);
          MenuItem.OnClick := @MenuItemDesignNewCustomRootClick;
          MenuItemDesignNewTransformCustomRoot.Add(MenuItem);

          MenuItem := CreateMenuItemForComponent(R);
          MenuItem.OnClick := @MenuItemAddComponentClick;
          MenuItemDesignAddTransform.Add(MenuItem);
        end;
      end;

    (*
    Don't show deprecated -- at least in initial CGE release, keep the menu clean.

    { add separators from deprecated }
    MenuItem := TMenuItem.Create(Self);
    MenuItem.Caption := '-';
    MenuItemDesignAddUserInterface.Add(MenuItem);

    MenuItem := TMenuItem.Create(Self);
    MenuItem.Caption := '-';
    MenuItemDesignAddTransform.Add(MenuItem);

    { add deprecated components }
    for R in RegisteredComponents do
      if R.IsDeprecated then
      begin
        if R.ComponentClass.InheritsFrom(TCastleUserInterface) and
           not R.ComponentClass.InheritsFrom(TCastleNavigation) then
        begin
          MenuItem := CreateMenuItemForComponent(R);
          MenuItem.OnClick := @MenuItemAddComponentClick;
          MenuItemDesignAddUserInterface.Add(MenuItem);
        end else
        if R.ComponentClass.InheritsFrom(TCastleTransform) then
        begin
          MenuItem := CreateMenuItemForComponent(R);
          MenuItem.OnClick := @MenuItemAddComponentClick;
          MenuItemDesignAddTransform.Add(MenuItem);
        end;
      end;
    *)
  end;

  { We create some components by code, this way we don't have to put
    in package TCastleShellTreeView and TCastleShellListView,
    making compiling CGE editor a bit easier. }
  procedure CreateShellViews;
  const
    { Similar to paths removed by build-tool "clean", or excluded by default by
      build-tool "package". This should be configurable some day. }
    ExcludeMask = 'castle-engine-output;*~;*.bak;*.exe;*.dll';
  begin
    ShellTreeView1 := TCastleShellTreeView.Create(Self);
    ShellTreeView1.Parent := TabFiles;
    ShellTreeView1.Width := MulDiv(250, PixelsPerInch, 96);
    ShellTreeView1.Align := alLeft;
    ShellTreeView1.FileSortType := fstAlphabet;
    ShellTreeView1.HotTrack := True;
    ShellTreeView1.ReadOnly := True;
    ShellTreeView1.ShowRoot := False;
    ShellTreeView1.TabOrder := 0;
    ShellTreeView1.Options := [tvoAutoItemHeight, tvoHideSelection, tvoHotTrack, tvoKeepCollapsedNodes, tvoReadOnly, tvoShowButtons, tvoShowLines, tvoToolTips, tvoThemedDraw];
    ShellTreeView1.ObjectTypes := [otFolders];
    ShellTreeView1.ExcludeMask := ExcludeMask;

    ShellListView1 := TCastleShellListView.Create(Self);
    ShellListView1.Parent := TabFiles;
    ShellListView1.Align := alClient;
    ShellListView1.ReadOnly := True;
    ShellListView1.SortColumn := 0;
    ShellListView1.TabOrder := 1;
    ShellListView1.ObjectTypes := [otNonFolders];
    // TODO: To make folders work nicely, it needs some more improvements:
    // - show icons of folders, to make them distinct
    // - double-click on folder should move to it, in both shell tree/list views
    //ShellListView1.ObjectTypes := [otNonFolders, otFolders];
    { Without this, files are in undefined order
      (it seems SortColumn=0 above doesn't work). }
    ShellListView1.FileSortType := fstFoldersFirst;
    ShellListView1.ExcludeMask := ExcludeMask;
    ShellListView1.OnDblClick := @ShellListViewDoubleClick;
    ShellListView1.ShowHint := true;
    ShellListView1.RowSelect := true;
    ShellListView1.OnSelectItem := @ShellListViewSelectItem;
    ShellListView1.Hint := 'Double-click to open.' + NL +
      NL +
      '- Scenes open in engine viewer (view3dscene).' + NL +
      '- Images open in engine viewer (castle-view-image).' + NL +
      '- Design opens in this editor window.' + NL +
      '- Pascal files open in Lazarus.' + NL +
      '- Other files open in external applications.';

    ShellTreeView1.ShellListView := ShellListView1;
    ShellListView1.ShellTreeView := ShellTreeView1;
  end;

begin
  OutputList := TOutputList.Create(ListOutput);
  BuildComponentsMenu;
  CreateShellViews;
  ApplicationProperties.OnWarning.Add(@WarningNotification);
end;

procedure TProjectForm.FormDestroy(Sender: TObject);
begin
  ApplicationProperties.OnWarning.Remove(@WarningNotification);
  ApplicationDataOverride := '';
  FreeProcess;
  FreeAndNil(OutputList);
end;

procedure TProjectForm.ListOutputClick(Sender: TObject);
begin
  // TODO: just to source code line in case of error message here
end;

procedure TProjectForm.MenuItemPreferencesClick(Sender: TObject);
begin
  PreferencesForm.ShowModal;
end;

procedure TProjectForm.MenuItemAutoGenerateCleanClick(Sender: TObject);
begin
  BuildToolCall(['auto-generate-clean']);
end;

procedure TProjectForm.MenuItemCleanClick(Sender: TObject);
begin
  BuildToolCall(['clean']);
end;

procedure TProjectForm.MenuItemCompileClick(Sender: TObject);
begin
  BuildToolCall(['compile']);
end;

procedure TProjectForm.MenuItemCompileRunClick(Sender: TObject);
begin
  if ProposeSaveDesign then
    BuildToolCall(['compile', 'run']);
end;

procedure TProjectForm.MenuItemCopyComponentClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise
  Design.CopyComponent;
end;

procedure TProjectForm.MenuItemDesignCloseClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise

  if ProposeSaveDesign then
  begin
    FreeAndNil(Design);
    DesignExistenceChanged;
  end;
end;

procedure TProjectForm.MenuItemDesignDeleteComponentClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise
  Design.DeleteComponent;
end;

procedure TProjectForm.MenuItemDuplicateComponentClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise
  Design.DuplicateComponent;
end;

procedure TProjectForm.MenuItemManualClick(Sender: TObject);
begin
  OpenURL('https://castle-engine.io/manual_intro.php');
end;

procedure TProjectForm.MenuItemModeDebugClick(Sender: TObject);
begin
  BuildMode := bmDebug;
  MenuItemModeDebug.Checked := true;
end;

procedure TProjectForm.DesignExistenceChanged;
begin
  MenuItemSaveAsDesign.Enabled := Design <> nil;
  MenuItemSaveDesign.Enabled := Design <> nil;
  MenuItemDesignClose.Enabled := Design <> nil;
  MenuItemDesignAddTransform.Enabled := Design <> nil;
  MenuItemDesignAddUserInterface.Enabled := Design <> nil;
  MenuItemDesignDeleteComponent.Enabled := Design <> nil;
  MenuItemCopyComponent.Enabled := Design <> nil;
  MenuItemPasteComponent.Enabled := Design <> nil;
  MenuItemDuplicateComponent.Enabled := Design <> nil;

  LabelNoDesign.Visible := Design = nil;
end;

procedure TProjectForm.NeedsDesignFrame;
begin
  if Design = nil then
  begin
    Design := TDesignFrame.Create(Self);
    Design.Parent := PanelAboveTabs;
    Design.Align := alClient;
    Design.OnUpdateFormCaption := @UpdateFormCaption;
    DesignExistenceChanged;
  end;
end;

procedure TProjectForm.WarningNotification(const Category,
  Message: string);
begin
  if Category <> '' then
    ListWarnings.Items.Add(Category + ': ' + Message)
  else
    ListWarnings.Items.Add(Message);
  TabWarnings.Caption := 'Warnings (' + IntToStr(ListWarnings.Count) + ')';
  TabWarnings.TabVisible := true;
end;

procedure TProjectForm.MenuItemDesignNewUserInterfaceRectClick(Sender: TObject);
begin
  if ProposeSaveDesign then
  begin
    NeedsDesignFrame;
    Design.NewDesign(TCastleUserInterface, nil);
  end;
end;

procedure TProjectForm.MenuItemDesignNewTransformClick(Sender: TObject);
begin
  if ProposeSaveDesign then
  begin
    NeedsDesignFrame;
    Design.NewDesign(TCastleTransform, nil);
  end;
end;

procedure TProjectForm.MenuItemOnlyRunClick(Sender: TObject);
begin
  if ProposeSaveDesign then
    BuildToolCall(['run']);
end;

procedure TProjectForm.MenuItemOpenDesignClick(Sender: TObject);
begin
  if ProposeSaveDesign then
  begin
    if Design <> nil then
      OpenDesignDialog.Url := Design.DesignUrl;
    if OpenDesignDialog.Execute then
    begin
      NeedsDesignFrame;
      Design.OpenDesign(OpenDesignDialog.Url);
    end;
  end;
end;

procedure TProjectForm.MenuItemPackageClick(Sender: TObject);
begin
  BuildToolCall(['package']);
end;

procedure TProjectForm.MenuItemPackageSourceClick(Sender: TObject);
begin
  BuildToolCall(['package-source']);
end;

procedure TProjectForm.MenuItemPasteComponentClick(Sender: TObject);
begin
  Assert(Design <> nil); // menu item is disabled otherwise
  Design.PasteComponent;
end;

procedure TProjectForm.MenuItemSwitchProjectClick(Sender: TObject);
begin
  if ProposeSaveDesign then
  begin
    Free; // do not call MenuItemDesignClose, to avoid OnCloseQuery
    ChooseProjectForm.Show;
  end;
end;

procedure TProjectForm.ProcessUpdateTimerTimer(Sender: TObject);
begin
  if RunningProcess <> nil then
  begin
    RunningProcess.Update;
    if not RunningProcess.Running then
      FreeProcess;
  end;
end;

procedure TProjectForm.FreeProcess;
begin
  FreeAndNil(RunningProcess);
  SetEnabledCommandRun(true);
  ProcessUpdateTimer.Enabled := false;
end;

procedure TProjectForm.ShellListViewSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);

  { Make sure ViewFileFrame is created and visible.
    For now we create ViewFileFrame on-demand, just in case there's a problem
    with initializing 2nd OpenGL context on some computer. }
  procedure NeedsViewFile;
  begin
    if ViewFileFrame = nil then
    begin
      ViewFileFrame := TViewFileFrame.Create(Self);
      ViewFileFrame.Parent := TabFiles;
      ViewFileFrame.Align := alRight;

      SplitterBetweenViewFile := TSplitter.Create(Self);
      SplitterBetweenViewFile.Parent := TabFiles;
      SplitterBetweenViewFile.Align := alRight;
    end;
    ViewFileFrame.Enabled := true;
    ViewFileFrame.Visible := true;
    SplitterBetweenViewFile.Enabled := true;
    SplitterBetweenViewFile.Visible := true;
  end;

var
  SelectedFileName, SelectedURL: String;
begin
  if ShellListView1.Selected <> nil then
  begin
    SelectedFileName := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    SelectedURL := FilenameToURISafe(SelectedFileName);

    if TFileFilterList.Matches(LoadScene_FileFilters, SelectedURL) then
    begin
      NeedsViewFile;
      ViewFileFrame.LoadScene(SelectedURL);
      Exit;
    end;

    if LoadImage_FileFilters.Matches(SelectedURL) then
    begin
      NeedsViewFile;
      ViewFileFrame.LoadImage(SelectedURL);
      Exit;
    end;

    if TFileFilterList.Matches(LoadSound_FileFilters, SelectedURL) then
    begin
      NeedsViewFile;
      ViewFileFrame.LoadSound(SelectedURL);
      Exit;
    end;
  end;

  { if control reached here, hide ViewFileFrame if needed }
  if ViewFileFrame <> nil then
  begin
    ViewFileFrame.ClearLoaded; // stops playing preview sound
    ViewFileFrame.Enabled := false;
    ViewFileFrame.Visible := false;
    SplitterBetweenViewFile.Enabled := false;
    SplitterBetweenViewFile.Visible := false;
  end;
end;

procedure TProjectForm.ShellListViewDoubleClick(Sender: TObject);

  procedure OpenWithCastleTool(const ToolName: String; const SelectedURL: String);
  var
    Exe: String;
  begin
    Exe := FindExeCastleTool(ToolName);
    if Exe = '' then
    begin
      EditorUtils.ErrorBox(Format('Cannot find Castle Game Engine tool "%s", opening "%s" failed. Make sure CGE is installed correctly, the tool should be distributed along with engine binary.',
        [ToolName, SelectedURL]));
      Exit;
    end;

    RunCommandNoWait(CreateTemporaryDir, Exe, [SelectedURL]);
  end;

  procedure OpenPascal(const FileName: String);
  var
    Exe: String;
  begin
    //if ProjectLazarus = '' then
    if ProjectStandaloneSource = '' then // see comments below, we use ProjectStandaloneSource
    begin
      //EditorUtils.ErrorBox('Cannot open project in Lazarus, as neither "standalone_source" nor "lazarus_project" were specified in CastleEngineManifest.xml.');
      EditorUtils.ErrorBox('Cannot open project in Lazarus, as "standalone_source" was not specified in CastleEngineManifest.xml.');
      Exit;
    end;

    try
      Exe := FindExeLazarusIDE;
    except
      on E: EExecutableNotFound do
      begin
        EditorUtils.ErrorBox(E.Message);
        Exit;
      end;
    end;

    { It would be cleaner to use LPI file, like this:

    // pass both project name, and particular filename, to open file within this project.
    RunCommandNoWait(CreateTemporaryDir, Exe, [ProjectLazarus, FileName]);

      But it doesn't work nicely: Lazarus asks for confirmation whether to open
      LPI as XML file, or a project.
      Instead opening LPR works better, i.e. just switches project (if necessary)
      to new one.
    }

    if SameFileName(ProjectStandaloneSource, FileName) then
      RunCommandNoWait(CreateTemporaryDir, Exe, [ProjectStandaloneSource])
    else
      { pass both project name, and particular filename, to open file within this project. }
      RunCommandNoWait(CreateTemporaryDir, Exe, [ProjectStandaloneSource, FileName]);
  end;

  procedure OpenLazarusProject(const FileName: String);
  var
    Exe: String;
  begin
    try
      Exe := FindExeLazarusIDE;
    except
      on E: EExecutableNotFound do
      begin
        EditorUtils.ErrorBox(E.Message);
        Exit;
      end;
    end;

    RunCommandNoWait(CreateTemporaryDir, Exe, [FileName]);
  end;

var
  SelectedFileName, Ext, SelectedURL: String;
begin
  if ShellListView1.Selected <> nil then
  begin
    SelectedFileName := ShellListView1.GetPathFromItem(ShellListView1.Selected);
    SelectedURL := FilenameToURISafe(SelectedFileName);
    Ext := ExtractFileExt(SelectedFileName);

    if TFileFilterList.Matches(LoadScene_FileFilters, SelectedURL) then
    begin
      OpenWithCastleTool('view3dscene', SelectedURL);
      Exit;
    end;

    if LoadImage_FileFilters.Matches(SelectedURL) then
    begin
      OpenWithCastleTool('castle-view-image', SelectedURL);
      Exit;
    end;

    if AnsiSameText(Ext, '.castle-user-interface') or
       AnsiSameText(Ext, '.castle-transform') then
    begin
      if ProposeSaveDesign then
      begin
        NeedsDesignFrame;
        Design.OpenDesign(SelectedURL);
      end;
      Exit;
    end;

    if AnsiSameText(Ext, '.pas') or
       AnsiSameText(Ext, '.inc') or
       AnsiSameText(Ext, '.pp') or
       AnsiSameText(Ext, '.lpr') or
       AnsiSameText(Ext, '.dpr') then
    begin
      OpenPascal(SelectedFileName);
      Exit;
    end;

    if AnsiSameText(Ext, '.lpi') then
    begin
      OpenLazarusProject(SelectedFileName);
      Exit;
    end;

    if not OpenDocument(SelectedFileName) then
      EditorUtils.ErrorBox(Format('Opening "%s" failed.', [SelectedFileName]));
  end;
end;

procedure TProjectForm.BuildToolCall(const Commands: array of String;
  const ExitOnSuccess: Boolean);
var
  BuildToolExe, ModeString, Command: String;
  QueueItem: TAsynchronousProcessQueue.TQueueItem;
begin
  if RunningProcess <> nil then
    raise EInternalError.Create('It should not be possible to call this when RunningProcess <> nil');

  BuildToolExe := FindExeCastleTool('castle-engine');
  if BuildToolExe = '' then
  begin
    EditorUtils.ErrorBox('Cannot find build tool (castle-engine) on $PATH environment variable.');
    Exit;
  end;

  case BuildMode of
    bmDebug  : ModeString := '--mode=debug';
    bmRelease: ModeString := '--mode=release';
    else raise EInternalError.Create('BuildMode?');
  end;

  SetEnabledCommandRun(false);
  OutputList.Clear;
  PageControlBottom.ActivePage := TabOutput;
  ProcessUpdateTimer.Enabled := true;

  RunningProcess := TAsynchronousProcessQueue.Create;
  RunningProcess.OutputList := OutputList;

  for Command in Commands do
  begin
    QueueItem := TAsynchronousProcessQueue.TQueueItem.Create;
    QueueItem.ExeName := BuildToolExe;
    QueueItem.CurrentDirectory := ProjectPath;
    QueueItem.Parameters.Add(ModeString);
    QueueItem.Parameters.Add(Command);
    RunningProcess.Queue.Add(QueueItem);
  end;

  if ExitOnSuccess then
    RunningProcess.OnSuccessfullyFinishedAll := @MenuItemQuitClick;

  RunningProcess.Start;
end;

procedure TProjectForm.MenuItemAddComponentClick(Sender: TObject);
var
  R: TRegisteredComponent;
begin
  R := TRegisteredComponent(Pointer((Sender as TComponent).Tag));
  Design.AddComponent(R.ComponentClass, R.OnCreate);
end;

procedure TProjectForm.MenuItemDesignNewCustomRootClick(Sender: TObject);
var
  R: TRegisteredComponent;
begin
  if ProposeSaveDesign then
  begin
    R := TRegisteredComponent(Pointer((Sender as TComponent).Tag));
    NeedsDesignFrame;
    Design.NewDesign(R.ComponentClass, R.OnCreate);
  end;
end;

procedure TProjectForm.SetEnabledCommandRun(const AEnabled: Boolean);
begin
  MenuItemCompile.Enabled := AEnabled;
  MenuItemCompileRun.Enabled := AEnabled;
  MenuItemOnlyRun.Enabled := AEnabled;
  MenuItemClean.Enabled := AEnabled;
  MenuItemPackage.Enabled := AEnabled;
  MenuItemPackageSource.Enabled := AEnabled;
  MenuItemAutoGenerateTextures.Enabled := AEnabled;
  MenuItemAutoGenerateClean.Enabled := AEnabled;
  MenuItemBreakProcess.Enabled := not AEnabled;
end;

procedure TProjectForm.UpdateFormCaption(Sender: TObject);
var
  S: String;
begin
  if Design <> nil then
    S := Design.FormCaption
  else
    S := '';
  S := S + SQuoteLCLCaption(ProjectName);
  if InternalHasCustomComponents then
    S := S + ' (With Custom Components)';
  Caption := S + ' | Castle Game Engine';
end;

function TProjectForm.ProposeSaveDesign: Boolean;
var
  Mr: TModalResult;
  DesignName: String;
begin
  Result := true;

  if Design <> nil then
  begin
    Design.BeforeProposeSaveDesign;
    if Design.DesignModified then
    begin
      if Design.DesignUrl <> '' then
        DesignName := '"' + Design.DesignUrl + '"'
      else
        DesignName := '<unnnamed>';
      Mr := MessageDlg('Save Design',
        'Design ' + DesignName + ' was modified but not saved yet. Save it now?',
        mtConfirmation, mbYesNoCancel, 0);
      case Mr of
        mrYes: MenuItemSaveDesign.Click;
        mrCancel: Result := false;
      end;
    end;
  end;
end;

procedure TProjectForm.OpenProject(const ManifestUrl: String);
var
  ManifestDoc: TXMLDocument;
  DefaultLazarusProject: String;
begin
  ManifestDoc := URLReadXML(ManifestUrl);
  try
    ProjectName := ManifestDoc.DocumentElement.AttributeString('name');
    if not ManifestDoc.DocumentElement.AttributeString(
      'standalone_source', ProjectStandaloneSource) then
      ProjectStandaloneSource := '';

    if ProjectStandaloneSource <> '' then
      DefaultLazarusProject := ChangeFileExt(ProjectStandaloneSource, '.lpi')
    else
      DefaultLazarusProject := '';
    ProjectLazarus := ManifestDoc.DocumentElement.AttributeStringDef(
      'lazarus_project', DefaultLazarusProject);
    if (ManifestDoc.DocumentElement.AttributeStringDef('editor_units', '') <> '') and
       (not InternalHasCustomComponents) then
      WritelnWarning('Project uses custom components (declares editor_units in CastleEngineManifest.xml), but this is not a custom editor build.' + NL + 'Use the menu item "Project -> Restart Editor (With Custom Components)" to build and run correct editor.');
  finally FreeAndNil(ManifestDoc) end;

  { Below we assume ManifestUrl contains an absolute path,
    otherwise ProjectPathUrl could be '',
    and OpenDesignDialog.InitialDir would be left '' and so on. }
  ProjectPathUrl := ExtractURIPath(ManifestUrl);
  ProjectPath := URIToFilenameSafe(ProjectPathUrl);

  { Make some fields absolute paths, or empty }
  if ProjectStandaloneSource <> '' then
    ProjectStandaloneSource := CombinePaths(ProjectPath, ProjectStandaloneSource);
  if ProjectLazarus <> '' then
    ProjectLazarus := CombinePaths(ProjectPath, ProjectLazarus);

  { override ApplicationData interpretation, and castle-data:/xxx URL,
    while this project is open. }
  ApplicationDataOverride := CombineURI(ProjectPathUrl, 'data/');
  OpenDesignDialog.InitialDir := URIToFilenameSafe(ApplicationDataOverride);
  SaveDesignDialog.InitialDir := URIToFilenameSafe(ApplicationDataOverride);

  ShellTreeView1.Root := ProjectPath;

  // It's too easy to change it visually and forget, so we set it from code
  PageControlBottom.ActivePage := TabFiles;
  SetEnabledCommandRun(true);

  BuildMode := bmDebug;
  MenuItemModeDebug.Checked := true;

  DesignExistenceChanged;
  UpdateFormCaption(nil); // make form Caption reflect project name
end;

initialization
  // initialize CGE log
  ApplicationProperties.ApplicationName := 'castle-editor';
  InitializeLog;
end.
