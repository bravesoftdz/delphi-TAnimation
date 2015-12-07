{ ****************************************************************************
  ani95reg.pas              Copyright © 1996-2001 DithoSoft Software Solutions
  Version 2.6                                          http://www.dithosoft.de
  ----------------------------------------------------------------------------
  This unit contains designtime tools for the Ani95 unit. It may not be
  installed in runtime packages, but in designtime-only packages only.
  **************************************************************************** }
unit ani95reg;

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

interface

{$IFDEF VER140}
uses DesignIntf, DesignEditors, VCLEditors;
{$ELSE}
uses DsgnIntf;
{$ENDIF}

type
  { New items for component´s context-menu }
  TAnimationEditor = class(TComponentEditor)
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): String; override;
    procedure ExecuteVerb(Index: Integer); override;
    procedure Edit; override;
  end;

  { Property editor for AVIFile property }
  TAVIFileProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

procedure Register;

implementation

uses ani95, Classes, Dialogs, Forms;

{$IFDEF NEWERDELPHI}
resourcestring
{$ELSE}
const
{$ENDIF}
      VerbInfo        = 'Info...';
      Msg_AniVer      = 'TAnimation 2.6'#13+
                        'Copyright © 1996-2001 DithoSoft Software Solutions';

procedure Register;
begin
  RegisterComponents('Freeware', [TAnimation]);
  RegisterComponentEditor(TAnimation,TAnimationEditor);
  RegisterPropertyEditor(TypeInfo(String),TAnimation,'AVIFile',TAVIFileProperty);

  {$IFDEF DELPHI5OR6}
  RegisterPropertiesInCategory({$IFDEF VER130}TVisualCategory{$ELSE}'Visual'{$ENDIF},TAnimation,['AVIFile','Center','Transparent']);
  RegisterPropertiesInCategory({$IFDEF VER130}TInputCategory{$ELSE}'Input'{$ENDIF},TAnimation,['Playing','StartFrame','EndFrame','RepeatCount']);
  RegisterPropertiesInCategory({$IFDEF VER130}TLocalizableCategory{$ELSE}'Localizable'{$ENDIF},TAnimation,['AVIFile']);
  {$ENDIF}
end;

{ ****************************************************************************
  TAnimationEditor...
  **************************************************************************** }
function TAnimationEditor.GetVerbCount: Integer;
begin
  { Only one new item for the menu }
  Result := 1;
end;

function TAnimationEditor.GetVerb(Index: Integer): String;
begin
  if Index = 0 then Result := VerbInfo;
end;

procedure TAnimationEditor.ExecuteVerb(Index: Integer);
begin
  if Index = 0 then
    MessageDlg(Msg_AniVer,mtInformation,[mbOK],0);
end;

procedure TAnimationEditor.Edit;
begin
  ExecuteVerb(0);
end;


{ ****************************************************************************
  TAVIFileProperty...
  **************************************************************************** }
function TAVIFileProperty.GetAttributes: TPropertyAttributes;
begin
  { Displays a dialog }
  Result := [paDialog];
end;

procedure TAVIFileProperty.Edit;
var OpenDialog: TOpenDialog;
    Ani       : TAnimation;
begin
  { Create open-dialog manually and set all properties }
  Ani        := GetComponent(0) as TAnimation;
  OpenDialog := TOpenDialog.Create(Application);
  try
    OpenDialog.DefaultExt := 'avi';
    OpenDialog.Filter     := 'AVI-Files (*.avi)|*.avi|All files (*.*)|*.*';
    OpenDialog.Options    := [ofPathMustExist,ofFileMustExist];
    OpenDialog.Title      := 'Select AVI file';

    { Show the dialog }
    if OpenDialog.Execute then begin
      Ani.AVIFile := OpenDialog.FileName;
      Designer.Modified;
    end;
  finally
    OpenDialog.Free;
  end;
end;

end.
