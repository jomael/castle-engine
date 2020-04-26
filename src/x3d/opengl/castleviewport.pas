{
  Copyright 2009-2019 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Viewport to display scenes (TCastleViewport). }
unit CastleViewport;

{$I castleconf.inc}

interface

uses SysUtils, Classes, Generics.Collections,
  {$ifdef CASTLE_OBJFPC} CastleGL, {$else} GL, GLExt, {$endif}
  CastleVectors, X3DNodes, X3DTriangles, CastleScene, CastleSceneCore, CastleCameras,
  CastleInternalGLShadowVolumes, CastleUIControls, CastleTransform, CastleTriangles,
  CastleKeysMouse, CastleBoxes, CastleInternalBackground, CastleUtils, CastleClassUtils,
  CastleGLShaders, CastleGLImages, CastleTimeUtils,
  CastleInputs, CastleRectangles, CastleColors,
  CastleProjection, CastleScreenEffects;

type
  TCastleViewport = class;
  TCastleSceneManager = class;

  TRender3DEvent = procedure (Viewport: TCastleViewport;
    const Params: TRenderParams) of object;

  { Internal, special TRenderParams descendant that can return different
    set of base lights for some scenes. Used to implement GlobalLights,
    where MainScene and other objects need different lights.
    @exclude. }
  TManagerRenderParams = class(TRenderParams)
  private
    MainScene: TCastleTransform;
    FBaseLights: array [boolean { is main scene }] of TLightInstancesList;
  public
    constructor Create;
    destructor Destroy; override;
    function BaseLights(Scene: TCastleTransform): TAbstractLightInstancesList; override;
  end;

  { Event for @link(TCastleViewport.OnProjection). }
  TProjectionEvent = procedure (var Parameters: TProjection) of object;

  { Viewport displays a tree of scenes and transformations
    (TCastleTransform and TCastleScene).
    Add the scenes and transformations to @link(Items).

    For some features, that require a notion of "main" scene,
    it is useful to set @link(TCastleRootTransform.MainScene Items.MainScene).
    See the @link(TCastleRootTransform.MainScene) docs.

    Each viewport has a @link(Camera) with a position and orientation.
    The initial camera may be auto-detected if @link(AutoCamera).

    Viewport may also have a @link(Navigation) that allows to move
    camera by keyboard, mouse and other inputs.
    You can use TCastleExamineNavigation or TCastleWalkNavigation instances.
    You can also implement your own navigation method
    (as a TCastleNavigation descendant,
    or just move/rotate the camera by calling @link(TCastleCamera.SetView) from anywhere).
    The inital navigation method may be auto-detected if @link(AutoNavigation).

    Viewport may clear the screen at the beginning,
    with a solid color or using a TAbstractBackgroundNode defined in
    @link(TCastleRootTransform.MainScene Items.MainScene).
    This way you can use e.g. a skybox.
    You can control this using @link(Transparent), @link(BackgroundColor) properties.

    Viewport may also add headlight to the scene,
    see @link(TCastleRootTransform.UseHeadlight Items.UseHeadlight).

    Multiple viewports can display the same world.
    To do this, simply copy @link(Items) reference from one
    TCastleViewport to another. You can also just create your own @link(TCastleRootTransform)
    instance and then assign it to multiple viewports.
    This allows e.g. to make a split-screen game (played by 2 people,
    with 2 viewports, on a single monitor).
    Or you can show in a 3D FPS game an additional view from some security camera,
    or from a flying rocket.
    For examples of using multiple viewports see:

    @unorderedList(
      @item(Explanation with an example:
        https://castle-engine.io/manual_2d_user_interface.php#section_viewport)
      @item(Example in engine sources: examples/3d_rendering_processing/multiple_viewports.lpr)
      @item(Example in engine sources: examples/fps_game/)
    )
  }
  TCastleViewport = class(TCastleScreenEffects)
  strict private
    type
      TSSAOScreenEffect = class(TGLSLScreenEffect)
        Viewport: TCastleViewport;
        function SetupUniforms(var BoundTextureUnits: Cardinal): Boolean; override;
      end;
    var
      FCamera: TCastleCamera;
      FRenderParams: TManagerRenderParams;
      FPrepareParams: TPrepareParams;
      FBackgroundWireframe: boolean;
      FBackgroundColor: TCastleColor;
      FOnRender3D: TRender3DEvent;
      FUseGlobalLights, FUseGlobalFog: boolean;
      FApproximateActivation: boolean;
      FDefaultVisibilityLimit: Single;
      FTransparent, FClearDepth: boolean;
      FInternalExamineNavigation: TCastleExamineNavigation;
      FInternalWalkNavigation: TCastleWalkNavigation;
      FWithinSetNavigationType: boolean;
      LastPressEvent: TInputPressRelease;
      FOnProjection: TProjectionEvent;
      FEnableParentDragging: boolean;
      AssignDefaultCameraDone: Boolean;
      FAutoCamera: Boolean;
      FAutoNavigation: Boolean;

      FShadowVolumes: boolean;
      FShadowVolumesRender: boolean;

      FScreenSpaceAmbientOcclusion: boolean;
      SSAOShader: TSSAOScreenEffect;
      SSAOShaderInitialized: Boolean;

      FOnCameraChanged: TNotifyEvent;
      { Renderer of shadow volumes. You can use this to optimize rendering
        of your shadow quads in RenderShadowVolume, and you can read
        it's statistics (TGLShadowVolumeRenderer.Count and related properties).

        @nil when OpenGL context is not yet initialized. }
      FShadowVolumeRenderer: TGLShadowVolumeRenderer;
      FItems: TCastleRootTransform;
      ScheduledVisibleChangeNotification: boolean;
      ScheduledVisibleChangeNotificationChanges: TVisibleChanges;

      FOnBoundViewpointChanged, FOnBoundNavigationInfoChanged: TNotifyEvent;
      FMouseRayHit: TRayCollision;
      FAvoidNavigationCollisions: TCastleTransform;
      PrepareResourcesDone: Boolean;
      FPreventInfiniteFallingDown: Boolean;

    function FillsWholeContainer: boolean;
    function IsStoredNavigation: Boolean;
    procedure SetScreenSpaceAmbientOcclusion(const Value: boolean);
    procedure SSAOShaderInitialize;
    function GetNavigationType: TNavigationType;
    procedure SetAutoCamera(const Value: Boolean);
    { Make sure to call AssignDefaultCamera, if needed because of AutoCamera. }
    procedure EnsureCameraDetected;
    procedure SetItems(const Value: TCastleRootTransform);
    function GetPaused: Boolean;
    procedure SetPaused(const Value: Boolean);

    { Callbacks when MainCamera is notified that MainScene changes camera/navigation }
    procedure MainSceneAndCamera_BoundViewpointChanged(Sender: TObject);
    procedure MainSceneAndCamera_BoundViewpointVectorsChanged(Sender: TObject);
    procedure MainSceneAndCamera_BoundNavigationInfoChanged(Sender: TObject);

    procedure SetMouseRayHit(const Value: TRayCollision);
    function MouseRayHitContains(const Item: TCastleTransform): boolean;
    procedure SetAvoidNavigationCollisions(const Value: TCastleTransform);
    procedure SetNavigationType(const Value: TNavigationType);

    { Handle navigation events by checking collisions with @link(Items).
      @groupBegin }
    function NavigationMoveAllowed(ANavigation: TCastleWalkNavigation;
      const ProposedNewPos: TVector3; out NewPos: TVector3;
      const BecauseOfGravity: boolean): boolean;
    function NavigationHeight(ANavigation: TCastleWalkNavigation; const Position: TVector3;
      out AboveHeight: Single; out AboveGround: PTriangle): boolean;
    { @groupEnd }

    procedure SetNavigation(const Value: TCastleNavigation);
    function CameraRayCollision(const RayOrigin, RayDirection: TVector3): TRayCollision;
    procedure SetSceneManager(const Value: TCastleSceneManager);
  private
    var
      FNavigation: TCastleNavigation;
      FProjection: TProjection;
      FSceneManager: TCastleSceneManager;

    class procedure CreateComponentSetup2D(Sender: TObject);

    procedure RecalculateCursor(Sender: TObject);
    function ItemsBoundingBox: TBox3D;

    { Set the projection parameters and matrix.
      Used by our Render method.

      This cooperates closely with current @link(Camera) definition.

      If AutoCamera then the initial and current @link(Camera) vectors
      are also initialized here (see TCastleCamera.Init
      and @link(AssignDefaultCamera).
      If AutoNavigation then the @link(Navigation) is automatically created here,
      see @link(AssignDefaultNavigation).

      This takes care to always update Camera.ProjectionMatrix,
      Projection, MainScene.BackgroundSkySphereRadius. }
    procedure ApplyProjection;
    procedure ItemsVisibleChange(const Sender: TCastleTransform; const Changes: TVisibleChanges);

    { What changes happen when camera changes.
      You may want to use it when calling Scene.CameraChanged. }
    function CameraToChanges(const ACamera: TCastleCamera): TVisibleChanges;

    { Render shadow quads for all the things rendered by @link(Render3D).
      You can use here ShadowVolumeRenderer instance, which is guaranteed
      to be initialized with TGLShadowVolumeRenderer.InitFrustumAndLight,
      so you can do shadow volumes culling. }
    procedure RenderShadowVolume;

    { Detect position/direction of the main light that produces shadows.
      The default implementation in this class looks at
      MainScene.MainLightForShadows.

      @seealso TCastleSceneCore.MainLightForShadows }
    function MainLightForShadows(
      out AMainLightPosition: TVector4): boolean;

    { Pass pointing device (mouse) activation/deactivation event to 3D world. }
    function PointingDeviceActivate(const Active: boolean): boolean;

    { Pass pointing device (mouse) move event to 3D world. }
    function PointingDeviceMove(const RayOrigin, RayDirection: TVector3): boolean;
  protected
    { Calculate projection parameters. Determines if the view is perspective
      or orthogonal and exact field of view parameters.
      Called each time at the beginning of rendering.

      The default implementation of this method in TCastleViewport
      calculates projection based on the @link(Camera) parameters.

      In turn, the @link(Camera) parameters may be automatically
      calculated (if @link(AutoCamera))
      based on the nodes in the @link(TCastleRootTransform.MainScene).
      Nodes like TViewpointNode or TOrthoViewpointNode or TNavigationInfoNode
      determine the default camera and projection details.

      You can override this method, or assign the @link(OnProjection) event
      to adjust the projection settings.
      But please note: instead of overriding this method,
      it's usually easier (and more advised) to simply change the @link(Camera) properties,
      like @link(TCastleCamera.ProjectionType Camera.ProjectionType)
      or @link(TCastleOrthographic.Width Camera.Orthographic.Width)
      or @link(TCastlePerspective.FieldOfView Camera.Perspective.FieldOfView). }
    function CalculateProjection: TProjection; virtual;

    { Prepare lights shining on everything.
      BaseLights contents should be initialized here.

      The implementation in this class adds headlight determined
      by the @link(Headlight) method. By default, this looks at the MainScene,
      and follows NavigationInfo.headlight and
      KambiNavigationInfo.headlightNode properties. }
    procedure InitializeLights(const Lights: TLightInstancesList); virtual;

    { Render everything from given camera view (as TRenderingCamera).
      Given RenderingCamera.Target says to where we generate the image.
      This method must take care of making many rendering passes
      for shadow volumes, but doesn't take care of updating generated textures. }
    procedure RenderFromViewEverything(const RenderingCamera: TRenderingCamera); virtual;

    { Render the scene, assuming that buffers were already cleared and background
      was rendered. Called by RenderFromViewEverything at the end.
      Lights are calculated in Params at this point.

      This will change Params.Transparent, Params.InShadow and Params.ShadowVolumesReceivers
      as needed. Their previous values do not matter. }
    procedure RenderFromView3D(const Params: TRenderParams); virtual;

    { The background used during rendering.
      @nil if no background should be rendered.

      The default implementation in this class does what is usually
      most natural: return MainScene.InternalBackground, if MainScene assigned. }
    function Background: TBackground; virtual;

    { Render one pass, with current camera and parameters (e.g. only transparent
      or only opaque shapes).
      All current camera settings are saved in RenderParams.RenderingCamera.
      @param(Params Rendering parameters, see @link(TRenderParams).) }
    procedure Render3D(const Params: TRenderParams); virtual;

    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    function GetScreenEffects(const Index: Integer): TGLSLProgram; virtual;

    function InternalExtraGetScreenEffects(const Index: Integer): TGLSLProgram; override;
    function InternalExtraScreenEffectsCount: Integer; override;
    function InternalExtraScreenEffectsNeedDepth: Boolean; override;

    { Called when PointingDeviceActivate was not handled by any 3D object.
      You can override this to make a message / sound signal to notify user
      that his Input_Interact click was not successful. }
    procedure PointingDeviceActivateFailed(const Active: boolean); virtual;

    { Handle pointing device (mouse) activation/deactivation event over a given 3D
      object. See TCastleTransform.PointingDeviceActivate method for description how it
      should be handled. Default implementation in TCastleViewport
      just calls TCastleTransform.PointingDeviceActivate. }
    function PointingDeviceActivate3D(const Item: TCastleTransform; const Active: boolean;
      const Distance: Single): boolean; virtual;

    procedure BoundNavigationInfoChanged; virtual;
    procedure BoundViewpointChanged; virtual;

    procedure RenderWithoutScreenEffects; override;
  public
    const
      DefaultScreenSpaceAmbientOcclusion = false;
      DefaultUseGlobalLights = true;
      DefaultUseGlobalFog = true;
      DefaultShadowVolumes = true;
      DefaultBackgroundColor: TVector4 = (Data: (0.1, 0.1, 0.1, 1));
      Default2DProjectionFar = 1000.0;
      Default2DCameraZ = Default2DProjectionFar / 2;
      DefaultPrepareOptions = [prRenderSelf, prRenderClones, prBackground, prBoundingBox, prScreenEffects];

    var
      { Rendering pass, for user purposes.
        Useful to keep shaders cached when you render the same scene multiple times
        in the same frame (under different lighting conditions or other things
        that change shaders).
        By default this is always 0, the engine doesn't modify this.
        You can set this field manually. }
      CustomRenderingPass: TUserRenderingPass;

      { Set these to non-1 to deliberately distort field of view / aspect ratio.
        This is useful for special effects when you want to create unrealistic
        projection.
        @exclude }
      InternalDistortFieldOfViewY, InternalDistortViewAspect: Single;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function AllowSuspendForInput: boolean; override;
    function Press(const Event: TInputPressRelease): boolean; override;
    function Release(const Event: TInputPressRelease): boolean; override;
    function Motion(const Event: TInputMotion): boolean; override;
    procedure Update(const SecondsPassed: Single;
      var HandleInput: boolean); override;
    procedure VisibleChange(const Changes: TCastleUserInterfaceChanges;
      const ChangeInitiatedByChildren: boolean = false); override;
    procedure BeforeRender; override;

    function GetMainScene: TCastleScene; deprecated 'use Items.MainScene';

    { Update MouseHitRay and update Items (TCastleTransform hierarchy) knowledge
      about the current pointing device.
      You usually don't need to call this, as it is done at every mouse move. }
    procedure UpdateMouseRayHit;

    { Current projection parameters,
      calculated by last @link(CalculateProjection) call,
      adjusted by @link(OnProjection).
      @bold(This is read only). To change the projection parameters,
      override @link(CalculateProjection) or handle event @link(OnProjection). }
    property Projection: TProjection read FProjection;
      deprecated 'in most cases, you can instead read Camera parameters, like Camera.Orthographic.EffectiveWidth, Camera.Orthographic.EffectiveHeight';

    { Return current navigation. Automatically creates it if missing. }
    function RequiredNavigation: TCastleNavigation; deprecated 'use Camera to set camera properties; if you require Navigation to be <> nil, just create own instance of TCastleWalkNavigation/TCastleExamineNavigation and assign it, or call AssignDefaultNavigation';
    function RequiredCamera: TCastleNavigation; deprecated 'use Camera to set camera properties; if you require Navigation to be <> nil, just create own instance of TCastleWalkNavigation/TCastleExamineNavigation and assign it, or call AssignDefaultNavigation';

    { Return the currently used camera as TCastleWalkNavigation, making sure that current
      NavigationType is something using TCastleWalkNavigation.

      @unorderedList(
        @item(
          When SwitchNavigationTypeIfNeeded is @true (the default),
          this method makes sure that the @link(NavigationType) corresponds to a type
          handled by TCastleWalkNavigation, creating and adjusting the camera if necessary.

          If the current NavigationType does not use TCastleWalkNavigation
          (see @link(TNavigationType) documentation for information which
          navigation types use which TCastleNavigation descendants),
          then it's switched to ntWalk.
        )

        @item(
          When SwitchNavigationTypeIfNeeded is @false,
          then we return @nil if the current camera is not already
          a TCastleWalkNavigation instance.

          We @italic(never) create a new camera in this case
          (even if the NavigatinInfo node in MainScene would indicate
          that the new camera would be a TCastleWalkNavigation).
        )
      )
    }
    function WalkNavigation(const SwitchNavigationTypeIfNeeded: boolean = true): TCastleWalkNavigation;
      deprecated 'create own instance of TCastleWalkNavigation, and assign it to Viewport.Navigation, this is more flexible and predictable';
    function WalkCamera(const SwitchNavigationTypeIfNeeded: boolean = true): TCastleWalkNavigation;
      deprecated 'create own instance of TCastleWalkNavigation, and assign it to Viewport.Navigation, this is more flexible and predictable';

    { Return the currently used camera as TCastleExamineNavigation, making sure that current
      NavigationType is something using TCastleExamineNavigation.

      @unorderedList(
        @item(
          When SwitchNavigationTypeIfNeeded is @true (the default),
          this method makes sure that the @link(NavigationType) corresponds to a type
          handled by TCastleExamineNavigation, creating and adjusting the camera if necessary.

          If the current NavigationType does not use TCastleExamineNavigation
          (see @link(TNavigationType) documentation for information which
          navigation types use which TCastleNavigation descendants),
          then it's switched to ntExamine.
        )

        @item(
          When SwitchNavigationTypeIfNeeded is @false,
          then we return @nil if the current camera is not already
          a TCastleExamineNavigation instance.

          We @italic(never) create a new camera in this case
          (even if the NavigatinInfo node in MainScene would indicate
          that the new camera would be a TCastleExamineNavigation).
        )
      )
    }
    function ExamineNavigation(const SwitchNavigationTypeIfNeeded: boolean = true): TCastleExamineNavigation;
      deprecated 'create own instance of TCastleExamineNavigation, and assign it to Viewport.Navigation, this is more flexible and predictable';
    function ExamineCamera(const SwitchNavigationTypeIfNeeded: boolean = true): TCastleExamineNavigation;
      deprecated 'create own instance of TCastleExamineNavigation, and assign it to Viewport.Navigation, this is more flexible and predictable';

    { Make @link(Navigation) @nil.
      The actual creation may be caused by calling
      @link(ExamineCamera), @link(WalkCamera),
      @link(InternalExamineCamera), @link(InternalWalkCamera),
      or by setting @link(NavigationType).

      In all cases, these methods will create a new camera instance
      after a @name call. No previous cached camera instance will be used. }
    procedure ClearCameras; deprecated 'just set Navigation to nil instead of using this method; to avoid reusing previous instance, do not use WalkNavigation/ExamineNavigation methods, instead create and destroy your own TCastleWalkNavigation/TCastleExamineNavigation whenever you want';

    { Camera instances used by this scene manager.
      Using these methods automatically creates these instances
      (so they are never @nil).

      Using these methods @italic(does not) make these
      camera instances current (in contast to calling @link(ExamineCamera),
      @link(WalkCamera) or setting @link(NavigationType)).

      When you switch navigation types by calling @link(ExamineCamera),
      @link(WalkCamera) or setting @link(NavigationType)
      the scene manager keeps using these instances of cameras,
      instead of creating new camera instances.
      This way all the camera properties
      (not only those copied by TCastleNavigation.Assign) are preserved when you switch
      e.g. NavigationType from ntWalk to ntExamine to ntWalk again.

      @deprecated This is deprecated now, because it causes auto-detection
      of navigation parameters, which is (in general) more surprising than helpful.
      E.g. it adjusts camera radius, speed and more properties.

      @groupBegin }
    function InternalExamineNavigation: TCastleExamineNavigation;
      deprecated 'create own instance of TCastleExamineNavigation instead of using this one, it results in more obvious code';
    function InternalWalkNavigation: TCastleWalkNavigation;
      deprecated 'create own instance of TCastleWalkNavigation instead of using this one, it results in more obvious code';
    function InternalExamineCamera: TCastleExamineNavigation; deprecated 'use InternalExamineNavigation';
    function InternalWalkCamera: TCastleWalkNavigation; deprecated 'use InternalWalkNavigation';
    { @groupEnd }

    { Assign @link(Navigation) to a default TCastleNavigation suitable
      for navigating in this scene.

      This is automatically used when @link(Navigation) is @nil
      and @link(AutoNavigation).
      You can also use it explicitly.

      The implementation in base TCastleViewport uses
      @link(TCastleSceneCore.NavigationTypeFromNavigationInfo MainScene.NavigationTypeFromNavigationInfo)
      and
      @link(TCastleSceneCore.InternalUpdateNavigation MainScene.InternalUpdateNavigation),
      thus it follows your X3D scene NavigationInfo.
      If MainScene is not assigned, we create a simple
      navigation in Examine mode. }
    procedure AssignDefaultNavigation; virtual;

    { Assign initial and current camera vectors and projection.

      This is automatically used at first rendering if @link(AutoCamera).
      You can also use it explicitly. }
    procedure AssignDefaultCamera; virtual;

    { Screen effects are shaders that post-process the rendered screen.
      If any screen effects are active, we will automatically render
      screen to a temporary texture, processing it with
      each shader.

      By default, screen effects come from MainScene.ScreenEffects,
      so the effects may be defined by VRML/X3D author using ScreenEffect
      nodes (see docs: [https://castle-engine.io/x3d_extensions_screen_effects.php]).
      Descendants may override GetScreenEffects, ScreenEffectsCount,
      and ScreenEffectsNeedDepth to add screen effects by code.
      Each viewport may have it's own, different screen effects.

      @groupBegin }
    property ScreenEffects [Index: Integer]: TGLSLProgram read GetScreenEffects;
    function ScreenEffectsCount: Integer; virtual;
    function ScreenEffectsNeedDepth: boolean; virtual;
    { @groupEnd }

    { Does the graphic card support our ScreenSpaceAmbientOcclusion shader.
      This does @italic(not) depend on the current state of
      ScreenSpaceAmbientOcclusion property.
      You can use it e.g. to disable the menu item to switch SSAO in 3D viewer. }
    function ScreenSpaceAmbientOcclusionAvailable: boolean;

    procedure GLContextOpen; override;
    procedure GLContextClose; override;

    { Parameters to prepare items that are to be rendered
      within this world. This should be passed to
      @link(TCastleTransform.PrepareResources).

      Note: Instead of using @link(TCastleTransform.PrepareResources),
      and this method,
      it's usually easier to call @link(TCastleViewport.PrepareResources).
      Then the appropriate TPrepareParams will be passed automatically. }
    function PrepareParams: TPrepareParams;

    function BaseLights: TLightInstancesList; deprecated 'this is internal info, you should not need this; use PrepareParams to get opaque information to pass to TCastleTransform.PrepareResources';

    { Statistics about last rendering frame. See TRenderStatistics docs. }
    function Statistics: TRenderStatistics;

    { Background color, displayed behind the 3D world.
      Unless the MainScene has a Background node defined, in which
      case the Background (colored and/or textured) of the 3D scene is used.

      Dark gray (DefaultBackgroundColor) by default. }
    property BackgroundColor: TCastleColor
      read FBackgroundColor write FBackgroundColor;

    { Current 3D triangle under the mouse cursor.
      Updated in every mouse move. May be @nil. }
    function TriangleHit: PTriangle;

    { Instance for headlight that should be used for this scene.
      Uses @link(Headlight) method, applies appropriate camera position/direction.
      Returns @true only if @link(Headlight) method returned @true
      and a suitable camera was present.

      Instance should be considered undefined ("out" parameter)
      when we return @false. }
    function HeadlightInstance(out Instance: TLightInstance): boolean;
      deprecated 'internal information, do not use this';

    { Enable built-in SSAO screen effect in the world. }
    property ScreenSpaceAmbientOcclusion: boolean
      read FScreenSpaceAmbientOcclusion write SetScreenSpaceAmbientOcclusion
      default DefaultScreenSpaceAmbientOcclusion;

    { Called on any camera change. }
    property OnCameraChanged: TNotifyEvent read FOnCameraChanged write FOnCameraChanged;

    { Utility method to set camera to a suitable state for 2D games.

      @unorderedList(
        @item(
          Sets both initial and current camera vectors like this:
          @unorderedList(
            @itemSpacing compact
            @item Position camera at @code((0, 0, 500)),
            @item Looks along the -Z direction,
            @item "Up" vector is in +Y.
          )

          This way the 2D world spans horizontally in X and vertically in Y.
          The Z (depth) can be used to put things in front/behind each other.

          Since this initialized the camera sensibly,
          we also set @link(AutoCamera) to false.
        )

        @item(
          Sets orthographic projection for the camera
          (@link(TCastleCamera.ProjectionType) set to ptOrthographic).

          By default our visible X range is @code([0..viewport width in pixels]),
          visible Y range is @code([0..viewport height in pixels]).
          Use the properties of @link(TCastleOrthographic Camera.Orthographic)
          to control the projection.
          For example set
          @link(TCastleOrthographic.Width Camera.Orthographic.Width) and/or
          @link(TCastleOrthographic.Height Camera.Orthographic.Height)
          to define visible projection size (horizontal or vertical) explicitly,
          regardless of the scene manager size.

          Setting @link(TCastleOrthographic.Origin Camera.Orthographic.Origin)
          is also often useful, e.g. set it to (0.5,0.5) to make the things positioned
          at (0,0) in the world visible at the middle of the scene manager.

          By default our visible Z range is [-1500, 500],
          because this sets ProjectionNear to -1000, ProjectionFar to 1000,
          and camera default depth (@code(Camera.Position.Z)) is 500.
          This was chosen to be comfortable for all cases -- you can
          keep camera Z unchanged and comfortably position things around [-500, 500],
          or set camera Z to zero and then comfortably position things around [-1000, 1000].
        )
      )
    }
    procedure Setup2D;

    { Set @link(Navigation) and some of its' parameters
      (like TCastleWalkNavigation.Gravity and so on).

      If @link(AutoNavigation), the initial @link(Navigation)
      as well as initial value of this property are automatically determined
      by the currently bound X3D NavigatinInfo node in the @link(TCastleRootTransform.MainScene MainScene),
      and world bounding box.
      They are also automatically adjusted e.g. when current NavigatinInfo
      node changes.

      But you can set @link(Navigation), or this property,
      manually to override the detected navigation.
      You should set @link(AutoNavigation) to @false to take control
      of @link(Navigation) and this property completely (no auto-detection
      based on @link(TCastleRootTransform.MainScene MainScene) will then take place).

      Note that you can also affect the current NavigationType by directly
      changing the camera properties,
      e.g. you can directly change @link(TCastleWalkNavigation.Gravity) from @false to @true,
      and thus you effectively switch from ntFly to ntWalk navigation types.
      When you read the NavigationType property, we determine the current navigation
      type from current camera properties.

      Setting this sets:
      @unorderedList(
        @itemSpacing compact
        @item @link(TCastleNavigation.Input)
        @item @link(TCastleExamineNavigation.Turntable), only in case of @link(TCastleExamineNavigation)
        @item @link(TCastleWalkNavigation.Gravity), only in case of @link(TCastleWalkNavigation)
        @item @link(TCastleWalkNavigation.PreferGravityUpForRotations), only in case of @link(TCastleWalkNavigation)
        @item @link(TCastleWalkNavigation.PreferGravityUpForMoving), only in case of @link(TCastleWalkNavigation)
      )

      If you write to NavigationType, then you @italic(should not) touch the
      above properties directly. That's because not every combination of
      above properties correspond to some sensible value of NavigationType.
      If you directly set some weird configuration, reading NavigationType will
      try it's best to determine the closest TNavigationType value
      that is similar to your configuration. }
    property NavigationType: TNavigationType
      read GetNavigationType write SetNavigationType
      default ntNone;

    { Convert 2D position on the viewport into "world coordinates",
      which is the coordinate
      space seen by TCastleTransform / TCastleScene inside scene manager @link(Items).
      This is a more general version of @link(PositionTo2DWorld),
      that works with any projection (perspective or orthographic).

      The interpretation of Position depends on ScreenCoordinates,
      and is similar to e.g. @link(TCastleTiledMapControl.PositionToTile):

      @unorderedList(
        @item(When ScreenCoordinates = @true,
          then Position is relative to the whole container
          (like TCastleWindowBase or TCastleControlBase).

          And it is expressed in real device coordinates,
          just like @link(TInputPressRelease.Position)
          when mouse is being clicked, or like @link(TInputMotion.Position)
          when mouse is moved.
        )

        @item(When ScreenCoordinates = @false,
          then Position is relative to this UI control.

          And it is expressed in coordinates after UI scaling.
          IOW, if the size of this control is @link(Width) = 100,
          then Position.X between 0 and 100 reflects the visible range of this control.
        )
      )

      This intersects the ray cast by @link(Camera)
      with a plane at Z = PlaneZ.

      Returns true and sets 3D PlanePosition (the Z component of this vector
      must always be equal to PlaneZ) if such intersection is found.
      Returns false if it's not possible to determine such point (when
      the camera looks in the other direction).
    }
    function PositionToWorldPlane(const Position: TVector2;
      const ScreenCoordinates: Boolean;
      const PlaneZ: Single; out PlanePosition: TVector3): Boolean;

    { Convert 2D position into "world coordinates", which is the coordinate
      space seen by TCastleTransform / TCastleScene inside scene manager @link(Items),
      assuming that we use orthographic projection in XY axes.

      The interpretation of Position depends on ScreenCoordinates,
      and is similar to e.g. @link(TCastleTiledMapControl.PositionToTile):

      @unorderedList(
        @item(When ScreenCoordinates = @true,
          then Position is relative to the whole container
          (like TCastleWindowBase or TCastleControlBase).

          And it is expressed in real device coordinates,
          just like @link(TInputPressRelease.Position)
          when mouse is being clicked, or like @link(TInputMotion.Position)
          when mouse is moved.
        )

        @item(When ScreenCoordinates = @false,
          then Position is relative to this UI control.

          And it is expressed in coordinates after UI scaling.
          IOW, if the size of this control is @link(Width) = 100,
          then Position.X between 0 and 100 reflects the visible range of this control.
        )
      )

      This assumes that camera "up vector" is +Y, and it is looking along the negative Z
      axis. It also assumes orthographic projection (@link(TCastleCamera.ProjectionType Camera.ProjectionType)
      equal @link(ptOrthographic)).
      These are default camera direction, up and projection types set
      by @link(Setup2D). }
    function PositionTo2DWorld(const Position: TVector2;
      const ScreenCoordinates: Boolean): TVector2;

    { Prepare resources, to make various methods (like @link(Render))
      execute fast.
      If DisplayProgressTitle <> '', we will display progress bar during loading. }
    procedure PrepareResources(const DisplayProgressTitle: string = '';
      const Options: TPrepareResourcesOptions = DefaultPrepareOptions);
    procedure PrepareResources(const Item: TCastleTransform;
      const DisplayProgressTitle: string = '';
      Options: TPrepareResourcesOptions = DefaultPrepareOptions); virtual;

    { Current 3D objects under the mouse cursor.
      Updated in every mouse move. May be @nil. }
    property MouseRayHit: TRayCollision read FMouseRayHit;

    { Do not collide with this object when moving by @link(Navigation).
      It makes sense to put here player avatar (in 3rd person view)
      or player collision volume (in 1st person view)
      to allow player to move, not colliding with its own body.

      In case of using @link(TLevel), this is automatically
      set when you set @link(TLevel.Player). }
    property AvoidNavigationCollisions: TCastleTransform
      read FAvoidNavigationCollisions
      write SetAvoidNavigationCollisions;

    { See @link(TCastleRootTransform.Paused). }
    property Paused: boolean read GetPaused write SetPaused default false;
      deprecated 'use Items.Paused';

    property SceneManager: TCastleSceneManager read FSceneManager write SetSceneManager;
      deprecated 'assign Items from one TCastleViewport to another to view the same world from multiple viewports';
  published
    { Transformations and scenes visible in this viewport.
      You should add here your @link(TCastleTransform) and @link(TCastleScene)
      instances.

      It is by default created (not nil), but you can also assign here your own
      TCastleRootTransform instance.
      You can also copy a TCastleRootTransform from one TCastleViewport to another,
      that is multiple TCastleViewport can refer to the same TCastleRootTransform
      instance. }
    property Items: TCastleRootTransform read FItems write SetItems;

    { Camera determines the viewer position and orientation.
      The given camera instance is always available and connected with this viewport. }
    property Camera: TCastleCamera read FCamera;

    { Navigation method is an optional component that handles
      the user input to control the camera.

      You can assign here an instance of @link(TCastleNavigation),
      like @link(TCastleWalkNavigation) or @link(TCastleExamineNavigation).
      Or you can leave it as @nil.

      Note that, if you leave it as @nil and have @link(AutoNavigation) as @true
      (default) then a default navigation will be calculated
      right before the first rendering. It will take into account the 3D world
      initialized in Viewport.Items, e.g. the NavigatinInfo inside Viewport.Items.MainScene.
      Set @link(AutoNavigation) to false to avoid this automatic detection.

      Note that assigning @link(NavigationType) also implicitly sets
      this property to an internal instance of
      @link(TCastleWalkNavigation) or @link(TCastleExamineNavigation).
      Setting @link(NavigationType) to @nil sets this property to @nil.

      @seealso OnCameraChanged }
    property Navigation: TCastleNavigation read FNavigation write SetNavigation
      stored IsStoredNavigation;

    { See Render3D method. }
    property OnRender3D: TRender3DEvent read FOnRender3D write FOnRender3D;
      deprecated 'do not customize rendering with this; instead add TCastleUserInterface descendants where you can override TCastleUserInterface.Render to do custom rendering';

    { Should we render with shadow volumes.
      You can change this at any time, to switch rendering shadows on/off.

      This works only if OpenGL context actually can render shadow volumes,
      checked by GLFeatures.ShadowVolumesPossible, which means that you have
      to initialize OpenGL context with stencil buffer.

      The shadow volumes algorithm is used only if shadow caster
      is 2-manifold, that is has a correctly closed volume.
      Also you need a light source
      marked as the main shadow volumes light (shadowVolumes = shadowVolumesMain = TRUE).
      See [https://castle-engine.io/x3d_extensions.php#section_ext_shadows]
      for details. }
    property ShadowVolumes: boolean
      read FShadowVolumes write FShadowVolumes default DefaultShadowVolumes;

    { Actually draw the shadow volumes to the color buffer, for debugging.
      If shadows are rendered (see GLFeatures.ShadowVolumesPossible and ShadowVolumes),
      you can use this to actually see shadow volumes, for debug / demo
      purposes. Shadow volumes will be rendered on top of the scene,
      as yellow blended polygons. }
    property ShadowVolumesRender: boolean read FShadowVolumesRender write FShadowVolumesRender default false;

    { If yes then the scene background will be rendered wireframe,
      over the background filled with BackgroundColor.

      There's a catch here: this works only if the background is actually
      internally rendered as a geometry. If the background is rendered
      by clearing the screen (this is an optimized case of sky color
      being just one simple color, and no textures),
      then it will just cover the screen as normal, like without wireframe.
      This is uncertain situation anyway (what should the wireframe
      look like in this case anyway?), so I don't consider it a bug.

      Useful especially for debugging when you want to see how your background
      geometry looks like. }
    property BackgroundWireframe: boolean
      read FBackgroundWireframe write FBackgroundWireframe default false;

    { If yes then we will not draw any background, letting the window contents
      underneath be visible (in places where we do not draw our own 3D geometry,
      or where our own geometry is transparent, e.g. by Material.transparency).
      For this to make sense, make sure that you always place some other 2D control
      under this viewport, that actually draws something predictable underneath.

      The normal background, derived from @link(Background) will be ignored.
      We will also not do any RenderContext.Clear on color buffer.
      Also BackgroundWireframe and BackgroundColor doesn't matter in this case. }
    property Transparent: boolean read FTransparent write FTransparent default false;

    { At the beginning of rendering, scene manager by default clears
      the depth buffer. This makes every scene manager draw everything
      on top of the previous 2D and 3D stuff (including on top
      of previous scene managers), like a layer.

      You can disable this, which allows to combine together the 3D objects rendered
      by various scene managers (and by custom OpenGL rendering),
      such that the 3D positions determime what overlaps what.
      This only makes sense if all these scene managers (or custom renderers)
      use the same viewport, the same projection and the same camera.

      It's your responsibility in such case to clear the depth buffer.
      E.g. place one scene manager in the back that has ClearDepth = @true.
      Or place a TCastleUserInterface descendant in the back, that calls
      @code(TRenderContext.Clear RenderContext.Clear) in overridden
      @link(TCastleUserInterface.Render).

      Note: to disable clearning the color buffer, set @link(Transparent)
      to @false.

      Note: if you use shadow volumes, we will still clear the stencil buffer
      at the beginning of rendering.
    }
    property ClearDepth: boolean read FClearDepth write FClearDepth default true;

    { Let MainScene.GlobalLights shine on every 3D object, not only
      MainScene. This is an easy way to lit your whole world with lights
      defined inside MainScene file. Be sure to set lights global=TRUE.

      Note that for now this assumes that MainScene coordinates equal
      world coordinates. This means that you should not transform
      the MainScene, it should be placed inside @link(TCastleViewport.Items)
      and not transformed by TCastleTransform. }
    property UseGlobalLights: boolean
      read FUseGlobalLights write FUseGlobalLights default DefaultUseGlobalLights;

    { Let the fog defined in MainScene affect all objects, not only MainScene.
      This is consistent with @link(UseGlobalLights), that allows lights
      from MainScene to shine on all objects. }
    property UseGlobalFog: boolean
      read FUseGlobalFog write FUseGlobalFog default DefaultUseGlobalFog;

    { Help user to activate pointing device sensors and pick items.
      Every time you press or release Input_Interact (by default
      just left mouse button), we look if current mouse position hits 3D object
      that actually does something on activation. The objects may do various stuff
      inside TCastleTransform.PointingDeviceActivate, generally this causes various
      picking/interaction with the object (like pulling a level, opening a door),
      possibly dragging, possibly with the help of VRML/X3D pointing device
      and drag sensors.

      When this is @true, we try harder to hit some 3D object that handles
      PointingDeviceActivate. If there's nothing interesting under mouse,
      we will retry a couple of other positions arount the current mouse.

      This should be usually used when you use TCastleWalkNavigation.MouseLook,
      or other navigation when mouse cursor is hidden.
      It allows user to only approximately look at interesting item and hit
      interaction button or key.
      Otherwise, activating a small 3D object is difficult,
      as you don't see the mouse cursor. }
    property ApproximateActivation: boolean
      read FApproximateActivation write FApproximateActivation default false;

    { Visibility limit of your 3D world. This is the distance the far projection
      clipping plane.

      The default @link(CalculateProjection) implementation
      calculates the final visibility limit as follows:

      @unorderedList(
        @item(First of all, if (GLFeatures.ShadowVolumesPossible and ShadowVolumes),
          then it's infinity.)
        @item(Then we look NavigationInfo.visibilityLimit value inside MainScene.
          This allows your 3D data creators to set this inside VRML/X3D data.

          Only if MainScene is not set, or doesn't contain NavigationInfo node,
          or NavigationInfo.visibilityLimit is left at (default) zero,
          we look further.)
        @item(We use this property, DefaultVisibilityLimit, if it's not zero.)
        @item(Finally, as a last resort we calculate something suitable looking
          at the 3D bounding box of items inside our 3D world.)
      )
    }
    property DefaultVisibilityLimit: Single
      read FDefaultVisibilityLimit write FDefaultVisibilityLimit default 0.0;
      deprecated 'use Camera.ProjectionFar, and set AutoCamera to false';

    { Adjust the projection parameters. This event is called before every render.
      See the @link(CalculateProjection) for a description how to default
      projection parameters are calculated. }
    property OnProjection: TProjectionEvent read FOnProjection write FOnProjection;
      deprecated 'adjust projection by changing Camera.ProjectionType and other projection parameters inside Camera';

    { Enable to drag a parent control, for example to drag a TCastleScrollView
      that contains this scene manager, even when the scene inside contains
      clickable elements (using TouchSensor node).

      To do this, you need to turn on
      TCastleScrollView.EnableDragging, and set EnableParentDragging=@true
      here. In effect, scene manager will cancel the click operation
      once you start dragging, which allows the parent to handle
      all the motion events for dragging. }
    property EnableParentDragging: boolean
      read FEnableParentDragging write FEnableParentDragging default false;

    { Assign initial camera properties
      (initial position, direction, up, TCastleCamera.ProjectionNear)
      by looking at the initial world (@link(Items)) when rendering the first frame.

      The @link(AssignDefaultCamera) is called only if this property is @true.

      Also, only if this property is @true, we synchronize
      camera when X3D Viewpoint node changes, or a new X3D Viewpoint node is bound.

      By default it is @true. Setting it to @false effectively means
      that you control @link(Camera) properties on your own.
    }
    property AutoCamera: Boolean
      read FAutoCamera write SetAutoCamera default false;

    { Assign sensible @link(Navigation) looking
      at the initial world (@link(Items)) if it is not assigned.

      This also allows to later synchronize navigation properties when X3D NavigationInfo
      node changes, or a new NavigationInfo node is bound.

      By default it is @true. Setting it to @false effectively means
      that you control @link(Navigation) on your own.
    }
    property AutoNavigation: Boolean
      read FAutoNavigation write FAutoNavigation default false;

    { Called when bound Viewpoint node changes.
      Called exactly when TCastleSceneCore.ViewpointStack.OnBoundChanged is called. }
    property OnBoundViewpointChanged: TNotifyEvent read FOnBoundViewpointChanged write FOnBoundViewpointChanged;

    { Called when bound NavigationInfo changes (to a different node,
      or just a field changes). }
    property OnBoundNavigationInfoChanged: TNotifyEvent read FOnBoundNavigationInfoChanged write FOnBoundNavigationInfoChanged;

    { Protect from falling down because of gravity when position is outside
      of world bounding box.
      This is a nice thing for general model viewers (like view3dscene),
      to prevent from accidentally falling down when using "Walk" mode.

      For now, the only thing doing gravity on camera is TCastleWalkNavigation
      when TCastleWalkNavigation.Gravity = @true, so this is the only case
      when this property is relevant. }
    property PreventInfiniteFallingDown: Boolean
      read FPreventInfiniteFallingDown write FPreventInfiniteFallingDown default false;

  {$define read_interface_class}
  {$I auto_generated_persistent_vectors/tcastleviewport_persistent_vectors.inc}
  {$undef read_interface_class}
  end;

  TCastleViewportList = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TCastleViewport>)
  private
    SceneManager: TCastleSceneManager;
  protected
    procedure Notify(constref Value: TCastleViewport;
      Action: TCollectionNotification); override;
  end deprecated 'internal for TCastleSceneManager';

  { Deprecated way to manage transformatiosn and scenes.
    To upgrade:
    - use @link(TCastleViewport)
    - set FullSize, AutoCamera and AutoNavigation to true. }
  TCastleSceneManager = class(TCastleViewport)
  strict private
    FDefaultViewport: boolean;
    {$warnings off} // using deprecated in deprecated
    FViewports: TCastleViewportList;
    {$warnings on}

    function GetMoveLimit: TBox3D;
    procedure SetMoveLimit(const Value: TBox3D);
    function GetTimeScale: Single;
    procedure SetTimeScale(const Value: Single);
    procedure SetDefaultViewport(const Value: boolean);
    function GetMainCamera: TCastleCamera;
    procedure SetMainCamera(const Value: TCastleCamera);
    function GetMainSceneInternal: TCastleScene;
    procedure SetMainScene(const Value: TCastleScene);
    function GetUseHeadlight: TUseHeadlight;
    procedure SetUseHeadlight(const Value: TUseHeadlight);
    function GetHeadlightNode: TAbstractLightNode;
    procedure SetHeadlightNode(const Value: TAbstractLightNode);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Render; override;

    { Limit the movement allowed by @link(WorldMoveAllowed).
      Ignored when empty (default).
      @seealso TCastleRootTransform.MoveLimit }
    property MoveLimit: TBox3D read GetMoveLimit write SetMoveLimit;
      deprecated 'use Items.MoveLimit';

    { List of viewports connected to this scene manager.
      This contains all TCastleViewport instances that have
      TCastleViewport.SceneManager set to us. Also it contains Self
      (this very scene manager) if and only if DefaultViewport = @true
      (because when DefaultViewport, scene manager acts as an
      additional viewport too).

      This list is read-only from the outside! It's automatically managed
      in this unit (when you change TCastleViewport.SceneManager
      or TCastleSceneManager.DefaultViewport, we automatically update this list
      as appropriate). }
    property Viewports: TCastleViewportList read FViewports;

    { Up vector, according to gravity. Gravity force pulls in -GravityUp direction. }
    function GravityUp: TVector3; deprecated 'use Camera.GravityUp';

    { See @link(TCastleRootTransform.HeadlightNode). }
    property HeadlightNode: TAbstractLightNode
      read GetHeadlightNode write SetHeadlightNode;
      deprecated 'use Items.HeadlightNode';

    { See @link(TCastleRootTransform.MainCamera). }
    property MainCamera: TCastleCamera read GetMainCamera write SetMainCamera;
      deprecated 'use Items.MainCamera';

    { See @link(TCastleRootTransform.PhysicsProperties). }
    function PhysicsProperties: TPhysicsProperties;
      deprecated 'use Items.PhysicsProperties';

    { See @link(TCastleRootTransform.TimeScale). }
    property TimeScale: Single read GetTimeScale write SetTimeScale default 1;
      deprecated 'use Items.TimeScale';

    { See @link(TCastleRootTransform.MainScene). }
    property MainScene: TCastleScene read GetMainSceneInternal write SetMainScene;
      deprecated 'use Items.MainScene';

    { See @link(TCastleRootTransform.UseHeadlight). }
    property UseHeadlight: TUseHeadlight
      read GetUseHeadlight write SetUseHeadlight default hlMainScene;
      deprecated 'use Items.UseHeadlight';
  published
    { Should we render the 3D world in a default viewport that covers
      the whole window. This is usually what you want. For more complicated
      uses, you can turn this off, and use explicit TCastleViewport
      (connected to this scene manager by TCastleViewport.SceneManager property)
      for making your world visible. }
    property DefaultViewport: boolean
      read FDefaultViewport write SetDefaultViewport default true;

    property FullSize default true;
    property AutoCamera default true;
    property AutoNavigation default true;
  end deprecated 'use TCastleViewport to render scenes. To have the same initial behavior, set FullSize, AutoCamera and AutoNavigation to true';

procedure Register;

var
  { Key/mouse combination to interact with clickable things in 3D world.
    More precisely, this input will activate pointing device sensors in VRML/X3D,
    which are used to touch (click) or drag 3D things.
    By default this is left mouse button click.

    You can change it to any other mouse button or even to key combination.
    Simply change properties like TInputShortcut.Key1
    or TInputShortcut.MouseButtonUse. }
  Input_Interact: TInputShortcut;

implementation

{$warnings off}
// TODO: This unit temporarily uses RenderingCamera singleton,
// to keep it working for backward compatibility.
uses DOM, Math,
  CastleRenderingCamera,
  CastleGLUtils, CastleProgress, CastleLog, CastleStringUtils,
  CastleSoundEngine, CastleGLVersion, CastleShapes, CastleTextureImages,
  CastleComponentSerialize, CastleInternalSettings, CastleXMLUtils, CastleURIUtils;
{$warnings on}

procedure Register;
begin
end;

{$I castleviewport_warmup_cache.inc}

{ TManagerRenderParams ------------------------------------------------------- }

constructor TManagerRenderParams.Create;
begin
  inherited;
  FBaseLights[false] := TLightInstancesList.Create;
  FBaseLights[true ] := TLightInstancesList.Create;
end;

destructor TManagerRenderParams.Destroy;
begin
  FreeAndNil(FBaseLights[false]);
  FreeAndNil(FBaseLights[true ]);
  inherited;
end;

function TManagerRenderParams.BaseLights(Scene: TCastleTransform): TAbstractLightInstancesList;
begin
  Result := FBaseLights[(Scene = MainScene) or Scene.ExcludeFromGlobalLights];
end;

{ TSSAOScreenEffect ---------------------------------------------------------- }

function TCastleViewport.TSSAOScreenEffect.SetupUniforms(var BoundTextureUnits: Cardinal): Boolean;
begin
  Result := inherited;

  { set special uniforms for SSAO shader }

  { TODO: use actual projection near/far values, instead of hardcoded ones.
    Assignment below works, but it seems that effect is much less noticeable
    then?

  WritelnLog('setting near to %f', [Viewport.ProjectionNear]); // testing
  WritelnLog('setting far to %f', [Viewport.ProjectionFarFinite]); // testing
  Uniform('near').SetValue(Viewport.ProjectionNear);
  Uniform('far').SetValue(Viewport.ProjectionFarFinite);
  }

  Uniform('near').SetValue(1.0);
  Uniform('far').SetValue(1000.0);
end;

{ TCastleViewport ------------------------------------------------------- }

constructor TCastleViewport.Create(AOwner: TComponent);
begin
  inherited;
  FBackgroundColor := DefaultBackgroundColor;
  FUseGlobalLights := DefaultUseGlobalLights;
  FUseGlobalFog := DefaultUseGlobalFog;
  FRenderParams := TManagerRenderParams.Create;
  FPrepareParams := TPrepareParams.Create;
  FShadowVolumes := DefaultShadowVolumes;
  FClearDepth := true;
  InternalDistortFieldOfViewY := 1;
  InternalDistortViewAspect := 1;

  FCamera := TCastleCamera.Create(Self);
  FCamera.InternalViewport := Self;
  FCamera.SetSubComponent(true);
  FCamera.Name := 'Camera';
  FCamera.InternalOnSceneBoundViewpointChanged := @MainSceneAndCamera_BoundViewpointChanged;
  FCamera.InternalOnSceneBoundViewpointVectorsChanged := @MainSceneAndCamera_BoundViewpointVectorsChanged;
  FCamera.InternalOnSceneBoundNavigationInfoChanged := @MainSceneAndCamera_BoundNavigationInfoChanged;

  FItems := TCastleRootTransform.Create(Self);
  FItems.SetSubComponent(true);
  FItems.Name := 'Items';
  FItems.OnCursorChange := @RecalculateCursor;
  FItems.OnVisibleChange := @ItemsVisibleChange;
  FItems.MainCamera := Camera;

  {$define read_implementation_constructor}
  {$I auto_generated_persistent_vectors/tcastleviewport_persistent_vectors.inc}
  {$undef read_implementation_constructor}
end;

destructor TCastleViewport.Destroy;
begin
  {$warnings off} // only to keep deprecated feature working
  SceneManager := nil; { remove Self from SceneManager.Viewports }
  {$warnings on}

  { unregister free notification from these objects }
  SetMouseRayHit(nil);
  AvoidNavigationCollisions := nil;

  { unregister self from Navigation callbacs, etc.

    This includes setting FNavigation to nil.
    Yes, this setting FNavigation to nil is needed, it's not just paranoia.

    Consider e.g. when our Navigation is owned by Self.
    This means that this navigation will be freed in "inherited" destructor call
    below. Since we just did FNavigation.RemoveFreeNotification, we would have
    no way to set FNavigation to nil, and FNavigation would then remain as invalid
    pointer.

    And when Viewport is freed it sends a free notification
    (this is also done in "inherited" destructor) to TCastleWindowBase instance,
    which causes removing us from TCastleWindowBase.Controls list,
    which causes SetContainer(nil) call that tries to access Navigation.

    This scenario would cause segfault, as FNavigation pointer is invalid
    at this time. }
  Navigation := nil;

  FreeAndNil(FRenderParams);
  FreeAndNil(FPrepareParams);

  {$define read_implementation_destructor}
  {$I auto_generated_persistent_vectors/tcastleviewport_persistent_vectors.inc}
  {$undef read_implementation_destructor}
  inherited;
end;

function TCastleViewport.FillsWholeContainer: boolean;
begin
  if Container = nil then
    Result := FullSize
  else
    Result := RenderRect.Round.Equals(Container.Rect);
end;

procedure TCastleViewport.SetNavigation(const Value: TCastleNavigation);
begin
  { Scene manager / viewport will handle passing events to their camera,
    and will also pass our own Container to Camera.Container.
    This is desired, this way events are correctly passed
    and interpreted before passing them to 3D objects.
    And this way we avoid the question whether camera should be before
    or after the scene manager / viewport on the Controls list (as there's really
    no perfect ordering for them).

    TODO: In the future it should be possible to assign
    the same Navigation instance to multiple viewports.
    For now, it doesn't work (last viewport will hijack some
    navigation events, and set Navigation.Viewport,
    making it not working in other viewports). }

  if FNavigation <> Value then
  begin
    { Check csDestroying, as this may be called from Notification,
      which may be called by navigation destructor *after* TCastleNavigation
      after freed it's fields. }
    if (FNavigation <> nil) and not (csDestroying in FNavigation.ComponentState) then
    begin
      if FNavigation is TCastleWalkNavigation then
      begin
        TCastleWalkNavigation(FNavigation).OnInternalMoveAllowed := nil;
        TCastleWalkNavigation(FNavigation).OnHeight := nil;
      end;

      FNavigation.RemoveFreeNotification(Self);
      { For easy backward-compatibility, leave Viewport assigned on
        FInternalWalkNavigation and FInternalExamineNavigation. }
      if (FNavigation <> FInternalWalkNavigation) and
         (FNavigation <> FInternalExamineNavigation) then
        { Note that InternalViewport has no setter to, in turn, set Viewport.Navigation.
          This would cause a recursive call from which we should protect.
          But InternalViewport is a trivial internal field now, so no need to protect,
          user code should not touch it. }
        FNavigation.InternalViewport := nil;
      RemoveControl(FNavigation);
    end;

    FNavigation := Value;

    if FNavigation <> nil then
    begin
      if FNavigation is TCastleWalkNavigation then
      begin
        TCastleWalkNavigation(FNavigation).OnInternalMoveAllowed := @NavigationMoveAllowed;
        TCastleWalkNavigation(FNavigation).OnHeight := @NavigationHeight;
      end;

      FNavigation.FreeNotification(Self);
      FNavigation.InternalViewport := Self;
      { Check IndexOfControl first, in case the FNavigation is already part
        of our controls. This happens when deserializing: "Navigation" field
        points to an instance that is within our GetChildren. }
      if IndexOfControl(FNavigation) = -1 then
        InsertControl(0, FNavigation);
    end;

    { Call OnBoundNavigationInfoChanged when Navigation instance changed.
      This allows code that observes NavigationType to work. }
    BoundNavigationInfoChanged;
  end;
end;

procedure TCastleViewport.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;

  if Operation = opRemove then
  begin
    if AComponent = FNavigation then
    begin
      { set to nil by SetNavigation, to clean nicely }
      Navigation := nil;
    end;
    // Note that we don't register on FInternalExamine/WalkNavigation destruction
    // when they are not current, so they should never be freed in that case.
    if AComponent = FInternalWalkNavigation then
      FInternalWalkNavigation := nil;
    if AComponent = FInternalExamineNavigation then
      FInternalExamineNavigation := nil;

    if (AComponent is TCastleTransform) and
       MouseRayHitContains(TCastleTransform(AComponent)) then
    begin
      { MouseRayHit cannot be used in subsequent RecalculateCursor. }
      SetMouseRayHit(nil);
    end;

    if AComponent = FAvoidNavigationCollisions then
      AvoidNavigationCollisions := nil;
  end;
end;

function TCastleViewport.Press(const Event: TInputPressRelease): boolean;
begin
  Result := inherited;
  if Result or Items.Paused then Exit;

  { Update MouseHitRay and update Items (TCastleTransform hierarchy) knowledge
    about the current pointing device.
    Otherwise the 1st mouse down event over a 3D object (like a TouchSensor)
    will be ignored
    if it happens before any mouse move (which is normal on touch devices). }
  UpdateMouseRayHit;

  LastPressEvent := TInputPressRelease(Event);

  if (Items <> nil) and
     Items.Press(Event) then
    Exit(ExclusiveEvents);

  if Input_Interact.IsEvent(Event) and
     PointingDeviceActivate(true) then
    Exit(ExclusiveEvents);
end;

function TCastleViewport.Release(const Event: TInputPressRelease): boolean;
begin
  Result := inherited;
  if Result or Items.Paused then Exit;

  if (Items <> nil) and
     Items.Release(Event) then
    Exit(ExclusiveEvents);

  if Input_Interact.IsEvent(Event) and
     PointingDeviceActivate(false) then
    Exit(ExclusiveEvents);
end;

function TCastleViewport.Motion(const Event: TInputMotion): boolean;

  function IsTouchSensorActiveInScene(const Scene: TCastleTransform): boolean;
  var
    ActiveSensorsList: TX3DNodeList;
    I: Integer;
  begin
    Result := false;
    if not (Scene is TCastleSceneCore) then
      Exit;
    ActiveSensorsList := (Scene as TCastleSceneCore).PointingDeviceActiveSensors;
    for I := 0 to ActiveSensorsList.Count -1 do
    begin
      if ActiveSensorsList.Items[I] is TTouchSensorNode then
        Exit(true);
    end;
  end;

const
  DistanceToHijackDragging = 5 * 96;
var
  TopMostScene: TCastleTransform;
begin
  Result := inherited;
  if (not Result) and (not Items.Paused) then
  begin
    if Navigation <> nil then
    begin
      if (MouseRayHit <> nil) and
         (MouseRayHit.Count <> 0) then
        TopMostScene := MouseRayHit.First.Item
      else
        TopMostScene := nil;

      { Test if dragging TTouchSensorNode. In that case cancel its dragging
        and let navigation move instead. }
      if (TopMostScene <> nil) and
         IsTouchSensorActiveInScene(TopMostScene) and
         (PointsDistance(LastPressEvent.Position, Event.Position) >
          DistanceToHijackDragging / Container.Dpi) then
      begin
        TopMostScene.PointingDeviceActivate(false, 0, true);

        if EnableParentDragging then
        begin
          { Without ReleaseCapture, the parent (like TCastleScrollView) would still
            not receive the following motion events. }
          Container.ReleaseCapture(Navigation);
        end;

        Navigation.Press(LastPressEvent);
      end;
    end;

    { Do PointingDeviceMove, which updates MouseRayHit, even when Navigation.Motion
      is true. On Windows 10 with MouseLook, Navigation.Motion is always true. }
    //if not Result then
    UpdateMouseRayHit;

    { Note: UpdateMouseRayHit above calls PointingDeviceMove and ignores
      PointingDeviceMove result.
      Maybe we should use PointingDeviceMove result as our Motion result?
      Answer unknown. Historically we do not do this, and I found no practical
      use-case when it would be useful to do this. }
  end;

  { update the cursor, since 3D object under the cursor possibly changed.

    Accidentaly, this also workarounds the problem of TCastleViewport:
    when the 3D object stayed the same but it's Cursor value changed,
    Items.CursorChange notify only TCastleSceneManager (not custom viewport).
    But thanks to doing RecalculateCursor below, this isn't
    a problem for now, as we'll update cursor anyway, as long as it changes
    only during mouse move.

    TODO: this comment is probably no longer valid, TCastleViewport
    is now used for everything. }
  RecalculateCursor(Self);
end;

procedure TCastleViewport.UpdateMouseRayHit;
var
  RayOrigin, RayDirection: TVector3;
begin
  Camera.CustomRay(RenderRect, Container.MousePosition, FProjection, RayOrigin, RayDirection);
  PointingDeviceMove(RayOrigin, RayDirection);
end;

procedure TCastleViewport.RecalculateCursor(Sender: TObject);
begin
  if { This may be called from TCastleViewport without SceneManager assigned. }
     (Items = nil) or
     { This may be called from
       TCastleTransformList.Notify when removing stuff owned by other
       stuff, in particular during our own destructor when FItems is freed
       and we're in half-destructed state. }
     (csDestroying in Items.ComponentState) or
     { When Paused, then Press and Motion events are not passed to Navigation,
       or to Items inside. So it's sensible that they also don't control the cursor
       anymore.
       In particular, it means cursor is no longer hidden by Navigation.MouseLook
       when the Paused is switched to true. }
     Items.Paused then
  begin
    Cursor := mcDefault;
    Exit;
  end;

  { We show mouse cursor from top-most 3D object.
    This is sensible, if multiple 3D scenes obscure each other at the same
    pixel --- the one "on the top" (visible by the player at that pixel)
    determines the mouse cursor.

    We ignore Cursor value of other 3d stuff along
    the MouseRayHit list. Maybe we should browse Cursor values along the way,
    and choose the first non-none? }

  if (MouseRayHit <> nil) and
     (MouseRayHit.Count <> 0) then
    Cursor := MouseRayHit.First.Item.Cursor
  else
    Cursor := mcDefault;
end;

function TCastleViewport.TriangleHit: PTriangle;
begin
  if (MouseRayHit <> nil) and
     (MouseRayHit.Count <> 0) then
    Result := MouseRayHit.First.Triangle
  else
    Result := nil;
end;

procedure TCastleViewport.Update(const SecondsPassed: Single;
  var HandleInput: boolean);
var
  SecondsPassedScaled: Single;

  procedure ItemsUpdate;
  var
    RemoveItem: TRemoveType;
  begin
    RemoveItem := rtNone;

    { Note that Items.Update do not take HandleInput
      parameter, as it would not be controllable for them: 3D objects do not
      have strict front-to-back order, so we would not know in what order
      call their Update methods, so we have to let many Items handle keys anyway.
      So, it's consistent to just treat 3D objects as "cannot definitely
      mark keys/mouse as handled". }

    Items.Update(SecondsPassedScaled, RemoveItem);
    { we ignore RemoveItem --- main Items list cannot be removed }
  end;

  procedure DoScheduledVisibleChangeNotification;
  var
    Changes: TVisibleChanges;
  begin
    if ScheduledVisibleChangeNotification then
    begin
      { reset state first, in case some VisibleChangeNotification will post again
        another visible change. }
      ScheduledVisibleChangeNotification := false;
      Changes := ScheduledVisibleChangeNotificationChanges;
      ScheduledVisibleChangeNotificationChanges := [];

      { pass visible change notification "upward" (as a TCastleUserInterface, to container) }
      VisibleChange([chRender]);
      { pass visible change notification "downward", to all children TCastleTransform }
      Items.VisibleChangeNotification(Changes);
    end;
  end;

begin
  inherited;

  if Items.Paused then
    Exit;

  SecondsPassedScaled := SecondsPassed * Items.TimeScale;

  { Note that TCastleCamera.Update doesn't process any input
    (only TCastleNavigation processes inputs),
    so passing HandleInput there is not necessary. }
  Camera.Update(SecondsPassedScaled);

  ItemsUpdate;
  DoScheduledVisibleChangeNotification;
end;

function TCastleViewport.AllowSuspendForInput: boolean;
begin
  Result := Items.Paused;
end;

procedure TCastleViewport.EnsureCameraDetected;
begin
  if AutoCamera and not AssignDefaultCameraDone then
    AssignDefaultCamera;
  { Set AssignDefaultCameraDone to done,
    regardless if AssignDefaultCameraDone was done or not.
    Otherwise later setting AutoCamera to true would suddenly
    reinitialize camera (initial and current vectors) in the middle of game. }
  AssignDefaultCameraDone := true;
end;

procedure TCastleViewport.ApplyProjection;
var
  Viewport: TRectangle;
  AspectRatio: Single;
  M: TMatrix4;
begin
  if AutoNavigation and (Navigation = nil) then
    AssignDefaultNavigation; // create Navigation if necessary

  EnsureCameraDetected;

  { We need to know container size now. }
  Check(ContainerSizeKnown, ClassName + ' did not receive "Resize" event yet, cannnot apply projection. This usually means you try to call "Render" method with a container that does not yet have an open context.');

  Viewport := RenderRect.Round;
  RenderContext.Viewport := Viewport;

  FProjection := CalculateProjection;
  {$warnings off} // using deprecated to keep it working
  if Assigned(OnProjection) then
    OnProjection(FProjection);
  {$warnings on}

  { take into account InternalDistort* properties }
  AspectRatio := InternalDistortViewAspect * Viewport.Width / Viewport.Height;
  FProjection.PerspectiveAngles[1] := InternalDistortFieldOfViewY * FProjection.PerspectiveAngles[1];

  { Apply new FProjection values }
  M := FProjection.Matrix(AspectRatio);
  Camera.ProjectionMatrix := M;
  RenderContext.ProjectionMatrix := M;

  { Calculate BackgroundSkySphereRadius here,
    using ProjectionFar that is *not* ZFarInfinity }
  if Items.MainScene <> nil then
    Items.MainScene.BackgroundSkySphereRadius :=
      TBackground.NearFarToSkySphereRadius(
        FProjection.ProjectionNear,
        FProjection.ProjectionFarFinite,
        Items.MainScene.BackgroundSkySphereRadius);
end;

function TCastleViewport.ItemsBoundingBox: TBox3D;
begin
  if Items <> nil then
    Result := Items.BoundingBox
  else
    Result := TBox3D.Empty;
end;

function TCastleViewport.IsStoredNavigation: Boolean;
begin
  { Do not store Navigation when it is an internal instance
    (set by AutoNavigation being true at some point).
    This is consistent with what editor shows: internal instances
    have csTransient, so they are not shown. }
  Result := (Navigation <> nil) and
    (not (csTransient in Navigation.ComponentStyle));
end;

procedure TCastleViewport.SetAutoCamera(const Value: Boolean);
begin
  if FAutoCamera <> Value then
  begin
    FAutoCamera := Value;

    (*
    At one point I had an idea to do this:

    { When setting AutoCamera to false, then back to true,
      call AssignDefaultCamera again (thus resetting camera initial and current
      vectors).
      This provides a way to cause AssignDefaultCamera initialization again. }
    if Value then
      AssignDefaultCameraDone := false;

    Docs in interface:
    Setting it back to @true will make the initialization again at nearest
    render.

    Later:
    This does not seem useful, and makes more confusion,
    because it overrides both initial and current camera vectors.
    You would not expect that

    if AutoCamera then
    begin
      AutoCamera := false;
      AutoCamera := true;
    end;

    does something, but here it would do something.
    Doing the same thing with AutoNavigation doesn't
    recreate navigation (if Navigation <> nil, it will stay as it was).
    *)
  end;
end;

function TCastleViewport.CalculateProjection: TProjection;
var
  Box: TBox3D;
  Viewport: TFloatRectangle;

  { Update Result.Dimensions and Camera.Orthographic.EffectiveXxx
    based on Camera.Orthographic.Width, Height and current control size. }
  procedure UpdateOrthographicDimensions;
  var
    ControlWidth, ControlHeight, EffectiveProjectionWidth, EffectiveProjectionHeight: Single;

    procedure CalculateDimensions;
    begin
      { Apply Camera.Orthographic.Scale here,
        this way it scales around Origin (e.g. around middle, when Origin is 0.5,0.5) }
      EffectiveProjectionWidth  *= Camera.Orthographic.Scale;
      EffectiveProjectionHeight *= Camera.Orthographic.Scale;

      Result.Dimensions.Width  := EffectiveProjectionWidth;
      Result.Dimensions.Height := EffectiveProjectionHeight;
      Result.Dimensions.Left   := - Camera.Orthographic.Origin.X * EffectiveProjectionWidth;
      Result.Dimensions.Bottom := - Camera.Orthographic.Origin.Y * EffectiveProjectionHeight;
    end;

  begin
    ControlWidth := EffectiveWidthForChildren;
    ControlHeight := EffectiveHeightForChildren;

    if (Camera.Orthographic.Width = 0) and
       (Camera.Orthographic.Height = 0) then
    begin
      EffectiveProjectionWidth := ControlWidth;
      EffectiveProjectionHeight := ControlHeight;
      CalculateDimensions;
    end else
    if Camera.Orthographic.Width = 0 then
    begin
      EffectiveProjectionWidth := Camera.Orthographic.Height * ControlWidth / ControlHeight;
      EffectiveProjectionHeight := Camera.Orthographic.Height;
      CalculateDimensions;
    end else
    if Camera.Orthographic.Height = 0 then
    begin
      EffectiveProjectionWidth := Camera.Orthographic.Width;
      EffectiveProjectionHeight := Camera.Orthographic.Width * ControlHeight / ControlWidth;
      CalculateDimensions;
    end else
    begin
      EffectiveProjectionWidth := Camera.Orthographic.Width;
      EffectiveProjectionHeight := Camera.Orthographic.Height;

      CalculateDimensions;

      Result.Dimensions := TOrthoViewpointNode.InternalFieldOfView(
        Result.Dimensions,
        Viewport.Width,
        Viewport.Height);

      EffectiveProjectionWidth := Result.Dimensions.Width;
      EffectiveProjectionHeight := Result.Dimensions.Height;
    end;

    Assert(Result.Dimensions.Width  = EffectiveProjectionWidth);
    Assert(Result.Dimensions.Height = EffectiveProjectionHeight);

    Camera.Orthographic.InternalSetEffectiveSize(
      Result.Dimensions.Width,
      Result.Dimensions.Height);
  end;

  { Calculate reasonable perspective projection near, looking at Box. }
  function GetDefaultProjectionNear: Single;
  var
    Radius: Single;
  begin
    Radius := Box.AverageSize(false, 1) * WorldBoxSizeToRadius;
    Result := Radius * RadiusToProjectionNear;
  end;

  { Calculate reasonable perspective projection far, looking at Box. }
  function GetDefaultProjectionFar: Single;
  begin
    { Note that when box is empty (or has 0 sizes),
      ProjectionFar cannot be simply "any dummy value".
      It must be appropriately larger than GetDefaultProjectionNear
      to provide sufficient space for rendering Background node. }
    Result := Box.AverageSize(false, 1) * WorldBoxSizeToProjectionFar;
  end;

var
  PerspectiveAnglesRad: TVector2;
begin
  Box := ItemsBoundingBox;
  Viewport := RenderRect;

  Result.ProjectionType := Camera.ProjectionType;

  PerspectiveAnglesRad := TViewpointNode.InternalFieldOfView(
    Camera.Perspective.FieldOfView,
    Camera.Perspective.FieldOfViewAxis,
    Viewport.Width,
    Viewport.Height);
  Result.PerspectiveAngles[0] := RadToDeg(PerspectiveAnglesRad[0]);
  Result.PerspectiveAngles[1] := RadToDeg(PerspectiveAnglesRad[1]);

  { calculate Result.ProjectionNear }
  Result.ProjectionNear := Camera.ProjectionNear;
  if (Result.ProjectionType = ptPerspective) and
     (Result.ProjectionNear <= 0) then
  begin
    Result.ProjectionNear := GetDefaultProjectionNear;
    Assert(Result.ProjectionNear > 0);
  end;

  { calculate Result.ProjectionFar, algorithm documented at DefaultVisibilityLimit }
  Result.ProjectionFar := Camera.ProjectionFar;
  {$warnings off} // using deprecated to keep it working
  if Result.ProjectionFar <= 0 then
    Result.ProjectionFar := DefaultVisibilityLimit;
  {$warnings on}
  if Result.ProjectionFar <= 0 then
    Result.ProjectionFar := GetDefaultProjectionFar;
  Assert(Result.ProjectionFar > 0);

  { update ProjectionFarFinite.
    ProjectionFar may be later changed to ZFarInfinity. }
  Result.ProjectionFarFinite := Result.ProjectionFar;

  { We need infinite ZFar in case of shadow volumes.
    But only perspective projection supports ZFar in infinity. }
  if (Result.ProjectionType = ptPerspective) and
     GLFeatures.ShadowVolumesPossible and
     ShadowVolumes then
    Result.ProjectionFar := ZFarInfinity;

  Camera.InternalSetEffectiveProjection(
    Result.ProjectionNear,
    Result.ProjectionFar);

  { Calculate Result.Dimensions regardless of Result.ProjectionType,
    this way OnProjection can easily change projection type to orthographic. }
  UpdateOrthographicDimensions;

{
  WritelnLogMultiline('Projection', Format(
    'ProjectionType: %s' + NL +
    'Perspective Field of View (in degrees): %f x %f' + NL +
    'Orthographic Dimensions: %s' + NL +
    'Near: %f' + NL +
    'Far: %f', [
    ProjectionTypeToStr(Result.ProjectionType),
    Result.PerspectiveAngles[0],
    Result.PerspectiveAngles[1],
    Result.Dimensions.ToString,
    Result.ProjectionNear,
    Result.ProjectionFar
  ]));
}
end;

function TCastleViewport.Background: TBackground;
begin
  if Items.MainScene <> nil then
    Result := Items.MainScene.InternalBackground
  else
    Result := nil;
end;

function TCastleViewport.MainLightForShadows(
  out AMainLightPosition: TVector4): boolean;
begin
  if Items.MainScene <> nil then
    Result := Items.MainScene.MainLightForShadows(AMainLightPosition)
  else
    Result := false;
end;

procedure TCastleViewport.Render3D(const Params: TRenderParams);
begin
  Params.Frustum := @Params.RenderingCamera.Frustum;
  Items.Render(Params);
  if Assigned(FOnRender3D) then
    FOnRender3D(Self, Params);
end;

procedure TCastleViewport.RenderShadowVolume;
begin
  Items.RenderShadowVolume(FShadowVolumeRenderer, true, TMatrix4.Identity);
end;

procedure TCastleViewport.InitializeLights(const Lights: TLightInstancesList);
var
  HI: TLightInstance;
begin
  {$warnings off}
  if HeadlightInstance(HI) then
    Lights.Add(HI);
  {$warnings on}
end;

function TCastleViewport.HeadlightInstance(out Instance: TLightInstance): boolean;
var
  Node: TAbstractLightNode;
  HC: TCastleCamera;

  procedure PrepareInstance;
  var
    Position, Direction, Up: TVector3;
  begin
    Assert(Node <> nil);

    HC.GetView(Position, Direction, Up);

    { set location/direction of Node }
    if Node is TAbstractPositionalLightNode then
    begin
      TAbstractPositionalLightNode(Node).FdLocation.Send(Position);
      if Node is TSpotLightNode then
        TSpotLightNode(Node).FdDirection.Send(Direction) else
      if Node is TSpotLightNode_1 then
        TSpotLightNode_1(Node).FdDirection.Send(Direction);
    end else
    if Node is TAbstractDirectionalLightNode then
      TAbstractDirectionalLightNode(Node).FdDirection.Send(Direction);

    Instance.Node := Node;
    Instance.Location := Position;
    Instance.Direction := Direction;
    Instance.Transform := TMatrix4.Identity;
    Instance.TransformScale := 1;
    Instance.Radius := MaxSingle;
    Instance.WorldCoordinates := true;
  end;

begin
  Result := false;
  Node := Items.InternalHeadlight;
  if Node <> nil then
  begin
    HC := Items.MainCamera;
    if HC <> nil then
    begin
      PrepareInstance;
      Result := true;
    end;
  end;
end;

function TCastleViewport.PrepareParams: TPrepareParams;
{ Note: you cannot refer to PrepareParams inside
  the TCastleTransform.PrepareResources or TCastleTransform.Render implementation,
  as they may change the referenced PrepareParams.InternalBaseLights value.
}
begin
  { We just reuse FRenderParams.FBaseLights[false] below as a temporary
    TLightInstancesList that we already have created. }

  { initialize FPrepareParams.InternalBaseLights }
  FRenderParams.FBaseLights[false].Clear;
  InitializeLights(FRenderParams.FBaseLights[false]);
  FPrepareParams.InternalBaseLights := FRenderParams.FBaseLights[false];

  { initialize FPrepareParams.InternalGlobalFog }
  if UseGlobalFog and
     (Items.MainScene <> nil) then
    FPrepareParams.InternalGlobalFog := Items.MainScene.FogStack.Top
  else
    FPrepareParams.InternalGlobalFog := nil;

  Result := FPrepareParams;
end;

function TCastleViewport.BaseLights: TLightInstancesList;
begin
  Result := PrepareParams.InternalBaseLights as TLightInstancesList;
end;

procedure TCastleViewport.RenderFromView3D(const Params: TRenderParams);

  procedure RenderNoShadows;
  begin
    { We must first render all non-transparent objects,
      then all transparent objects. Otherwise transparent objects
      (that must be rendered without updating depth buffer) could get brutally
      covered by non-transparent objects (that are in fact further away from
      the camera). }

    Params.InShadow := false;

    Params.Transparent := false; Params.ShadowVolumesReceivers := [false, true]; Render3D(Params);
    Params.Transparent := true ; Params.ShadowVolumesReceivers := [false, true]; Render3D(Params);
  end;

  procedure RenderWithShadows(const MainLightPosition: TVector4);
  begin
    FShadowVolumeRenderer.InitFrustumAndLight(Params.RenderingCamera.Frustum, MainLightPosition);
    FShadowVolumeRenderer.Render(Params, @Render3D, @RenderShadowVolume, ShadowVolumesRender);
  end;

var
  MainLightPosition: TVector4;
begin
  if GLFeatures.ShadowVolumesPossible and
     ShadowVolumes and
     MainLightForShadows(MainLightPosition) then
    RenderWithShadows(MainLightPosition) else
    RenderNoShadows;
end;

procedure TCastleViewport.RenderFromViewEverything(const RenderingCamera: TRenderingCamera);

  { Call RenderContext.Clear with proper options. }
  procedure RenderClear;
  var
    ClearBuffers: TClearBuffers;
    ClearColor: TCastleColor;
    MainLightPosition: TVector4; { ignored }
  begin
    { Make ClearColor anything defined.
      If we will include cbColor in ClearBuffers, it will actually always
      be adjusted to something appropriate. }
    ClearColor := Black;
    ClearBuffers := [];

    if ClearDepth then
      Include(ClearBuffers, cbDepth);

    if RenderingCamera.Target = rtVarianceShadowMap then
    begin
      { When rendering to VSM, we want to clear the screen to max depths (1, 1^2). }
      Include(ClearBuffers, cbColor);
      ClearColor := Vector4(1, 1, 0, 1);
    end else
    if not Transparent then
    begin
      { Note that we clear cbColor regardless whether Background exists.
        This is more reliable, in case Background rendering is transparent,

        - e.g. ImageBackground can be completely transparent or partially-transparent
          in a couple of ways. When ImageBackground.color has alpha < 1,
          when ImageBackground.texture is transparent,
          when ImageBackground.texture is NULL...

        - likewise, Background can be transparent.
          E.g. if one of the textures on 6 cube sides didn't load.
          Or when BackgroundWireframe.
      }
      Include(ClearBuffers, cbColor);
      ClearColor := BackgroundColor;
    end;

    if GLFeatures.ShadowVolumesPossible and
       ShadowVolumes and
       MainLightForShadows(MainLightPosition) then
      Include(ClearBuffers, cbStencil);

    RenderContext.Clear(ClearBuffers, ClearColor);
  end;

  procedure RenderBackground;
  var
    UsedBackground: TBackground;
  begin
    UsedBackground := Background;
    if UsedBackground <> nil then
    begin
      if GLFeatures.EnableFixedFunction then
      begin
        {$ifndef OpenGLES}
        glLoadMatrix(RenderingCamera.RotationMatrix);
        {$endif}
      end;
      RenderingCamera.RotationOnly := true;
      UsedBackground.Render(RenderingCamera, BackgroundWireframe, RenderRect, FProjection);
      RenderingCamera.RotationOnly := false;
    end;
  end;

begin
  { TODO: Temporary compatibility cludge:
    Because some rendering code still depends on
    the CastleRenderingCamera.RenderingCamera singleton being initialized,
    so initialize it from current parameter. }
  if RenderingCamera <> CastleRenderingCamera.RenderingCamera then
    CastleRenderingCamera.RenderingCamera.Assign(RenderingCamera);

  RenderClear;
  RenderBackground;

  if GLFeatures.EnableFixedFunction then
  begin
    {$ifndef OpenGLES}
    glLoadMatrix(RenderingCamera.Matrix);
    {$endif}
  end;

  { clear FRenderParams instance }

  FRenderParams.InternalPass := 0;
  FRenderParams.UserPass := CustomRenderingPass;
  FRenderParams.RenderingCamera := RenderingCamera;
  FillChar(FRenderParams.Statistics, SizeOf(FRenderParams.Statistics), #0);

  FRenderParams.FBaseLights[false].Clear;
  InitializeLights(FRenderParams.FBaseLights[false]);
  if UseGlobalLights and
     (Items.MainScene <> nil) and
     (Items.MainScene.GlobalLights.Count <> 0) then
  begin
    FRenderParams.MainScene := Items.MainScene;
    { For MainScene, BaseLights are only the ones calculated by InitializeLights }
    FRenderParams.FBaseLights[true].Assign(FRenderParams.FBaseLights[false]);
    { For others than MainScene, BaseLights are calculated by InitializeLights
      summed with Items.MainScene.GlobalLights. }
    FRenderParams.FBaseLights[false].AppendInWorldCoordinates(Items.MainScene.GlobalLights);
  end else
    { Do not use Params.FBaseLights[true] }
    FRenderParams.MainScene := nil;

  { initialize FRenderParams.GlobalFog }
  if UseGlobalFog and
     (Items.MainScene <> nil) then
    FRenderParams.GlobalFog := Items.MainScene.FogStack.Top
  else
    FRenderParams.GlobalFog := nil;

  RenderFromView3D(FRenderParams);
end;

procedure TCastleViewport.RenderWithoutScreenEffects;

  { Render everything (by RenderFromViewEverything) on the screen.
    Takes care to set RenderingCamera (Target = rtScreen and camera as given),
    and takes care to apply Scissor if not FillsWholeContainer,
    and calls RenderFromViewEverything.

    Always call ApplyProjection before this, to set correct
    projection matrix. }
  procedure RenderOnScreen(ACamera: TCastleCamera);
  begin
    RenderingCamera.Target := rtScreen;
    RenderingCamera.FromCameraObject(ACamera);

    if (not FillsWholeContainer) and (not RenderScreenEffects) then
      { Use Scissor to limit what RenderContext.Clear clears. }
      RenderContext.ScissorEnable(
        RenderRect.Translate(Vector2(RenderContext.ViewportDelta)).Round);

    RenderFromViewEverything(RenderingCamera);

    if (not FillsWholeContainer) and (not RenderScreenEffects) then
      RenderContext.ScissorDisable;
  end;

begin
  inherited;
  ApplyProjection;
  Items.UpdateGeneratedTextures(@RenderFromViewEverything,
    FProjection.ProjectionNear, FProjection.ProjectionFar);
  RenderOnScreen(Camera);
end;

function TCastleViewport.InternalExtraGetScreenEffects(const Index: Integer): TGLSLProgram;
begin
  Result := GetScreenEffects(Index);
end;

function TCastleViewport.InternalExtraScreenEffectsCount: Integer;
begin
  Result := ScreenEffectsCount;
end;

function TCastleViewport.InternalExtraScreenEffectsNeedDepth: Boolean;
begin
  Result := ScreenEffectsNeedDepth;
end;

function TCastleViewport.GetScreenEffects(const Index: Integer): TGLSLProgram;
begin
  if ScreenSpaceAmbientOcclusion then
    SSAOShaderInitialize;

  if ScreenSpaceAmbientOcclusion and (SSAOShader <> nil) then
  begin
    if Index = 0 then
      Result := SSAOShader else
      Result := Items.MainScene.ScreenEffects(Index - 1);
  end else
  if Items.MainScene <> nil then
    Result := Items.MainScene.ScreenEffects(Index)
  else
    { no Index is valid, since ScreenEffectsCount = 0 in this class }
    Result := nil;
end;

function TCastleViewport.ScreenEffectsCount: Integer;
begin
  if ScreenSpaceAmbientOcclusion then
    SSAOShaderInitialize;

  if Items.MainScene <> nil then
    Result := Items.MainScene.ScreenEffectsCount
  else
    Result := 0;
  if ScreenSpaceAmbientOcclusion and (SSAOShader <> nil) then
    Inc(Result);
end;

function TCastleViewport.ScreenEffectsNeedDepth: boolean;
begin
  if ScreenSpaceAmbientOcclusion then
    SSAOShaderInitialize;

  if ScreenSpaceAmbientOcclusion and (SSAOShader <> nil) then
    Exit(true);
  if Items.MainScene <> nil then
    Result := Items.MainScene.ScreenEffectsNeedDepth
  else
    Result := false;
end;

procedure TCastleViewport.SSAOShaderInitialize;
begin
  { Do not retry creating SSAOShader if SSAOShaderInitialize was already called.
    Even if SSAOShader is nil (when SSAOShaderInitialize = true but
    SSAOShader = nil it means that compiling SSAO shader fails on this GPU). }
  if SSAOShaderInitialized then Exit;

  // SSAOShaderInitialized = false implies SSAOShader = nil
  Assert(SSAOShader = nil);

  if GLFeatures.Shaders <> gsNone then
  begin
    try
      SSAOShader := TSSAOScreenEffect.Create;
      SSAOShader.Viewport := Self;
      SSAOShader.NeedsDepth := true;
      SSAOShader.ScreenEffectShader := {$I ssao.glsl.inc};
      SSAOShader.Link;
    except
      on E: EGLSLError do
      begin
        WritelnLog('GLSL', 'Error when initializing GLSL shader for ScreenSpaceAmbientOcclusionShader: ' + E.Message);
        FreeAndNil(SSAOShader);
        ScreenSpaceAmbientOcclusion := false;
      end;
    end;
  end;
  SSAOShaderInitialized := true;
end;

procedure TCastleViewport.GLContextOpen;
begin
  inherited;

  { We actually need to do it only if GLFeatures.ShadowVolumesPossible
    and ShadowVolumes for any viewport.
    But we can as well do it always, it's harmless (just checks some GL
    extensions). (Otherwise we'd have to handle SetShadowVolumes.) }
  if FShadowVolumeRenderer = nil then
  begin
    FShadowVolumeRenderer := TGLShadowVolumeRenderer.Create;
    FShadowVolumeRenderer.GLContextOpen;
  end;
end;

procedure TCastleViewport.GLContextClose;
begin
  FreeAndNil(FShadowVolumeRenderer);

  FreeAndNil(SSAOShader);
  SSAOShaderInitialized := false;

  inherited;
end;

function TCastleViewport.ScreenSpaceAmbientOcclusionAvailable: boolean;
begin
  SSAOShaderInitialize;
  Result := (SSAOShader <> nil);
end;

procedure TCastleViewport.SetScreenSpaceAmbientOcclusion(const Value: boolean);
begin
  if FScreenSpaceAmbientOcclusion <> Value then
  begin
    FScreenSpaceAmbientOcclusion := Value;
    VisibleChange([chRender]);
  end;
end;

function TCastleViewport.RequiredCamera: TCastleNavigation;
begin
  {$warnings off} // using deprecated in deprecated
  Result := RequiredNavigation;
  {$warnings on}
end;

function TCastleViewport.RequiredNavigation: TCastleNavigation;
begin
  { For backward-compatibility, this also initializes Camera vectors
    (even though the method docs only guarantee that it initializes Navigation,
    but in the past Camera and Navigation were the same thing). }
  EnsureCameraDetected;

  if Navigation = nil then
    AssignDefaultNavigation;
  {$warnings off} // using deprecated in deprecated
  // Since AssignDefaultNavigation may leave Navigation nil, make sure it is assigned now
  if Navigation = nil then
    Result := InternalExamineNavigation;
  {$warnings on}
  Result := Navigation;
end;

function TCastleViewport.InternalExamineCamera: TCastleExamineNavigation;
begin
  {$warnings off} // using deprecated in deprecated
  Result := InternalExamineNavigation;
  {$warnings on}
end;

function TCastleViewport.InternalWalkCamera: TCastleWalkNavigation;
begin
  {$warnings off} // using deprecated in deprecated
  Result := InternalWalkNavigation;
  {$warnings on}
end;

function TCastleViewport.InternalExamineNavigation: TCastleExamineNavigation;
begin
  if FInternalExamineNavigation = nil then
  begin
    FInternalExamineNavigation := TCastleExamineNavigation.Create(Self);
    FInternalExamineNavigation.SetTransient;
    { For easy backward-compatibility, Viewport is assigned here for the
      entire lifetime of FInternalExamineNavigation instance,
      even before calling SetNavigation on it. }
    FInternalExamineNavigation.InternalViewport := Self;
  end;
  Result := FInternalExamineNavigation;
end;

function TCastleViewport.InternalWalkNavigation: TCastleWalkNavigation;
begin
  if FInternalWalkNavigation = nil then
  begin
    FInternalWalkNavigation := TCastleWalkNavigation.Create(Self);
    FInternalWalkNavigation.SetTransient;
    { For easy backward-compatibility, Viewport is assigned here for the
      entire lifetime of FInternalExamineNavigation instance,
      even before calling SetNavigation on it. }
    FInternalWalkNavigation.InternalViewport := Self;
  end;
  Result := FInternalWalkNavigation;
end;

function TCastleViewport.ExamineNavigation(const SwitchNavigationTypeIfNeeded: boolean): TCastleExamineNavigation;
var
  NewNavigation: TCastleExamineNavigation;
begin
  if not (Navigation is TCastleExamineNavigation) then
  begin
    if not SwitchNavigationTypeIfNeeded then
      Exit(nil);

    { For backward-compatibility, this also initializes Camera vectors
      (even though the method docs only guarantee that it initializes Navigation,
      but in the past Camera and Navigation were the same thing). }
    EnsureCameraDetected;

    {$warnings off} // using deprecated in deprecated
    NewNavigation := InternalExamineNavigation;
    {$warnings on}
    if Navigation = nil then
      AssignDefaultNavigation; // initialize defaults from MainScene
    // AssignDefaultNavigation could leave Navigation at nil, in which case ignor
    if Navigation <> nil then
      NewNavigation.Assign(Navigation);
    Navigation := NewNavigation;
    { make sure it's in ntExamine mode (as we possibly reuse old navigation,
      by reusing InternalExamineNavigation, so we're not sure what state it's in. }
    NavigationType := ntExamine;
  end;
  Result := Navigation as TCastleExamineNavigation;
end;

function TCastleViewport.ExamineCamera(const SwitchNavigationTypeIfNeeded: boolean): TCastleExamineNavigation;
begin
  {$warnings off} // using deprecated in deprecated
  Result := ExamineNavigation(SwitchNavigationTypeIfNeeded);
  {$warnings on}
end;

function TCastleViewport.WalkNavigation(const SwitchNavigationTypeIfNeeded: boolean): TCastleWalkNavigation;
var
  NewNavigation: TCastleWalkNavigation;
begin
  if not (Navigation is TCastleWalkNavigation) then
  begin
    if not SwitchNavigationTypeIfNeeded then
      Exit(nil);

    { For backward-compatibility, this also initializes Camera vectors
      (even though the method docs only guarantee that it initializes Navigation,
      but in the past Camera and Navigation were the same thing). }
    EnsureCameraDetected;

    {$warnings off} // using deprecated in deprecated
    NewNavigation := InternalWalkNavigation;
    {$warnings on}
    if Navigation = nil then
      AssignDefaultNavigation; // initialize defaults from MainScene
    // AssignDefaultNavigation could leave Navigation at nil, in which case ignor
    if Navigation <> nil then
      NewNavigation.Assign(Navigation);
    Navigation := NewNavigation;
    { make sure it's in ntWalk mode (as we possibly reuse old navigation,
      by reusing InternalWalkNavigation, so we're not sure what state it's in. }
    NavigationType := ntWalk;
  end;
  Result := Navigation as TCastleWalkNavigation;
end;

function TCastleViewport.WalkCamera(const SwitchNavigationTypeIfNeeded: boolean): TCastleWalkNavigation;
begin
  {$warnings off} // using deprecated in deprecated
  Result := WalkNavigation(SwitchNavigationTypeIfNeeded);
  {$warnings on}
end;

function TCastleViewport.GetNavigationType: TNavigationType;
var
  C: TCastleNavigation;
begin
  C := Navigation;
  { We are using here Navigation, not RequiredNavigation, as automatically
    creating Navigation could have surprising consequences.
    E.g. it means that SetNavigation(nil) may recreate the navigation,
    as BoundNavigationInfoChanged calls something that checks
    NavigationType. }
  if C = nil then
    Result := ntNone
  else
    Result := C.GetNavigationType;
end;

procedure TCastleViewport.SetNavigationType(const Value: TNavigationType);
var
  E: TCastleExamineNavigation;
  W: TCastleWalkNavigation;
begin
  { Do this even if "Value = GetNavigationType".
    This makes sense, in case you set some weird values.
    On the other hand, it makes "NavigationType := NavigationType" sometimes
    a sensible operation that changes something.

    It also avoids recursive loop when first assigning navigation
    in AssignDefaultNavigation. }

  { do not change NavigationType when
    SetNavigationType is called from ExamineNavigation or WalkNavigation
    that were already called by NavigationType.
    It's actually harmless, but still useless. }
  if FWithinSetNavigationType then
    Exit;
  FWithinSetNavigationType := true;

  case Value of
    ntExamine:
      begin
        {$warnings off} // TODO: this should be internal
        E := ExamineNavigation;
        {$warnings on}
        E.Input := TCastleNavigation.DefaultInput;
        E.Turntable := false;
      end;
    ntTurntable:
      begin
        {$warnings off} // TODO: this should be internal
        E := ExamineNavigation;
        {$warnings on}
        E.Input := TCastleNavigation.DefaultInput;
        E.Turntable := true;
      end;
    ntWalk:
      begin
        {$warnings off} // TODO: this should be internal
        W := WalkNavigation;
        {$warnings on}
        W.Input := TCastleNavigation.DefaultInput;
        W.PreferGravityUpForRotations := true;
        W.PreferGravityUpForMoving := true;
        W.Gravity := true;
      end;
    ntFly:
      begin
        {$warnings off} // TODO: this should be internal
        W := WalkNavigation;
        {$warnings on}
        W.Input := TCastleNavigation.DefaultInput;
        W.PreferGravityUpForRotations := true;
        W.PreferGravityUpForMoving := false;
        W.Gravity := false;
      end;
    ntNone:
      begin
        { Advantage: This way setting NavigationType to ntNone (default NavigationType value)
          will restore Navigation to nil, which is Navigation default value. }
        // Navigation := nil;

        { Advantage: This way of setting NavigationType to ntNone (by making Navigation non-nil)
          explicitly will prevent
          Navigation from being auto-created (in case AutoNavigation remains @true),
          which would make setting "NavigationType := ntNone" moot. }
        {$warnings off} // TODO: this should be internal
        W := WalkNavigation;
        {$warnings on}
        W.Input := [];
        W.Gravity := false;
      end;
    {$ifndef COMPILER_CASE_ANALYSIS}
    else raise EInternalError.Create('TCastleViewport.SetNavigationType: Value?');
    {$endif}
  end;

  { This assertion should be OK. It is commented out only to prevent
    GetNavigationType from accidentally creating something intermediate,
    and thus making debug and release behaviour different) }
  // Assert(GetNavigationType = Value);

  FWithinSetNavigationType := false;

  { Call OnBoundNavigationInfoChanged when NavigationType changed. }
  BoundNavigationInfoChanged;
end;

procedure TCastleViewport.ClearCameras;
begin
  Navigation := nil;
  FreeAndNil(FInternalExamineNavigation);
  FreeAndNil(FInternalWalkNavigation);
end;

procedure TCastleViewport.AssignDefaultNavigation;
var
  Box: TBox3D;
  Scene: TCastleScene;
  C: TCastleExamineNavigation;
  Nav: TNavigationType;
begin
  Box := ItemsBoundingBox;
  Scene := Items.MainScene;
  if Scene <> nil then
  begin
    Nav := Scene.NavigationTypeFromNavigationInfo;

    { Set Navigation explicitly, otherwise SetNavigationType below could call
      ExamineNavigation / WalkNavigation that call AssignDefaultNavigation when Navigation = nil,
      and we would have infinite AssignDefaultNavigation calls loop. }
    {$warnings off} // TODO: this should be internal
    if Nav in [ntExamine, ntTurntable] then
      Navigation := InternalExamineNavigation
    else
      Navigation := InternalWalkNavigation;
    {$warnings on}

    NavigationType := Nav;
    Scene.InternalUpdateNavigation(Navigation, Box);
  end else
  begin
    {$warnings off} // TODO: this should be internal
    C := InternalExamineNavigation;
    {$warnings on}
    C.ModelBox := Box;
    C.Radius := Box.AverageSize(false, 1.0) * WorldBoxSizeToRadius;
    Navigation := C;
  end;
end;

procedure TCastleViewport.AssignDefaultCamera;
var
  Box: TBox3D;
  Scene: TCastleScene;
  APos, ADir, AUp, NewGravityUp: TVector3;
begin
  Box := ItemsBoundingBox;
  Scene := Items.MainScene;
  if Scene <> nil then
  begin
    Scene.InternalUpdateCamera(Camera, Box, false, false);
  end else
  begin
    CameraViewpointForWholeScene(Box, 2, 1, false, true,
      APos, ADir, AUp, NewGravityUp);
    Camera.Init(APos, ADir, AUp, NewGravityUp);
  end;

  { Mark it as done, so that next EnsureCameraDetected does nothing
    if you manually call this.
    This is consistent with AssignDefaultNavigation,
    that sets Navigation <> nil thus it is no longer auto-detected
    if you call AssignDefaultNavigation. }
  AssignDefaultCameraDone := true;
end;

function TCastleViewport.Statistics: TRenderStatistics;
begin
  Result := FRenderParams.Statistics;
end;

procedure TCastleViewport.Setup2D;
begin
  Camera.Init(
    { pos } Vector3(0, 0, Default2DCameraZ),
    { dir } Vector3(0, 0, -1),
    { up } Vector3(0, 1, 0),
    { gravity up } Vector3(0, 1, 0)
  ); // sets both initial and current vectors
  Camera.ProjectionNear := -Default2DProjectionFar;
  Camera.ProjectionFar := Default2DProjectionFar;
  Camera.ProjectionType := ptOrthographic;
  AutoCamera := false;
end;

function TCastleViewport.PositionToWorldPlane(const Position: TVector2;
  const ScreenCoordinates: Boolean;
  const PlaneZ: Single; out PlanePosition: TVector3): Boolean;
var
  R: TFloatRectangle;
  ScreenPosition: TVector2;
  RayOrigin, RayDirection: TVector3;
begin
  R := RenderRect;

  if ScreenCoordinates then
    ScreenPosition := Position
  else
    ScreenPosition := Position * UIScale + R.LeftBottom;

  Camera.CustomRay(R, ScreenPosition, FProjection, RayOrigin, RayDirection);

  Result := TrySimplePlaneRayIntersection(PlanePosition, 2, PlaneZ,
    RayOrigin, RayDirection);
end;

function TCastleViewport.PositionTo2DWorld(const Position: TVector2;
  const ScreenCoordinates: Boolean): TVector2;

{ Version 1:
  This makes sense, but ignores TCastleExamineNavigation.ScaleFactor (assumes unscaled camera).

var
  P: TVector2;
  Proj: TProjection;
  ProjRect: TFloatRectangle;
begin
  if ScreenCoordinates then
    P := (Position - RenderRect.LeftBottom) / UIScale
  else
    P := Position;

  Proj := Projection;
  if Proj.ProjectionType <> ptOrthographic then
    raise Exception.Create('TCastle2DSceneManager.PositionTo2DWorld assumes an orthographic projection, like the one set by TCastle2DSceneManager.CalculateProjection');
  ProjRect := Proj.Dimensions;

  if Navigation <> nil then
    ProjRect := ProjRect.Translate(Navigation.Position.XY);

  Result := Vector2(
    MapRange(P.X, 0, EffectiveWidth , ProjRect.Left  , ProjRect.Right),
    MapRange(P.Y, 0, EffectiveHeight, ProjRect.Bottom, ProjRect.Top)
  );
end; }

{ Version 2:
  This also makes sense, but also
  ignores TCastleExamineNavigation.ScaleFactor (assumes unscaled camera).
  TCastleNavigation.CustomRay looks only at camera pos/dir/up and ignores scaling.

var
  P: TVector2;
  Proj: TProjection;
  RayOrigin, RayDirection: TVector3;
begin
  if not ScreenCoordinates then
    P := Position * UIScale + RenderRect.LeftBottom
  else
    P := Position;
  RequiredNavigation.CustomRay(RenderRect, P, Projection, RayOrigin, RayDirection);
  Result := RayOrigin.XY;
end; }

{ Version 3:
  Should work, but
  1. Cannot invert projection matrix,
  2. Also it's not efficient, since camera has ready InverseMatrix calculated
     more efficiently.

var
  WorldToScreenMatrix: TMatrix4;
  ScreenToWorldMatrix: TMatrix4;
  P: TVector2;
begin
  WorldToScreenMatrix := RequiredNavigation.ProjectionMatrix * RequiredNavigation.Matrix;
  if not WorldToScreenMatrix.TryInverse(ScreenToWorldMatrix) then
    raise Exception.Create('Cannot invert projection * camera matrix. Possibly one of them was not initialized, or camera contains scale to zero.');

  if ScreenCoordinates then
    P := (Position - RenderRect.LeftBottom) / UIScale
  else
    P := Position;
  P := Vector2(
    MapRange(P.X, 0, EffectiveWidth , -1, 1),
    MapRange(P.Y, 0, EffectiveHeight, -1, 1)
  );

  Result := ScreenToWorldMatrix.MultPoint(Vector3(P, 0)).XY;
end; }

var
  CameraToWorldMatrix: TMatrix4;
  P: TVector2;
begin
  CameraToWorldMatrix := Camera.MatrixInverse;

  if ScreenCoordinates then
    P := (Position - RenderRect.LeftBottom) / UIScale
  else
    P := Position;
  P := Vector2(
    MapRange(P.X, 0, EffectiveWidth , FProjection.Dimensions.Left  , FProjection.Dimensions.Right),
    MapRange(P.Y, 0, EffectiveHeight, FProjection.Dimensions.Bottom, FProjection.Dimensions.Top)
  );

  Result := CameraToWorldMatrix.MultPoint(Vector3(P, 0)).XY;
end;

procedure TCastleViewport.SetItems(const Value: TCastleRootTransform);
begin
  if FItems <> Value then
  begin
    if Value = nil then
      raise EInternalError.Create('Cannot set TCastleSceneManager.Items to nil');
    FItems := Value;
  end;
end;

procedure TCastleViewport.ItemsVisibleChange(const Sender: TCastleTransform; const Changes: TVisibleChanges);
begin
  { merely schedule broadcasting this change to a later time.
    This way e.g. animating a lot of transformations doesn't cause a lot of
    "visible change notifications" repeatedly on the same 3D object within
    the same frame. }
  ScheduledVisibleChangeNotification := true;
  ScheduledVisibleChangeNotificationChanges := ScheduledVisibleChangeNotificationChanges + Changes;
end;

function TCastleViewport.GetPaused: Boolean;
begin
  Result := Items.Paused;
end;

procedure TCastleViewport.SetPaused(const Value: Boolean);
begin
  Items.Paused := Value;
end;

function TCastleViewport.CameraToChanges(const ACamera: TCastleCamera): TVisibleChanges;
begin
  // headlight exists, and we changed camera controlling headlight
  if (Items.InternalHeadlight <> nil) and
     (ACamera = Items.MainCamera) then
    Result := [vcVisibleNonGeometry]
  else
    Result := [];
end;

function TCastleViewport.GetMainScene: TCastleScene;
begin
  Result := Items.MainScene;
end;

function TCastleViewport.MouseRayHitContains(const Item: TCastleTransform): boolean;
begin
  Result := (MouseRayHit <> nil) and
            (MouseRayHit.IndexOfItem(Item) <> -1);
end;

procedure TCastleViewport.SetMouseRayHit(const Value: TRayCollision);
var
  I: Integer;
begin
  if FMouseRayHit <> Value then
  begin
    { Always keep FreeNotification on every 3D item inside MouseRayHit.
      When it's destroyed, our MouseRayHit must be freed too,
      it cannot be used in subsequent RecalculateCursor. }

    if FMouseRayHit <> nil then
    begin
      for I := 0 to FMouseRayHit.Count - 1 do
      begin
        { leave free notification for 3D item if it's also present somewhere else }
        if (FMouseRayHit[I].Item <> FAvoidNavigationCollisions) then
          FMouseRayHit[I].Item.RemoveFreeNotification(Self);
      end;
      FreeAndNil(FMouseRayHit);
    end;

    FMouseRayHit := Value;

    if FMouseRayHit <> nil then
    begin
      for I := 0 to FMouseRayHit.Count - 1 do
        FMouseRayHit[I].Item.FreeNotification(Self);
    end;
  end;
end;

procedure TCastleViewport.SetAvoidNavigationCollisions(const Value: TCastleTransform);
begin
  if FAvoidNavigationCollisions <> Value then
  begin
    if FAvoidNavigationCollisions <> nil then
    begin
      { leave free notification for FAvoidNavigationCollisions if it's also present somewhere else }
      if (not MouseRayHitContains(FAvoidNavigationCollisions)) then
        FAvoidNavigationCollisions.RemoveFreeNotification(Self);
    end;

    FAvoidNavigationCollisions := Value;

    if FAvoidNavigationCollisions <> nil then
      FAvoidNavigationCollisions.FreeNotification(Self);
  end;
end;

procedure TCastleViewport.PrepareResources(const Item: TCastleTransform;
  const DisplayProgressTitle: string;
  Options: TPrepareResourcesOptions);
var
  MainLightPosition: TVector4; // value of this is ignored
begin
  if GLFeatures.ShadowVolumesPossible and
     ShadowVolumes and
     MainLightForShadows(MainLightPosition) then
    Include(Options, prShadowVolume);

  { call TCastleScreenEffects.PrepareResources. }
  inherited PrepareResources;

  if ContainerSizeKnown then
  begin
    { Apply projection now, it calculates
      MainScene.BackgroundSkySphereRadius, which is used by MainScene.Background.
      Otherwise our preparations of "prBackground" here would be useless,
      as BackgroundSkySphereRadius will change later, and MainScene.Background
      will have to be recreated. }
    ApplyProjection;
  end;

  { RenderingCamera properties must be already set,
    since PrepareResources may do some operations on texture gen modes
    in WORLDSPACE*. }
  RenderingCamera.FromCameraObject(Camera);

  if DisplayProgressTitle <> '' then
  begin
    Progress.Init(Items.PrepareResourcesSteps, DisplayProgressTitle, true);
    try
      Item.PrepareResources(Options, true, PrepareParams);
    finally Progress.Fini end;
  end else
    Item.PrepareResources(Options, false, PrepareParams);
end;

procedure TCastleViewport.PrepareResources(const DisplayProgressTitle: string;
  const Options: TPrepareResourcesOptions);
begin
  PrepareResources(Items, DisplayProgressTitle, Options);
end;

procedure TCastleViewport.BeforeRender;
begin
  inherited;

  { Do it only once, otherwise BeforeRender eats time each frame
    (traversing TCastleTransform tree one more time, usually doing nothing if
    the TCastleScene are already prepared). }
  if not PrepareResourcesDone then
  begin
    PrepareResources;
    PrepareResourcesDone := true;
  end;
end;

function TCastleViewport.PointingDeviceActivate(const Active: boolean): boolean;

  { Try PointingDeviceActivate on 3D stuff hit by RayHit }
  function TryActivate(RayHit: TRayCollision): boolean;
  var
    PassToMainScene: boolean;
    I: Integer;
  begin
    { call TCastleTransform.PointingDeviceActivate on everything, calculate Result }
    Result := false;
    PassToMainScene := true;

    if RayHit <> nil then
      for I := 0 to RayHit.Count - 1 do
      begin
        if RayHit[I].Item = Items.MainScene then
          PassToMainScene := false;
        Result := PointingDeviceActivate3D(RayHit[I].Item, Active, RayHit.Distance);
        if Result then
        begin
          PassToMainScene := false;
          Break;
        end;
      end;

    if PassToMainScene and (Items.MainScene <> nil) then
      Result := PointingDeviceActivate3D(Items.MainScene, Active, MaxSingle);
  end;

var
  MousePosition: TVector2;

  { Try PointingDeviceActivate on 3D stuff hit by ray moved by given number
    of screen pixels from current mouse position.
    Call only if MousePosition already assigned. }
  function TryActivateAround(const Change: TVector2): boolean;
  var
    RayOrigin, RayDirection: TVector3;
    RayHit: TRayCollision;
  begin
    Camera.CustomRay(RenderRect, MousePosition + Change,
      FProjection, RayOrigin, RayDirection);

    RayHit := CameraRayCollision(RayOrigin, RayDirection);

    { We do not really have to check "RayHit <> nil" below,
      as TryActivate can (and should) work even with RayHit=nil case.
      However, we know that TryActivate will not do anything new if RayHit=nil
      (it will just pass this to MainScene, which was already done before
      trying ApproximateActivation). }

    Result := (RayHit <> nil) and TryActivate(RayHit);

    FreeAndNil(RayHit);
  end;

  function TryActivateAroundSquare(const Change: Single): boolean;
  begin
    Result := TryActivateAround(Vector2(-Change, -Change)) or
              TryActivateAround(Vector2(-Change, +Change)) or
              TryActivateAround(Vector2(+Change, +Change)) or
              TryActivateAround(Vector2(+Change, -Change)) or
              TryActivateAround(Vector2(      0, -Change)) or
              TryActivateAround(Vector2(      0, +Change)) or
              TryActivateAround(Vector2(-Change,       0)) or
              TryActivateAround(Vector2(+Change,       0));
  end;

  { If Container assigned, set local MousePosition. }
  function GetMousePosition: boolean;
  var
    C: TUIContainer;
  begin
    C := Container;
    Result := C <> nil;
    if Result then
      MousePosition := C.MousePosition;
  end;

begin
  Result := TryActivate(MouseRayHit);
  if not Result then
  begin
    if ApproximateActivation and GetMousePosition then
      Result := TryActivateAroundSquare(25) or
                TryActivateAroundSquare(50) or
                TryActivateAroundSquare(100) or
                TryActivateAroundSquare(200);
  end;

  if not Result then
    PointingDeviceActivateFailed(Active);
end;

function TCastleViewport.PointingDeviceActivate3D(const Item: TCastleTransform;
  const Active: boolean; const Distance: Single): boolean;
begin
  Result := Item.PointingDeviceActivate(Active, Distance);
end;

procedure TCastleViewport.PointingDeviceActivateFailed(const Active: boolean);
begin
  if Active then
    SoundEngine.Sound(stPlayerInteractFailed);
end;

function TCastleViewport.PointingDeviceMove(
  const RayOrigin, RayDirection: TVector3): boolean;
var
  PassToMainScene: boolean;
  I: Integer;
  MainSceneNode: TRayCollisionNode;
begin
  { update MouseRayHit.
    We know that RayDirection is normalized now, which is important
    to get correct MouseRayHit.Distance. }
  SetMouseRayHit(CameraRayCollision(RayOrigin, RayDirection));

  { call TCastleTransform.PointingDeviceMove on everything, calculate Result }
  Result := false;
  PassToMainScene := true;

  if MouseRayHit <> nil then
    for I := 0 to MouseRayHit.Count - 1 do
    begin
      if MouseRayHit[I].Item = Items.MainScene then
        PassToMainScene := false;
      Result := MouseRayHit[I].Item.PointingDeviceMove(MouseRayHit[I], MouseRayHit.Distance);
      if Result then
      begin
        PassToMainScene := false;
        Break;
      end;
    end;

  if PassToMainScene and (Items.MainScene <> nil) then
  begin
    MainSceneNode.Item := Items.MainScene;
    { if ray hit something, then the outermost 3D object should just be our Items,
      and it contains the 3D point picked.
      This isn't actually used by anything now --- TRayCollisionNode.Point
      is for now used only by TCastleSceneCore, and only when Triangle <> nil. }
    if MouseRayHit <> nil then
      MainSceneNode.Point := MouseRayHit.Last.Point else
      MainSceneNode.Point := TVector3.Zero;
    MainSceneNode.RayOrigin := RayOrigin;
    MainSceneNode.RayDirection := RayDirection;
    MainSceneNode.Triangle := nil;
    Result := Items.MainScene.PointingDeviceMove(MainSceneNode, MaxSingle);
  end;
end;

procedure TCastleViewport.VisibleChange(const Changes: TCastleUserInterfaceChanges;
  const ChangeInitiatedByChildren: boolean = false);

  procedure CameraChange;
  var
    Pos, Dir, Up: TVector3;
    MC: TCastleCamera;
  begin
    MC := Items.MainCamera;
    if MC = Camera then
    begin
      { Call CameraChanged on all TCastleTransform.
        Note that we have to call it on all Items, not just MainScene,
        to make ProximitySensor, Billboard etc. to work in all scenes, not just in MainScene. }
      Items.CameraChanged(Camera);
      { ItemsVisibleChange may again cause this VisibleChange (if we are TCastleViewport),
        but without chCamera, so no infinite recursion. }
      ItemsVisibleChange(Items, CameraToChanges(Camera));

      Camera.GetView(Pos, Dir, Up);
      SoundEngine.UpdateListener(Pos, Dir, Up);
    end;

    if Assigned(OnCameraChanged) then
      OnCameraChanged(Self);
  end;

begin
  inherited;
  if chCamera in Changes then
    CameraChange;
end;

function TCastleViewport.NavigationMoveAllowed(ANavigation: TCastleWalkNavigation;
  const ProposedNewPos: TVector3; out NewPos: TVector3;
  const BecauseOfGravity: boolean): boolean;

  function PositionOutsideBoundingBox: Boolean;
  var
    CameraPos: TVector3;
    Box: TBox3D;
    GravityCoordinate, Coord1, Coord2: Integer;
  begin
    CameraPos := Camera.Position;
    Box := ItemsBoundingBox;
    if Box.IsEmpty then Exit(false);
    GravityCoordinate := MaxAbsVectorCoord(NewPos - CameraPos);
    RestOf3DCoords(GravityCoordinate, Coord1, Coord2);
    { Do not fall down if CamePos is outside of Box.
      But in case camera is *above* Box, consider it *inside* the box
      (gravity will work there).
      This is useful to allow jumping on top of the scene work naturally. }
    Result :=
      (CameraPos[Coord1] < Box.Data[0][Coord1]) or
      (CameraPos[Coord1] > Box.Data[1][Coord1]) or
      (CameraPos[Coord2] < Box.Data[0][Coord2]) or
      (CameraPos[Coord2] > Box.Data[1][Coord2]) or
      (CameraPos[GravityCoordinate] < Box.Data[0][GravityCoordinate]);
  end;

begin
  { Both version result in calling WorldMoveAllowed.
    AvoidNavigationCollisions version adds AvoidNavigationCollisions.Disable/Enable around. }

  // take into account PreventInfiniteFallingDown
  if BecauseOfGravity and
     PreventInfiniteFallingDown and
     PositionOutsideBoundingBox then
    Exit(false);

  if AvoidNavigationCollisions <> nil then
    Result := AvoidNavigationCollisions.MoveAllowed(Camera.Position, ProposedNewPos, NewPos, BecauseOfGravity)
  else
    Result := Items.WorldMoveAllowed(Camera.Position, ProposedNewPos, NewPos,
      true, ANavigation.Radius,
      { We prefer to resolve collisions with navigation using sphere.
        But for TCastleTransform implementations that can't use sphere, we can construct box. }
      Box3DAroundPoint(Camera.Position, ANavigation.Radius * 2),
      Box3DAroundPoint(ProposedNewPos, ANavigation.Radius * 2), BecauseOfGravity);
end;

function TCastleViewport.NavigationHeight(ANavigation: TCastleWalkNavigation;
  const Position: TVector3;
  out AboveHeight: Single; out AboveGround: PTriangle): boolean;
begin
  { Both version result in calling WorldHeight.
    AvoidNavigationCollisions version adds AvoidNavigationCollisions.Disable/Enable around. }

  if AvoidNavigationCollisions <> nil then
    Result := AvoidNavigationCollisions.Height(Position, AboveHeight, AboveGround)
  else
    Result := Items.WorldHeight(Position, AboveHeight, AboveGround);
end;

function TCastleViewport.CameraRayCollision(const RayOrigin, RayDirection: TVector3): TRayCollision;
begin
  { Both version result in calling WorldRay.
    AvoidNavigationCollisions version adds AvoidNavigationCollisions.Disable/Enable around. }

  if AvoidNavigationCollisions <> nil then
    Result := AvoidNavigationCollisions.Ray(RayOrigin, RayDirection)
  else
    Result := Items.WorldRay(RayOrigin, RayDirection);
end;

procedure TCastleViewport.BoundViewpointChanged;
begin
  if Assigned(OnBoundViewpointChanged) then
    OnBoundViewpointChanged(Self);
end;

procedure TCastleViewport.BoundNavigationInfoChanged;
begin
  if Assigned(OnBoundNavigationInfoChanged) then
    OnBoundNavigationInfoChanged(Self);
end;

procedure TCastleViewport.MainSceneAndCamera_BoundViewpointChanged(Sender: TObject);
begin
  if AutoCamera then
  begin
    Items.MainScene.InternalUpdateCamera(Camera, ItemsBoundingBox, false);
    BoundViewpointChanged;
  end;
end;

procedure TCastleViewport.MainSceneAndCamera_BoundNavigationInfoChanged(Sender: TObject);
begin
  if AutoNavigation and (Navigation <> nil) then
  begin
    NavigationType := Items.MainScene.NavigationTypeFromNavigationInfo;
    Items.MainScene.InternalUpdateNavigation(Navigation, Items.BoundingBox);
  end;
  BoundNavigationInfoChanged;
end;

procedure TCastleViewport.MainSceneAndCamera_BoundViewpointVectorsChanged(Sender: TObject);
begin
  { TODO: It may be useful to enable camera animation by some specific property,
    like AnimateCameraByViewpoint (that works even when AutoCamera = false,
    as we advise for new scene managers). }
  if AutoCamera { or AnimateCameraByViewpoint } then
    Items.MainScene.InternalUpdateCamera(Camera, ItemsBoundingBox, true);
end;

class procedure TCastleViewport.CreateComponentSetup2D(Sender: TObject);
begin
  (Sender as TCastleViewport).Setup2D;
end;

procedure TCastleViewport.SetSceneManager(const Value: TCastleSceneManager);
begin
  {$warnings off} // only to keep deprecated feature working
  if Value <> FSceneManager then
  begin
    if SceneManager <> nil then
      SceneManager.Viewports.Remove(Self);
    FSceneManager := Value;
    if SceneManager <> nil then
      SceneManager.Viewports.Add(Self);
  end;
  {$warnings on}
end;

{$define read_implementation_methods}
{$I auto_generated_persistent_vectors/tcastleviewport_persistent_vectors.inc}
{$undef read_implementation_methods}

{ TCastleViewportList -------------------------------------------------- }

procedure TCastleViewportList.Notify(constref Value: TCastleViewport;
  Action: TCollectionNotification);
begin
  inherited;

  { Note that SceneManager itself is also on SceneManager.Viewports list,
    depending on SceneManager.DefaultViewport value.
    Ignore it below, since we don't want to change SceneManager.Items value. }
  if Value <> SceneManager then
  begin
    if Action = cnAdded then
      Value.Items := SceneManager.Items
    else
      // Action in [cnRemoved, cnExtracted]
      Value.Items := TCastleRootTransform.Create(Value);
  end;
end;

{ TCastleSceneManager -------------------------------------------------------- }

constructor TCastleSceneManager.Create(AOwner: TComponent);
begin
  inherited;

  FDefaultViewport := true;
  FullSize := true;
  AutoNavigation := true;
  AutoCamera := true;

  {$warnings off} // using deprecated in deprecated
  FViewports := TCastleViewportList.Create(false);
  {$warnings on}
  FViewports.SceneManager := Self;
  if DefaultViewport then FViewports.Add(Self);
end;

destructor TCastleSceneManager.Destroy;
var
  I: Integer;
begin
  if FViewports <> nil then
  begin
    for I := 0 to FViewports.Count - 1 do
      if FViewports[I] is TCastleViewport then
      begin
        {$warnings off} // using deprecated in deprecated
        Assert(
          (TCastleViewport(FViewports[I]).SceneManager = Self) or
          (TCastleViewport(FViewports[I]).SceneManager = nil)
        );
        {$warnings on}

        { Set SceneManager by direct field (FSceneManager),
          otherwise TCastleViewport.SetSceneManager would try to update
          our Viewports list, that we iterate over right now... }
        TCastleViewport(FViewports[I]).FSceneManager := nil;
      end;
    FreeAndNil(FViewports);
  end;

  inherited;
end;

procedure TCastleSceneManager.Render;
begin
  if not DefaultViewport then Exit;
  inherited;
end;

procedure TCastleSceneManager.SetDefaultViewport(const Value: boolean);
begin
  if Value <> FDefaultViewport then
  begin
    FDefaultViewport := Value;
    if DefaultViewport then
      Viewports.Add(Self)
    else
      Viewports.Remove(Self);
  end;
end;

function TCastleSceneManager.GetMainCamera: TCastleCamera;
begin
  Result := Items.MainCamera;
end;

procedure TCastleSceneManager.SetMainCamera(const Value: TCastleCamera);
begin
  Items.MainCamera := Value;
end;

function TCastleSceneManager.GetMainSceneInternal: TCastleScene;
begin
  Result := Items.MainScene;
end;

procedure TCastleSceneManager.SetMainScene(const Value: TCastleScene);
begin
  Items.MainScene := Value;
end;

function TCastleSceneManager.GetUseHeadlight: TUseHeadlight;
begin
  Result := Items.UseHeadlight;
end;

procedure TCastleSceneManager.SetUseHeadlight(const Value: TUseHeadlight);
begin
  Items.UseHeadlight := Value;
end;

function TCastleSceneManager.GravityUp: TVector3;
begin
  Result := Camera.GravityUp;
end;

function TCastleSceneManager.GetHeadlightNode: TAbstractLightNode;
begin
  Result := Items.HeadlightNode;
end;

procedure TCastleSceneManager.SetHeadlightNode(const Value: TAbstractLightNode);
begin
  Items.HeadlightNode := Value;
end;

function TCastleSceneManager.GetMoveLimit: TBox3D;
begin
  Result := Items.MoveLimit;
end;

procedure TCastleSceneManager.SetMoveLimit(const Value: TBox3D);
begin
  Items.MoveLimit := Value;
end;

function TCastleSceneManager.PhysicsProperties: TPhysicsProperties;
begin
  Result := Items.PhysicsProperties;
end;

function TCastleSceneManager.GetTimeScale: Single;
begin
  Result := Items.TimeScale;
end;

procedure TCastleSceneManager.SetTimeScale(const Value: Single);
begin
  Items.TimeScale := Value;
end;

var
  R: TRegisteredComponent;
initialization
  Input_Interact := TInputShortcut.Create(nil, 'Interact (press, open door)', 'interact', igOther);
  Input_Interact.Assign(K_None, K_None, '', true, mbLeft);

  R := TRegisteredComponent.Create;
  {$warnings off} // using deprecated, to keep reading it from castle-user-interface working
  R.ComponentClass := TCastleSceneManager;
  {$warnings on}
  R.Caption := 'Scene Manager';
  R.IsDeprecated := true;
  RegisterSerializableComponent(R);

  RegisterSerializableComponent(TCastleViewport, 'Viewport');

  R := TRegisteredComponent.Create;
  R.ComponentClass := TCastleViewport;
  R.Caption := 'Viewport (Configured For 2D)';
  R.OnCreate := @TCastleViewport(nil).CreateComponentSetup2D;
  RegisterSerializableComponent(R);

  InitializeWarmupCache;
end.
