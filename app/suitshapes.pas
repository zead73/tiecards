unit SuitShapes;

{ Draws card suits as shapes, so they look the same on every platform and do
  not depend on any font having the suit glyphs. UI code (uses Graphics). }

{$mode objfpc}{$H+}

interface

uses
  Types, Graphics, Cards;

{ Draws a suit centred on (Cx, Cy), about S pixels tall, in the current
  Canvas colours replaced by AColor. }
procedure DrawSuit(ACanvas: TCanvas; ASuit: TSuit; Cx, Cy, S: Integer;
  AColor: TColor);

implementation

procedure Disc(C: TCanvas; X, Y, R: Integer);
begin
  C.Ellipse(X - R, Y - R, X + R + 1, Y + R + 1);
end;

function Pt(X, Y: Double): TPoint;
begin
  Result := Point(Round(X), Round(Y));
end;

procedure Stem(C: TCanvas; Cx, Cy, S: Integer; TopY: Double);
begin
  C.Polygon([Pt(Cx - 0.05 * S, TopY), Pt(Cx + 0.05 * S, TopY),
             Pt(Cx + 0.17 * S, Cy + 0.5 * S), Pt(Cx - 0.17 * S, Cy + 0.5 * S)]);
end;

procedure DrawSuit(ACanvas: TCanvas; ASuit: TSuit; Cx, Cy, S: Integer;
  AColor: TColor);
var
  R: Integer;
begin
  with ACanvas do
  begin
    Pen.Style := psSolid;
    Pen.Width := 1;
    Pen.Color := AColor;
    Brush.Style := bsSolid;
    Brush.Color := AColor;
    case ASuit of
      suDiamonds:
        Polygon([Pt(Cx, Cy - 0.5 * S), Pt(Cx + 0.36 * S, Cy),
                 Pt(Cx, Cy + 0.5 * S), Pt(Cx - 0.36 * S, Cy)]);
      suHearts:
      begin
        R := Round(0.26 * S);
        Disc(ACanvas, Round(Cx - 0.24 * S), Round(Cy - 0.2 * S), R);
        Disc(ACanvas, Round(Cx + 0.24 * S), Round(Cy - 0.2 * S), R);
        Polygon([Pt(Cx - 0.49 * S, Cy - 0.12 * S), Pt(Cx + 0.49 * S, Cy - 0.12 * S),
                 Pt(Cx, Cy + 0.5 * S)]);
      end;
      suSpades:
      begin
        R := Round(0.26 * S);
        Disc(ACanvas, Round(Cx - 0.24 * S), Round(Cy + 0.08 * S), R);
        Disc(ACanvas, Round(Cx + 0.24 * S), Round(Cy + 0.08 * S), R);
        Polygon([Pt(Cx, Cy - 0.5 * S), Pt(Cx - 0.49 * S, Cy + 0.0 * S),
                 Pt(Cx + 0.49 * S, Cy + 0.0 * S)]);
        Stem(ACanvas, Cx, Cy, S, Cy + 0.2 * S);
      end;
      suClubs:
      begin
        R := Round(0.21 * S);
        Disc(ACanvas, Cx, Round(Cy - 0.27 * S), R);
        Disc(ACanvas, Round(Cx - 0.25 * S), Round(Cy + 0.08 * S), R);
        Disc(ACanvas, Round(Cx + 0.25 * S), Round(Cy + 0.08 * S), R);
        Polygon([Pt(Cx, Cy - 0.15 * S), Pt(Cx - 0.2 * S, Cy + 0.1 * S),
                 Pt(Cx + 0.2 * S, Cy + 0.1 * S)]);
        Stem(ACanvas, Cx, Cy, S, Cy + 0.1 * S);
      end;
    end;
  end;
end;

end.
