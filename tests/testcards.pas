program TestCards;

{$mode objfpc}{$H+}

uses SysUtils, Cards{$IFDEF PAS2JS}, JsCompat{$ENDIF};

var
  D: TDeck;
  C: TCard;
  Seen: array[TSuit, TRank] of Boolean;
  S: TSuit;
  R: TRank;
  I: Integer;
begin
  Randomize;
  D := TDeck.Create;
  try
    if D.Count <> 52 then Halt(1);
    D.Shuffle;
    for S := Low(TSuit) to High(TSuit) do
      for R := Low(TRank) to High(TRank) do Seen[S, R] := False;
    for I := 1 to 52 do
    begin
      C := D.Draw;
      if Seen[C.Suit, C.Rank] then
      begin
        WriteLn('FAIL: duplicate ', CardName(C));
        Halt(1);
      end;
      Seen[C.Suit, C.Rank] := True;
    end;
    for S := Low(TSuit) to High(TSuit) do
      for R := Low(TRank) to High(TRank) do
        if not Seen[S, R] then Halt(1);
    if D.Count <> 0 then Halt(1);
    WriteLn('OK: 52 unique cards drawn, deck empty');
  finally
    D.Free;
  end;
end.
