unit Settings;

{ Small preferences that should be remembered between runs. No window code.
  Stored in the per-user config folder next to the inventory and campaign. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, TextIni, Storage, Campaign;

type
  TGameMode = (gmFreePlay, gmCampaign);

  TSettings = class
  private
    FFile: string;
    FMode: TGameMode;
    FFenwickMet: Boolean;
    FWrapUnlocked: Boolean;
    FStockUnlocked: Boolean;
  public
    { AFileName = '' means never load or save (used by tests). A missing or
      unreadable file gives the defaults. }
    constructor Create(const AFileName: string);
    procedure Save;
    property Mode: TGameMode read FMode write FMode;    { the mode you were last in }
    { The player has had Fenwick's introduction in the Store (shown once). }
    property FenwickMet: Boolean read FFenwickMet write FFenwickMet;
    { The Store stocks the Open wrap card from the time the player first reaches
      a vampire with no wrap (and keeps it, even if the campaign is restarted). }
    property WrapUnlocked: Boolean read FWrapUnlocked write FWrapUnlocked;
    { Likewise the Full deck card, from the first vampire with a smaller stock. }
    property StockUnlocked: Boolean read FStockUnlocked write FStockUnlocked;
  end;

{ Per-user save location (works on Linux and Windows). }
function DefaultSettingsFile: string;

{ Should the game open straight into the campaign? Only if you were in it last
  time and it is not already finished (a finished campaign is never restarted
  for you: that is your choice, with the Campaign button). }
function ShouldResumeCampaign(ASettings: TSettings; ACampaign: TCampaign): Boolean;

implementation

constructor TSettings.Create(const AFileName: string);
var
  Ini: TTextIni;
  Text: string;
begin
  inherited Create;
  FFile := AFileName;
  FMode := gmFreePlay;
  if (FFile <> '') and StoreRead(FFile, Text) then
  begin
    Ini := TTextIni.Create;
    try
      Ini.LoadFromText(Text);
      if SameText(Ini.ReadString('Settings', 'Mode', 'FreePlay'), 'Campaign') then
        FMode := gmCampaign;                { anything else = Free Play }
      FFenwickMet := Ini.ReadBool('Settings', 'FenwickMet', False);
      FWrapUnlocked := Ini.ReadBool('Settings', 'WrapUnlocked', False);
      FStockUnlocked := Ini.ReadBool('Settings', 'StockUnlocked', False);
    finally
      Ini.Free;
    end;
  end;
end;

procedure TSettings.Save;
var
  Ini: TTextIni;
  Text: string;
begin
  if FFile = '' then Exit;
  Ini := TTextIni.Create;
  try
    if StoreRead(FFile, Text) then Ini.LoadFromText(Text);
    if FMode = gmCampaign then
      Ini.WriteString('Settings', 'Mode', 'Campaign')
    else
      Ini.WriteString('Settings', 'Mode', 'FreePlay');
    Ini.WriteBool('Settings', 'FenwickMet', FFenwickMet);
    Ini.WriteBool('Settings', 'WrapUnlocked', FWrapUnlocked);
    Ini.WriteBool('Settings', 'StockUnlocked', FStockUnlocked);
    StoreWrite(FFile, Ini.ToText);
  finally
    Ini.Free;
  end;
end;

function DefaultSettingsFile: string;
begin
  Result := StoreName('settings.ini');
end;

function ShouldResumeCampaign(ASettings: TSettings; ACampaign: TCampaign): Boolean;
begin
  Result := (ASettings.Mode = gmCampaign) and not ACampaign.IsComplete;
end;

end.
