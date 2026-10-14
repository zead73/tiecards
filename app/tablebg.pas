unit TableBg;

{ The table: a dark felt vignette with a thin gold frame, drawn in code.
  UI code (uses Graphics). The vignette is built once at low resolution and
  stretched, so a smooth gradient costs almost nothing at any window size. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Graphics;

type
  TTableBackground = class
  private
    FBmp: TBitmap;
    procedure Build;
  public
    constructor Create;
    destructor Destroy; override;
    { Paints the whole area R; Scale is the table scale (for frame thickness). }
    procedure Draw(ACanvas: TCanvas; const R: TRect; Scale: Double);
  end;

implementation

const
  BmpW = 320;
  BmpH = 180;
  { felt colours (R, G, B) }
  CenterR = 24; CenterG = 74; CenterB = 48;
  EdgeR = 5;    EdgeG = 16;   EdgeB = 11;

constructor TTableBackground.Create;
begin
  inherited Create;
  FBmp := TBitmap.Create;
  Build;
end;

destructor TTableBackground.Destroy;
begin
  FBmp.Free;
  inherited Destroy;
end;

procedure TTableBackground.Build;
var
  X, Y: Integer;
  DX, DY, D, T: Double;
begin
  FBmp.SetSize(BmpW, BmpH);
  for Y := 0 to BmpH - 1 do
    for X := 0 to BmpW - 1 do
    begin
      DX := (X - (BmpW - 1) / 2) / (BmpW / 2);
      DY := (Y - (BmpH - 1) / 2) / (BmpH / 2);
      D := Sqrt(DX * DX + DY * DY) / Sqrt(2);          { 0 centre .. 1 corner }
      T := Power(Min(1, D * 1.15), 1.7);
      FBmp.Canvas.Pixels[X, Y] := RGBToColor(
        Round(CenterR + (EdgeR - CenterR) * T),
        Round(CenterG + (EdgeG - CenterG) * T),
        Round(CenterB + (EdgeB - CenterB) * T));
    end;
end;

procedure TTableBackground.Draw(ACanvas: TCanvas; const R: TRect; Scale: Double);
var
  M, Th, Dm: Integer;

  procedure Diamond(CX, CY: Integer);
  begin
    ACanvas.Polygon([Point(CX, CY - Dm), Point(CX + Dm, CY),
                     Point(CX, CY + Dm), Point(CX - Dm, CY)]);
  end;

begin
  ACanvas.StretchDraw(R, FBmp);

  M := Round(10 * Scale) + 6;                 { frame inset }
  Th := Round(Scale * 1.5);
  if Th < 1 then Th := 1;
  Dm := Round(5 * Scale) + 2;
  with ACanvas do
  begin
    Brush.Style := bsClear;
    Pen.Style := psSolid;
    Pen.Color := RGBToColor(110, 90, 46);     { dim gold }
    Pen.Width := Th;
    Rectangle(R.Left + M, R.Top + M, R.Right - M, R.Bottom - M);
    Pen.Color := RGBToColor(58, 48, 26);
    Pen.Width := 1;
    Rectangle(R.Left + M + 4 * Th + 2, R.Top + M + 4 * Th + 2,
      R.Right - M - 4 * Th - 2, R.Bottom - M - 4 * Th - 2);
    { corner diamonds }
    Brush.Style := bsSolid;
    Brush.Color := RGBToColor(110, 90, 46);
    Pen.Color := RGBToColor(110, 90, 46);
    Diamond(R.Left + M, R.Top + M);
    Diamond(R.Right - M, R.Top + M);
    Diamond(R.Left + M, R.Bottom - M);
    Diamond(R.Right - M, R.Bottom - M);
  end;
end;

end.
