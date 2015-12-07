{ ****************************************************************************
  Ani95.pas                 Copyright © 1996-2001 DithoSoft Software Solutions
  Version 2.6                                          http://www.dithosoft.de
  ----------------------------------------------------------------------------
  Displays AVI-Clips in forms. Covers the Windows 95 CommonControl. CAN ONLY
  PLAY 8-BIT AVIs NOT CONTAINING SOUND (sorry, not my fault...)
  ----------------------------------------------------------------------------
  Changes/New features: - Delphi 6 compatibility
                        - Publishes some more useful properties
  ----------------------------------------------------------------------------
  Known problems:       - The application hangs if you try to load an AVI from
                          a DLL by calling LoadLibrary/FreeLibrary in the DPR.
                          FreeLibrary is somehow called before the control is
                          destroyed.

  Workarounds:          - Don´t load the DLL(s) in the project file! Write a
                          unit containing global variables to save the handle(s)
                          and use the initialization/finalization blocks to load
                          or free the libraries. Make sure this/these units are
                          the first units included in the project file in order
                          of their internal dependencies. Please view the exam-
                          ples in the help file for detailed info.
  ----------------------------------------------------------------------------
  History:              - 1.0  1st implementation for personal use
                        - 1.1  1st public release (help file, bug fixes)
                        - 2.0  2nd public release (some new features see above)
                        - 2.1  bugfixes, Open-dialog for AVIFile property,
                               removed AVIStandard property as it didn´t work
                               with D2
                        - 2.5  tested and modified for Delphi 5 compatibility
                        - 2.5a further improved Delphi 5 compatibility
                        - 2.6  Delphi 6 compatibility, now uses all features
                               introduced in Delphi 5
  ----------------------------------------------------------------------------
  Credits:              - Thank you, Rhett Hermer
                          for feedback, bugfixing, adding the new property
                          RepeatCount, suggesting the Open-dialog feature
                        - Thank you, Torsten Mohs
                          for bugfixing
  **************************************************************************** }
unit ani95;

{$DEFINE DELPHI5OR6}
{$DEFINE NEWERDELPHI}

{$IFNDEF VER130}
  {$IFNDEF VER140}
    {$UNDEF DELPHI5OR6}
  {$ENDIF}
{$ENDIF}

{$IFDEF VER90}
  {$UNDEF NEWERDELPHI}
{$ENDIF}
{$IFDEF VER80}
  {$UNDEF NEWERDELPHI}
{$ENDIF}

{$R-,B-,Q-}

interface

uses
  Windows, Messages, Classes, Controls, StdCtrls;

type
  { TAnimation Component }
  TAnimation = class(TWinControl)
  private
    FCW, FCH       : Integer;     // Width and Height if Center is False
    FAVIFile,                     // Filename of AVI file
    FAVIResName    : String;      // Resourcename of AVI resource
    FAVIResID      : Integer;     // ResourceID of AVI resource
    FAVIResHandle  : THandle;     // Handle of module containing resource
    FCenter,                      // Center clip in control
    FTransparent,                 // Display clip transparently
    FPlaying,                     // Play the clip
    FOpened        : Boolean;     // True if clip was opened successfully
    FStartFrame,                  // Frame to start with
    FEndFrame      : SmallInt;    // Frame to end with
    FRepeatCount   : Integer;     // Number of repetitions
    FOnStart,                     // Called when playback starts
    FOnStop        : TNotifyEvent;// Called when playback stops

    { Property methods }
    procedure SetAVIFile(Value: String);
    procedure SetAVIResName(Value: String);
    procedure SetAVIResID(Value: Integer);
    procedure SetAVIResHandle(Value: THandle);
    procedure SetCenter(Value: Boolean);
    procedure SetTransparent(Value: Boolean);
    procedure SetPlaying(Value: Boolean);
    procedure SetStartFrame(Value: SmallInt);
    procedure SetEndFrame(Value: SmallInt);
    procedure SetRepeatCount(Value: Integer);
    procedure SetOnStart(Value: TNotifyEvent);
    procedure SetOnStop(Value: TNotifyEvent);

    { Internal utility methods }
    function  GetDesiredModuleHandle: THandle;
    function  GetDesiredAVI: Integer;
    procedure OpenAnimation;
    procedure UpdateAnimation;

    { Eventhandlers }
    procedure CNCommand(var Msg: TWMCommand); message CN_COMMAND;
    procedure CMColorChanged(var Msg: TMessage); message CM_COLORCHANGED;
    procedure WMWindowPosChanging(var Msg: TWMWindowPosChanging); message WM_WINDOWPOSCHANGING;
  protected
    { Creating the window }
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DestroyWnd; override;
    procedure Loaded; override;
    procedure LaunchOnStartEvent; virtual;
    procedure LaunchOnStopEvent; virtual;
  public
    { Creating the class }
    constructor Create(AOwner: TComponent); override;

    { Public methods }
    procedure Play; virtual;
    procedure Stop; virtual;

    { Public properties }
    property AVIResName: String read FAVIResName write SetAVIResName;
    property AVIResID: Integer read FAVIResID write SetAVIResID;
    property AVIResHandle: THandle read FAVIResHandle write SetAVIResHandle;
    property Opened: Boolean read FOpened;
  published
    { Published properties }
    property AVIFile: String read FAVIFile write SetAVIFile;
    property Center: Boolean read FCenter write SetCenter;
    property Transparent: Boolean read FTransparent write SetTransparent;
    property Playing: Boolean read FPlaying write SetPlaying;
    property StartFrame: SmallInt read FStartFrame write SetStartFrame;
    property EndFrame: SmallInt read FEndFrame write SetEndFrame;
    property RepeatCount: Integer read FRepeatCount write SetRepeatCount;

    {$IFDEF DELPHI5OR6}
    property Action;
    property Anchors;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    {$ENDIF}
    
    property Color;
    property ParentColor;
    property ParentShowHint;
    property ShowHint;
    property Visible;

    property OnStart: TNotifyEvent read FOnStart write SetOnStart;
    property OnStop: TNotifyEvent read FOnStop write SetOnStop;
  end;

implementation

uses
  SysUtils, CommCtrl, Dialogs;


{$IFNDEF NEWERDELPHI}
const
{$ELSE}
resourcestring
{$ENDIF}
      Msg_StartFrame1 = 'StartFrame must be >= 1!';
      Msg_StartFrame2 = 'StartFrame must be <= EndFrame!';
      Msg_EndFrame    = 'EndFrame must be 0 or >= StartFrame!';
      Msg_RepeatCount = 'RepeatCount must be >= 0!';


{ ****************************************************************************
  TAnimation...
  **************************************************************************** }
constructor TAnimation.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  { Draw a frame around the component when in design mode }
  ControlStyle := [csOpaque];
  if csDesigning in ComponentState then
    ControlStyle := ControlStyle+[csFramed];

  { Set ancestor´s properties }
  Width  := 64;
  Height := 64;

  { Set new properties }
  FAVIFile       := '';
  FAVIResName    := '';
  FAVIResID      := 0;
  FAVIResHandle  := 0;
  FCenter        := True;
  FTransparent   := True;
  FPlaying       := False;
  FOpened        := False;
  FStartFrame    := 1;
  FEndFrame      := 0;
  FRepeatCount   := 0;
  FOnStart       := Nil;
  FOnStop        := Nil;
end;

{ ----------------------------------------------------------------------------
  Creation of window
  ---------------------------------------------------------------------------- }
procedure TAnimation.CreateParams(var Params: TCreateParams);
begin
  { Initialize COMMCTRL.DLL and the Params record }
  InitCommonControls;
  inherited CreateParams(Params);

  { Create the common control in the same instance where the AVI is stored }
  Params.WindowClass.hInstance := GetDesiredModuleHandle;
  CreateSubClass(Params, ANIMATE_CLASS);

  { Set window class style and assign a unique name }
  Params.WindowClass.Style := Params.WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW);
  StrFmt(Params.WinClassName,'Animation(%.8X,%.8X)',[GetTickCount,HInstance]);

  { Include the properties }
  with Params do begin
    { Centered display }
    if FCenter then
      Style := Style or ACS_CENTER;

    { Transparent display }
    if FTransparent then
      Style := Style or ACS_TRANSPARENT;
  end;
end;

procedure TAnimation.DestroyWnd;
begin
  FOpened := False;
  inherited DestroyWnd;
end;

procedure TAnimation.Loaded;
begin
  inherited Loaded;
  UpdateAnimation;
end;

{ ----------------------------------------------------------------------------
  Public methods
  ---------------------------------------------------------------------------- }
procedure TAnimation.Play;
begin
  Playing := True;
end;

procedure TAnimation.Stop;
begin
  Playing := False;
end;

{ ----------------------------------------------------------------------------
  Eventhandlers
  ---------------------------------------------------------------------------- }
procedure TAnimation.CNCommand(var Msg: TWMCommand);
begin
  inherited;

  { Handle notifications -> Launch corresponding On...-Event }
  case Msg.NotifyCode of
    ACN_START: LaunchOnStartEvent;
    ACN_STOP : begin
                 LaunchOnStopEvent;
                 FPlaying := False; { When RepeatCount > 0! }
               end;
  end;
end;

procedure TAnimation.CMColorChanged(var Msg: TMessage);
begin
  { Recreate all when the color property is changed (transparency!) }
  inherited;
  UpdateAnimation;
end;

procedure TAnimation.WMWindowPosChanging(var Msg: TWMWindowPosChanging);
begin
  { Keep AVI width and height if Center is False }
  if not Center and Opened then begin
    Msg.WindowPos^.CX := FCW;
    Msg.WindowPos^.CY := FCH;
  end else
    inherited;
end;


{ ----------------------------------------------------------------------------
  Internal utility methods
  ---------------------------------------------------------------------------- }
function TAnimation.GetDesiredModuleHandle: THandle;
var ModHandle: THandle;
begin
  { Return the module handle of the module where AVI is to be loaded from }
  if FAVIResHandle <> 0 then
    ModHandle := FAVIResHandle
  else
    ModHandle := HInstance;

  Result := ModHandle;
end;

function TAnimation.GetDesiredAVI: Integer;
begin
  { Return the ID of the AVI to be loaded }
  if FAVIFile <> '' then
    Result := Integer(FAVIFile)
  else if (FAVIResName <> '') then
    Result := Integer(FAVIResName)
  else
    Result := FAVIResID;
end;

procedure TAnimation.OpenAnimation;
begin
  { This requires a window handle! }
  HandleNeeded;

  { No current AVI in case of error }
  FOpened := False;

  { Load new AVI and display FStartFrame}
  FOpened := Perform(ACM_OPEN,GetDesiredModuleHandle,GetDesiredAVI) <> 0;
  if FOpened then begin
    Perform(ACM_PLAY,1,MakeLong(Pred(FStartFrame),Pred(FStartFrame)));
    FCW := Width;
    FCH := Height;
  end;
end;

procedure TAnimation.UpdateAnimation;
var p: Boolean;
begin
  { Only after the loading process is finished }
  if csLoading in ComponentState then
    exit;

  { Stop playback, but save state }
  p := Playing;
  Playing := False;

  { Recreate all }
  RecreateWnd;
  OpenAnimation;

  { restore state }
  Playing := p;
end;

procedure TAnimation.LaunchOnStartEvent;
begin
  if Assigned(FOnStart) then FOnStart(Self);
end;

procedure TAnimation.LaunchOnStopEvent;
begin
  if Assigned(FOnStop) then FOnStop(Self);
end;

{ ----------------------------------------------------------------------------
  Property methods
  ---------------------------------------------------------------------------- }
procedure TAnimation.SetAVIFile(Value: String);
begin
  if (Value <> FAVIFile) then begin
   FAVIFile      := Value;
   FAVIResName   := '';
   FAVIResID     := 0;
   FAVIResHandle := 0;

   UpdateAnimation;
  end;
end;

procedure TAnimation.SetAVIResName(Value: String);
begin
  if (Value <> FAVIResName) then begin
    FAVIResName   := Value;
    FAVIResID     := 0;
    FAVIFile      := '';

    UpdateAnimation;
  end;
end;

procedure TAnimation.SetAVIResID(Value: Integer);
begin
  if (Value <> FAVIResID) then begin
    FAVIResID     := Value;
    FAVIResName   := '';
    FAVIFile      := '';

    UpdateAnimation;
  end;
end;

procedure TAnimation.SetAVIResHandle(Value: THandle);
begin
  if (Value <> FAVIResHandle) then begin
    FAVIResHandle := Value;
    FAVIFile      := '';

    UpdateAnimation;
  end;
end;

procedure TAnimation.SetCenter(Value: Boolean);
begin
  if (Value <> FCenter) then begin
    FCenter := Value;
    UpdateAnimation;
  end;
end;

procedure TAnimation.SetTransparent(Value: Boolean);
begin
  if (Value <> FTransparent) then begin
    FTransparent := Value;
    UpdateAnimation;
  end;
end;

procedure TAnimation.SetPlaying(Value: Boolean);
var Rep: Integer;
begin
  { Don´t continue if no AVI is loaded }
  if not Opened then exit;

  if (Value <> FPlaying) then begin
    FPlaying := Value;

    { Calc repetitions }
    if FRepeatCount = 0 then
      Rep := -1
    else
      Rep := FRepeatCount;

    { Either play or stop and display StartFrame }
    if FPlaying then
      Perform(ACM_PLAY,Rep,MakeLong(Pred(FStartFrame),Pred(FEndFrame)))
    else begin
      Perform(ACM_STOP,0,0);
      Perform(ACM_PLAY,1,MakeLong(Pred(FStartFrame),Pred(FStartFrame)));
    end;
  end;
end;

procedure TAnimation.SetStartFrame(Value: SmallInt);
var p: Boolean;
begin
  { Don´t allow Value < 1! }
  if Value < 1 then begin
    MessageDlg(Msg_StartFrame1,mtError,[mbOk],0);
    Exit;
  end;

  { Don´t allow Value > EndFrame }
  if (Value > FEndFrame) and (FEndFrame > 0) then begin
    MessageDlg(Msg_StartFrame2,mtError,[mbOk],0);
    Exit;
  end;

  { Stop playback, but save state }
  FStartFrame := Value;
  p           := Playing;
  Playing     := False;

  { When playing: stop and start with new frame, otherwise display StartFrame }
  if P then
    SetPlaying(True);
end;

procedure TAnimation.SetEndFrame(Value: SmallInt);
var p: Boolean;
begin
  { Don´t allow Value < StartFrame, except for 0! }
  if (Value < 0) or ((Value > 0) and (Value < FStartFrame)) then begin
    MessageDlg(Msg_EndFrame,mtError,[mbOk],0);
    Exit;
  end;

  { Stop playback, but save state }
  FEndFrame := Value;
  p         := Playing;
  Playing   := False;

  { When playing: stop and start with new frame, otherwise display StartFrame }
  if p then
    SetPlaying(True);
end;

procedure TAnimation.SetRepeatCount(Value: Integer);
var p: Boolean;
begin
  { Don´t allow Value < 0! }
  if Value < 0 then begin
    MessageDlg(Msg_RepeatCount,mtError,[mbOk],0);
    Exit;
  end;

  { Stop playback, but save state }
  FRepeatCount := Value;
  p            := Playing;
  Playing      := False;

  { When playing: stop and start with new frame, otherwise display StartFrame }
  if p then
    SetPlaying(True)
end;

procedure TAnimation.SetOnStart(Value: TNotifyEvent);
begin
  FOnStart := Value;
end;

procedure TAnimation.SetOnStop(Value: TNotifyEvent);
begin
  FOnStop := Value;
end;

end.



