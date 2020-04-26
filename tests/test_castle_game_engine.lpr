program test_castle_game_engine;

{ Define this if you use text runner for our tests.
  Usually this is automatically defined by calling compile_console.sh. }
{ $define TEXT_RUNNER}

{ Define this to disable any GUI tests (using CastleWindow).
  The CastleWindow
  - Conflicts with LCL windows (so it can be used only when TEXT_RUNNER,
    otherwise we use a runner that shows output in LCL window).
  - Can work only when graphical window system (like X on Unix)
    is available (e.g. not inside non-X ssh session, or cron).
}
{ $define NO_WINDOW_SYSTEM}

{$mode objfpc}{$H+}

uses
  {$ifdef TEXT_RUNNER}
  CastleConsoleTestRunner, ConsoleTestRunner,
  {$else}
  Interfaces, Forms, GuiTestRunner, castle_base,
  {$endif}

  CastleLog, CastleApplicationProperties,

  { Test units below. Their order determines default tests order. }

  { Testing (mainly) things inside FPC standard library, not CGE }
  TestCompiler,
  TestSysUtils,
  { For some reason, testing FGL with FPC 3.3.1 fails with:

      Marked memory at $00007F65B6276C60 invalid
      Wrong signature $2071BAA5 instead of 243D6DCB
        $00000000004CB2C0

      FPC rev 40000, Linux/x86_64.
      Also: FPC rev 41505, Windows/x86_64.
      Once the backtrace pointed to DEREF,  line 1028 of fgl.pp .
  }
  {$ifdef VER3_0}
  TestFGL,
  {$endif}
  TestGenericsCollections,
  TestOldFPCBugs,
  TestFPImage,

  { Testing CGE units }
  TestCastleUtils,
  TestCastleRectangles,
  TestCastleGenericLists,
  TestCastleFilesUtils,
  TestCastleUtilsLists,
  TestCastleClassUtils,
  TestCastleVectors,
  TestCastleTriangles,
  TestCastleColors,
  TestCastleQuaternions,
  TestCastleKeysMouse,
  TestCastleImages,
  TestCastleImagesDraw,
  TestCastleBoxes,
  TestCastleFrustum,
  TestCastleFonts,
  TestCastleTransform,
  TestCastleParameters,
  TestCastleUIControls,
  TestCastleCameras,
  TestX3DFields,
  TestX3DNodes,
  TestX3DNodesOptimizedProxy,
  TestCastleScene,
  TestCastleSceneCore,
  TestCastleSceneManager,
  TestCastleVideos,
  TestCastleSpaceFillingCurves,
  TestCastleStringUtils,
  TestCastleScript,
  TestCastleScriptVectors,
  TestCastleCubeMaps,
  TestCastleGLVersion,
  TestCastleCompositeImage,
  TestCastleTriangulate,
  TestCastleGame,
  TestCastleURIUtils,
  TestCastleXMLUtils,
  TestCastleCurves,
  TestCastleTimeUtils,
  TestCastleControls,
  TestCastleRandom,
  TestCastleSoundEngine,
  TestCastleComponentSerialize,
  TestX3DLoadInternalUtils,
  TestCastleLevels,
  TestCastleDownload

  {$ifdef TEXT_RUNNER} {$ifndef NO_WINDOW_SYSTEM},
  TestCastleWindow,
  TestCastleOpeningAndRendering3D,
  TestCastleWindowOpen
  {$endif} {$endif}

  { Stuff requiring Lazarus LCL. }
  {$ifndef TEXT_RUNNER},
  TestCastleLCLUtils
  {$endif};

{$ifdef TEXT_RUNNER}
var
  Application: TCastleConsoleTestRunner;
{$endif}

{var
  T: TTestCastleTransform;}
begin
  // InitializeLog;

  ApplicationProperties.OnWarning.Add(@ApplicationProperties.WriteWarningOnConsole);
  // avoid warnings that opening files too early
  ApplicationProperties._FileAccessSafe := true;

{ Sometimes it's comfortable to just run the test directly, to get
  full backtrace from FPC.

  T := TTestCastleTransform.Create;
  T.TestPhysicsWorldOwnerEmptyBox;
  T.Free;
  Exit;}

  {$ifdef TEXT_RUNNER}
  Application := TCastleConsoleTestRunner.Create(nil);
  Application.Title := 'Castle Game Engine test runner (using fpcunit)';
  DefaultFormat := fPlain;
  {$endif}
  Application.Initialize;
  {$ifndef TEXT_RUNNER}
  Application.CreateForm(TGuiTestRunner, TestRunner);
  {$endif}
  Application.Run;
  {$ifdef TEXT_RUNNER}
  Application.Free;
  {$endif}
end.
