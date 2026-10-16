{ Measures how winnable the campaign's hands are with a vampire's trick, by solving random deals with full information (perfect play) and with a plain player ('play the card that uncovers most'). A stand-alone program (it does not use the game's units, so it repeats the layout): it is what the numbers in src/vampires.pas came from. Build and run:   fpc -O2 -Mobjfpc tools/trick-solver.pas && ./tools/trick-solver   (about a minute). Edit the Run(...) lines at the bottom to try other rules: wrap, stock size, number of chained cards, how often he feeds. }
program trick_solver;
{$mode objfpc}{$H+}
uses SysUtils, Generics.Collections;

var
  Cover: array[0..27, 0..1] of Integer;
  Rank: array[0..27] of Integer;
  RowOf, XOf: array[0..27] of Integer;
  Chained: array[0..27] of Boolean;
  Stock: array[0..22] of Integer;      { Stock[0] is drawn first; the LAST is the bottom }
  StockN: Integer;
  Wrap: Boolean;
  FeedEvery: Integer;                  { 0 = no hunger }
  FeedCap: Integer;                    { 0 = no cap; else he feeds at most this many times in a hand }
  SkipFeed: Integer;                   { Iron Spoon: how many of his first feedings are skipped (the relic skips 1) }
  BreakOn: Boolean;                    { Locksmith's Pick: one chained card per hand may be played anyway }
  Seen: specialize TDictionary<QWord, Boolean>;
  Nodes, NodeCap: Int64;
  Capped: Boolean;
  Nb: array[0..27, 0..1] of Integer;   { row neighbours (-1 none) }

procedure Layout;
var P, J, K: Integer;
begin
  for K := 0 to 27 do begin Cover[K,0] := -1; Cover[K,1] := -1; end;
  for P := 0 to 2 do
  begin
    RowOf[P] := 0;
    Cover[P,0] := 3 + 2*P; Cover[P,1] := 3 + 2*P + 1;
    for J := 0 to 1 do begin K := 3 + 2*P + J; RowOf[K] := 1; Cover[K,0] := 9 + 3*P + J; Cover[K,1] := 9 + 3*P + J + 1; end;
    for J := 0 to 2 do begin K := 9 + 3*P + J; RowOf[K] := 2; Cover[K,0] := 18 + 3*P + J; Cover[K,1] := 18 + 3*P + J + 1; end;
  end;
  for K := 18 to 27 do begin RowOf[K] := 3; XOf[K] := 2*(K-18); end;
  for K := 17 downto 0 do XOf[K] := (XOf[Cover[K,0]] + XOf[Cover[K,1]]) div 2;
  for K := 0 to 27 do begin Nb[K,0] := -1; Nb[K,1] := -1; end;
  for K := 0 to 27 do
    for J := 0 to 27 do
      if (J <> K) and (RowOf[J] = RowOf[K]) and (Abs(XOf[J] - XOf[K]) = 2) then
        if XOf[J] < XOf[K] then Nb[K,0] := J else Nb[K,1] := J;
end;

function Adj(A, B: Integer): Boolean;
begin
  Result := (Abs(A - B) = 1) or (Wrap and (Abs(A - B) = 12));
end;

function Free(Mask: LongWord; I: Integer): Boolean;
begin
  Result := ((Mask shr I) and 1 = 0)
    and ((Cover[I,0] < 0) or ((Mask shr Cover[I,0]) and 1 = 1))
    and ((Cover[I,1] < 0) or ((Mask shr Cover[I,1]) and 1 = 1));
end;

{ Locked as the chain rule says (a neighbour in its row is still on the table). }
function Locked(Mask: LongWord; I: Integer): Boolean;
var Q: Integer;
begin
  Result := False;
  if Chained[I] then
    for Q := 0 to 1 do
      if (Nb[I,Q] >= 0) and ((Mask shr Nb[I,Q]) and 1 = 0) then Result := True;
end;

{ BreakLeft = 1 while the Pick's one break is still unused. }
function Playable(Mask: LongWord; I, BreakLeft: Integer): Boolean;
begin
  Result := Free(Mask, I) and (not Locked(Mask, I) or (BreakLeft > 0));
end;

function Avail(Drawn: Integer): Integer;       { stock cards left before draw number Drawn+1 }
var Fed: Integer;
begin
  if FeedEvery > 0 then
  begin
    Fed := Drawn div FeedEvery;
    if (FeedCap > 0) and (Fed > FeedCap) then Fed := FeedCap;
    Result := StockN - Drawn - Fed;
    if SkipFeed > 0 then
    begin
      Fed := Drawn div FeedEvery;                               { feedings that would have happened }
      if Fed > SkipFeed then Fed := SkipFeed;
      Inc(Result, Fed);                                         { the first ones never happened }
    end;
  end
  else Result := StockN - Drawn;
end;

function Solve(Mask: LongWord; Drawn, WasteRank, BreakLeft: Integer): Boolean;
var
  I: Integer;
  Key: QWord;
begin
  Result := False;
  if Mask = $0FFFFFFF then Exit(True);
  Inc(Nodes);
  if Nodes > NodeCap then begin Capped := True; Exit; end;
  Key := (QWord(Mask) shl 13) or (QWord(BreakLeft) shl 12) or (QWord(Drawn) shl 5) or QWord(WasteRank);
  if Seen.ContainsKey(Key) then Exit;
  for I := 27 downto 0 do
    if Playable(Mask, I, BreakLeft) and Adj(Rank[I], WasteRank) then
    begin
      if Locked(Mask, I) then
      begin
        if Solve(Mask or (LongWord(1) shl I), Drawn, Rank[I], 0) then Exit(True);   { the break is used }
      end
      else if Solve(Mask or (LongWord(1) shl I), Drawn, Rank[I], BreakLeft) then Exit(True);
      if Capped then Exit;
    end;
  if Avail(Drawn) > 0 then
    if Solve(Mask, Drawn + 1, Stock[Drawn], BreakLeft) then Exit(True);
  if not Capped then Seen.Add(Key, True);
end;

{ the plain player: play the card that uncovers most, draw when nothing plays }
function Greedy(Waste: Integer): Boolean;
var
  Mask: LongWord;
  Drawn, I, Best, BestS, S, J, Q, O, BreakLeft: Integer;
begin
  Mask := 0; Drawn := 0; BreakLeft := 0;
  if BreakOn then BreakLeft := 1;
  while Mask <> $0FFFFFFF do
  begin
    Best := -1; BestS := -1;
    for I := 27 downto 0 do
      if Playable(Mask, I, 0) and Adj(Rank[I], Waste) then
      begin
        S := 0;
        for J := 0 to 27 do
          if ((Mask shr J) and 1 = 0) and (J <> I) then
            for Q := 0 to 1 do
              if Cover[J,Q] = I then
              begin
                O := Cover[J, 1 - Q];
                if (O < 0) or ((Mask shr O) and 1 = 1) then Inc(S);
              end;
        if S > BestS then begin BestS := S; Best := I; end;
      end;
    if Best >= 0 then begin Mask := Mask or (LongWord(1) shl Best); Waste := Rank[Best]; end
    else if BreakLeft > 0 then
    begin                                   { nothing plays: use the Pick on a chained card that does }
      for I := 27 downto 0 do
        if (Best < 0) and Playable(Mask, I, 1) and Adj(Rank[I], Waste) then Best := I;
      if Best >= 0 then begin Mask := Mask or (LongWord(1) shl Best); Waste := Rank[Best]; BreakLeft := 0; end
      else if Avail(Drawn) > 0 then begin Waste := Stock[Drawn]; Inc(Drawn); end
      else Exit(False);
    end
    else if Avail(Drawn) > 0 then begin Waste := Stock[Drawn]; Inc(Drawn); end
    else Exit(False);
  end;
  Result := True;
end;

procedure RandomDeal(var Waste: Integer);
var D: array[0..51] of Integer; I, J, T: Integer;
begin
  for I := 0 to 51 do D[I] := (I mod 13) + 1;
  for I := 51 downto 1 do begin J := Random(I + 1); T := D[I]; D[I] := D[J]; D[J] := T; end;
  for I := 0 to 27 do Rank[I] := D[I];
  for I := 0 to 22 do Stock[I] := D[28 + I];
  Waste := D[51];
end;

procedure PickChains(Count: Integer);
var N, K, Q, Tries: Integer; Ok: Boolean;
begin
  for K := 0 to 27 do Chained[K] := False;
  N := 0; Tries := 0;
  while (N < Count) and (Tries < 1000) do
  begin
    Inc(Tries);
    K := 3 + Random(25);              { rows 1..3 }
    if Chained[K] then Continue;
    Ok := True;
    for Q := 0 to 1 do if (Nb[K,Q] >= 0) and Chained[Nb[K,Q]] then Ok := False;
    if Ok then begin Chained[K] := True; Inc(N); end;
  end;
end;

procedure Run(const Name: string; AWrap: Boolean; AStock, Chains, Feed, N: Integer; ASkip: Integer = 0; APick: Boolean = False; ACap: Integer = 0);
var K, WinP, WinG, Waste, Unknown: Integer;
begin
  Wrap := AWrap; StockN := AStock; FeedEvery := Feed; SkipFeed := ASkip; BreakOn := APick; FeedCap := ACap;
  WinP := 0; WinG := 0; Unknown := 0;
  RandSeed := 4242;
  for K := 1 to N do
  begin
    RandomDeal(Waste);
    PickChains(Chains);
    Nodes := 0; Capped := False; Seen.Clear;
    if Solve(0, 0, Waste, Ord(BreakOn)) then Inc(WinP) else if Capped then Inc(Unknown);
    if Greedy(Waste) then Inc(WinG);
  end;
  WriteLn(Format('%-34s perfect %5.1f%%  plain %5.1f%%  (capped %d)', [Name, 100*WinP/N, 100*WinG/N, Unknown]));
end;

begin
  Layout;
  Seen := specialize TDictionary<QWord, Boolean>.Create;
  NodeCap := 3000000;
  Run('Alaric: no wrap, 23 stock, feeds every 4', False, 23, 0, 4, 500);
  Run('A: he feeds at most once a hand', False, 23, 0, 4, 500, 0, False, 1);
  Run('B: he feeds at most twice a hand', False, 23, 0, 4, 500, 0, False, 2);
  Run('C: he feeds every 8th draw', False, 23, 0, 8, 500);
  Run('D: King and Ace wrap in his hands', True, 23, 0, 4, 500);
  Run('E: wrap, and he skips the first feeding', True, 23, 0, 4, 500, 1);
  Run('F: no hunger at all (the ceiling)', False, 23, 0, 0, 500);
  Run('Lucien: the ordinary rules', True, 23, 0, 0, 500);
  Run('Carmilla: wrap, 20 stock, 3 chains', True, 20, 3, 0, 500);
  Run('Alaric: no wrap, 23 stock, feeds every 4', False, 23, 0, 4, 500);
  Run('Carmilla with the Locksmith''s Pick', True, 20, 3, 0, 500, 0, True);
  Run('Alaric with the Iron Spoon (skips 1 feeding)', False, 23, 0, 4, 500, 1, False);
  Run('  ... if it skipped the first 2', False, 23, 0, 4, 500, 2, False);
  Run('  ... if he fed every 6th draw instead', False, 23, 0, 6, 500, 0, False);
end.
