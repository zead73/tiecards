unit HandFile;

{ Saving a hand to disk and reading it back. No window code.

  The file is plain text, one "key=value" per line. Reading is defensive: any
  missing, malformed or out-of-range entry means "no usable hand" (False), never
  a crash. Whether the cards add up to a believable hand is then checked by the
  game itself when the hand is loaded (see TTriPeaksGame.SetState).

  Writing is done by Storage, which on the desktop goes to a temporary file
  first and swaps it in afterwards, so a crash part-way through a save cannot
  destroy the previous save. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Storage, Cards, TriPeaks, Session, Settings;

const
  SlotCount = 3;                  { manual save slots (Free Play) }

type
  TSlotInfo = record
    Exists: Boolean;
    CardsLeft: Integer;
    Stamp: string;                { when it was saved }
  end;

{ The text of a saved hand (exposed so it can be tested without files). }
function HandToText(const H: TSavedHand; const Stamp: string): string;
function TextToHand(const Text: string; out H: TSavedHand; out Stamp: string): Boolean;

function WriteHandFile(const FileName: string; const H: TSavedHand): Boolean;
function ReadHandFile(const FileName: string; out H: TSavedHand): Boolean;
{ A quick look at a save (for the slot menu) without loading it. }
function PeekHandFile(const FileName: string): TSlotInfo;
procedure DeleteHandFile(const FileName: string);
{ Deletes the game's own saved hands in Dir: the two autosaves and the manual
  slots (Free Play's and the campaign's) (and any leftover temporary files). Only those exact names: never
  anything else that happens to be in the folder. }
procedure DeleteAllSavedHands(const Dir: string);
{ Only the duel's autosave. }
procedure DeleteCampaignHand(const Dir: string);

{ Where hands live (per-user config folder). }
function AutoSaveFile(AMode: TGameMode): string;
function SlotFile(N: Integer): string;      { N = 1..SlotCount }

implementation

const
  Magic = 'tiecards-hand 1';

function CardToStr(const C: TCard): string;
begin
  Result := IntToStr(Ord(C.Suit)) + '-' + IntToStr(C.Rank);
end;

function StrToCard(const S: string; out C: TCard): Boolean;
var
  P, Su, Ra: Integer;
begin
  Result := False;
  P := Pos('-', S);
  if P < 2 then Exit;
  if not TryStrToInt(Copy(S, 1, P - 1), Su) then Exit;
  if not TryStrToInt(Copy(S, P + 1, MaxInt), Ra) then Exit;
  if (Su < 0) or (Su > Ord(High(TSuit))) then Exit;
  if (Ra < Low(TRank)) or (Ra > High(TRank)) then Exit;
  C.Suit := TSuit(Su);
  C.Rank := Ra;
  C.FaceUp := False;
  Result := True;
end;

function CardsToStr(const A: TCardArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + CardToStr(A[I]);
  end;
end;

function StrToCards(const S: string; out A: TCardArray): Boolean;
var
  P, Start: Integer;
  Part: string;
  C: TCard;
begin
  Result := False;
  A := nil;
  Start := 1;
  for P := 1 to Length(S) + 1 do
    if (P > Length(S)) or (S[P] = ' ') then
    begin
      Part := Copy(S, Start, P - Start);
      Start := P + 1;
      if Part = '' then Continue;
      if not StrToCard(Part, C) then Exit;
      SetLength(A, Length(A) + 1);
      A[High(A)] := C;
      if Length(A) > 52 then Exit;
    end;
  Result := True;
end;

function BitsToStr(const B: array of Boolean): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    if B[I] then Result := Result + '1' else Result := Result + '0';
end;

function StrToBits(const S: string; out B: array of Boolean): Boolean;
var
  I: Integer;
begin
  Result := Length(S) = Length(B);
  if not Result then Exit;
  for I := 0 to High(B) do
  begin
    if not (S[I + 1] in ['0', '1']) then Exit(False);
    B[I] := S[I + 1] = '1';
  end;
end;

{ The moves undo can take back, oldest first, one word each: "P<tableau
  index>", "D" for a draw or "M" for a draw that missed a play, then the card
  that was on the waste and the streak before it: "P12:2-5:3". }
function MovesToStr(const A: TUndoArray): string;
var
  I: Integer;
  T: string;
begin
  Result := '';
  for I := 0 to High(A) do
  begin
    if A[I].Draw then
    begin
      if A[I].Ate then
      begin
        if A[I].Missed then T := 'X' else T := 'F';        { ... and he ate a stock card after it }
      end
      else if A[I].Missed then T := 'M'
      else T := 'D';
    end
    else if A[I].Bitten then
      T := 'B' + IntToStr(A[I].Index)                      { a bitten card }
    else
      T := 'P' + IntToStr(A[I].Index);
    if Result <> '' then Result := Result + ' ';
    Result := Result + T + ':' + CardToStr(A[I].PrevWasteTop) + ':' + IntToStr(A[I].PrevStreak);
  end;
end;

function StrToMoves(const S: string; out A: TUndoArray): Boolean;
var
  P, Start, C1, C2: Integer;
  Part, Kind: string;
  M: TUndoMove;
begin
  Result := False;
  A := nil;
  Start := 1;
  for P := 1 to Length(S) + 1 do
    if (P > Length(S)) or (S[P] = ' ') then
    begin
      Part := Copy(S, Start, P - Start);
      Start := P + 1;
      if Part = '' then Continue;
      C1 := Pos(':', Part);
      if C1 < 2 then Exit;
      C2 := C1 + Pos(':', Copy(Part, C1 + 1, MaxInt));
      if C2 = C1 then Exit;
      Kind := Copy(Part, 1, C1 - 1);
      M.Draw := (Kind = 'D') or (Kind = 'M') or (Kind = 'F') or (Kind = 'X');
      M.Missed := (Kind = 'M') or (Kind = 'X');
      M.Ate := (Kind = 'F') or (Kind = 'X');
      M.Bitten := False;
      M.Index := 0;
      if not M.Draw then
      begin
        if (Kind[1] <> 'P') and (Kind[1] <> 'B') then Exit;
        M.Bitten := Kind[1] = 'B';
        if not TryStrToInt(Copy(Kind, 2, MaxInt), M.Index) then Exit;
      end;
      if not StrToCard(Copy(Part, C1 + 1, C2 - C1 - 1), M.PrevWasteTop) then Exit;
      if not TryStrToInt(Copy(Part, C2 + 1, MaxInt), M.PrevStreak) then Exit;
      SetLength(A, Length(A) + 1);
      A[High(A)] := M;
      if Length(A) > 80 then Exit;
    end;
  Result := True;
end;

function MarksToStr(const M: TMarkArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to TableauSize - 1 do Result := Result + IntToStr(M[I]);
end;

function StrToMarks(const S: string; out M: TMarkArray): Boolean;
var
  I: Integer;
begin
  Result := Length(S) = TableauSize;
  if not Result then Exit;
  for I := 0 to TableauSize - 1 do
  begin
    if not (S[I + 1] in ['0', '1', '2', '3']) then Exit(False);
    M[I] := Ord(S[I + 1]) - Ord('0');
  end;
end;

function HandToText(const H: TSavedHand; const Stamp: string): string;
var
  L: TStringList;
  I, Left: Integer;
  Tab: TCardArray;
begin
  L := TStringList.Create;
  try
    Left := 0;
    SetLength(Tab, TableauSize);
    for I := 0 to TableauSize - 1 do
    begin
      Tab[I] := H.Game.Tableau[I];
      if not H.Game.Removed[I] then Inc(Left);
    end;
    L.Add(Magic);
    L.Add('saved=' + Stamp);
    L.Add('left=' + IntToStr(Left));
    L.Add('id=' + IntToStr(H.Game.HandId));
    L.Add('stocksize=' + IntToStr(H.Game.StockSize));
    if H.Game.Wrap then L.Add('wrap=1') else L.Add('wrap=0');
    L.Add('spare=' + CardsToStr(H.Game.Spare));
    if H.Game.Revealed then L.Add('revealed=1') else L.Add('revealed=0');
    L.Add('stakes=' + IntToStr(H.Game.Stakes));
    L.Add('tableau=' + CardsToStr(Tab));
    L.Add('removed=' + BitsToStr(H.Game.Removed));
    L.Add('stock=' + CardsToStr(H.Game.Stock));
    L.Add('waste=' + CardToStr(H.Game.WasteTop));
    L.Add(Format('counts=%d %d %d %d', [H.Game.WasteCount, H.Game.Streak,
      H.Game.BestStreak, H.Game.Plays]));
    L.Add('misses=' + IntToStr(H.Misses));
    L.Add('bites=' + IntToStr(H.Bites));
    L.Add('hazard=' + IntToStr(H.Game.Hazard));
    L.Add('marks=' + MarksToStr(H.Game.Marks));
    L.Add('undo=' + MovesToStr(H.Game.History));
    Result := L.Text;
  finally
    L.Free;
  end;
end;

{ "a b c d" -> the integers, True only if there are exactly N valid ones. }
function ParseInts(const S: string; N: Integer; out V: array of Integer): Boolean;
var
  P, Start, K: Integer;
  Part: string;
begin
  Result := False;
  K := 0;
  Start := 1;
  for P := 1 to Length(S) + 1 do
    if (P > Length(S)) or (S[P] = ' ') then
    begin
      Part := Copy(S, Start, P - Start);
      Start := P + 1;
      if Part = '' then Continue;
      if K >= N then Exit;
      if not TryStrToInt(Part, V[K]) then Exit;
      Inc(K);
    end;
  Result := K = N;
end;

function TextToHand(const Text: string; out H: TSavedHand; out Stamp: string): Boolean;
var
  L: TStringList;
  Tab: TCardArray;
  Nums: array[0..3] of Integer;
  I, Id: Integer;
  S: string;
begin
  Result := False;
  Stamp := '';
  H := Default(TSavedHand);
  H.Game.Stock := nil;
  H.Game.History := nil;
  L := TStringList.Create;
  try
    L.Text := Text;
    if (L.Count = 0) or (Trim(L[0]) <> Magic) then Exit;
    Stamp := L.Values['saved'];
    if not TryStrToInt(L.Values['id'], Id) then Exit;
    if Id <= 0 then Exit;
    H.Game.HandId := Id;
    { the hand's rules; a save from before difficulty levels has neither line
      and used the ordinary rules }
    H.Game.StockSize := FullStock;
    H.Game.Wrap := True;
    H.Game.Spare := nil;
    H.Game.Revealed := False;
    H.Game.Stakes := 0;
    if L.IndexOfName('stocksize') >= 0 then
    begin
      if not TryStrToInt(L.Values['stocksize'], H.Game.StockSize) then Exit;
      if (H.Game.StockSize < 0) or (H.Game.StockSize > FullStock) then Exit;
    end;
    if L.IndexOfName('wrap') >= 0 then
    begin
      S := L.Values['wrap'];
      if (S <> '0') and (S <> '1') then Exit;
      H.Game.Wrap := S = '1';
    end;
    { special cards: a save from before them has none of these lines }
    if L.IndexOfName('spare') >= 0 then
      if not StrToCards(L.Values['spare'], H.Game.Spare) then Exit;
    if L.IndexOfName('revealed') >= 0 then
    begin
      S := L.Values['revealed'];
      if (S <> '0') and (S <> '1') then Exit;
      H.Game.Revealed := S = '1';
    end;
    if L.IndexOfName('stakes') >= 0 then
    begin
      if not TryStrToInt(L.Values['stakes'], H.Game.Stakes) then Exit;
      if H.Game.Stakes < 0 then Exit;
    end;
    if not StrToCards(L.Values['tableau'], Tab) then Exit;
    if Length(Tab) <> TableauSize then Exit;
    for I := 0 to TableauSize - 1 do H.Game.Tableau[I] := Tab[I];
    if not StrToBits(L.Values['removed'], H.Game.Removed) then Exit;
    if L.IndexOfName('stock') < 0 then Exit;         { an empty stock is legal; a missing line is not }
    if not StrToCards(L.Values['stock'], H.Game.Stock) then Exit;
    if Length(H.Game.Stock) > H.Game.StockSize then Exit;
    if not StrToCard(L.Values['waste'], H.Game.WasteTop) then Exit;
    if not ParseInts(L.Values['counts'], 4, Nums) then Exit;
    H.Game.WasteCount := Nums[0];
    H.Game.Streak := Nums[1];
    H.Game.BestStreak := Nums[2];
    H.Game.Plays := Nums[3];
    if not TryStrToInt(L.Values['misses'], H.Misses) then Exit;
    if H.Misses < 0 then Exit;
    { a save from before the vampires' tricks has none of these lines }
    H.Bites := 0;
    H.Game.Hazard := 0;
    for I := 0 to TableauSize - 1 do H.Game.Marks[I] := 0;
    if L.IndexOfName('bites') >= 0 then
      if not TryStrToInt(L.Values['bites'], H.Bites) or (H.Bites < 0) then Exit;
    if L.IndexOfName('hazard') >= 0 then
      if not TryStrToInt(L.Values['hazard'], H.Game.Hazard) then Exit;
    if L.IndexOfName('marks') >= 0 then
      if not StrToMarks(L.Values['marks'], H.Game.Marks) then Exit;
    { the moves undo can take back. A save from the one-move days says just
      "undo=0" or "undo=1" (and the old snapshot lines): it loads with nothing
      to undo. }
    H.Game.History := nil;
    S := L.Values['undo'];
    if (S <> '0') and (S <> '1') then
      if not StrToMoves(S, H.Game.History) then Exit;
    Result := True;
  finally
    L.Free;
  end;
end;

function WriteHandFile(const FileName: string; const H: TSavedHand): Boolean;
begin
  Result := StoreWrite(FileName, HandToText(H, FormatDateTime('yyyy-mm-dd hh:nn', Now)));
end;

function ReadHandFile(const FileName: string; out H: TSavedHand): Boolean;
var
  Text, Stamp: string;
begin
  Result := False;
  H := Default(TSavedHand);
  if not StoreRead(FileName, Text) then Exit;
  Result := TextToHand(Text, H, Stamp);
end;

function PeekHandFile(const FileName: string): TSlotInfo;
var
  H: TSavedHand;
  L: TStringList;
  Text, Stamp: string;
begin
  Result.Exists := False;
  Result.CardsLeft := 0;
  Result.Stamp := '';
  if not StoreRead(FileName, Text) then Exit;
  L := TStringList.Create;
  try
    L.Text := Text;
    if TextToHand(Text, H, Stamp) then      { only a readable file counts as a save }
    begin
      Result.Exists := True;
      Result.Stamp := Stamp;
      Result.CardsLeft := StrToIntDef(L.Values['left'], 0);
    end;
  finally
    L.Free;
  end;
end;

procedure DeleteHandFile(const FileName: string);
begin
  StoreDelete(FileName);
end;

procedure DeleteInDir(const Dir, Name: string);
begin
  StoreDelete(IncludeTrailingPathDelimiter(Dir) + Name);      { and its temporary copy }
end;

procedure DeleteAllSavedHands(const Dir: string);
var
  N: Integer;
begin
  DeleteInDir(Dir, ExtractFileName(AutoSaveFile(gmFreePlay)));
  DeleteInDir(Dir, ExtractFileName(AutoSaveFile(gmCampaign)));
  for N := 1 to SlotCount do
  begin
    DeleteInDir(Dir, ExtractFileName(SlotFile(N)));
    DeleteInDir(Dir, Format('campaignslot%d.save', [N]));     { the campaign's slots (see CampaignSlots) }
  end;
end;

procedure DeleteCampaignHand(const Dir: string);
begin
  DeleteInDir(Dir, ExtractFileName(AutoSaveFile(gmCampaign)));
end;

function AutoSaveFile(AMode: TGameMode): string;
begin
  if AMode = gmCampaign then
    Result := StoreName('campaign.hand')
  else
    Result := StoreName('freeplay.hand');
end;

function SlotFile(N: Integer): string;
begin
  Result := StoreName(Format('slot%d.hand', [N]));
end;

end.
