unit TriPeaks;

{ Tri Peaks solitaire rules. No UI code in here.

  Tableau layout: 28 cards in three peaks, indexed 0..27.
    row 0:  0..2    (peak tops)
    row 1:  3..8
    row 2:  9..17
    row 3: 18..27   (bottom row, 10 cards, starts face up)
  Every card in rows 0..2 is covered by two cards in the row below it. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Cards;

const
  TableauSize = 28;
  FullStock = 52 - TableauSize - 1;     { stock cards in an ordinary deal: 23 }

  { What a vampire does to a hand (the campaign only; Free Play has none):
      bitten   a few cards are marked; playing one costs coins and ends your streak
      chained  a few cards are chained; one cannot be played while a card beside
               it in its row is still on the table
      hunger   after every FeedEvery-th draw the bottom card of the stock is eaten
               (it goes to the unused cards, so a Full deck brings it back) }
  BittenCount = 3;
  ChainedCount = 3;
  FeedEvery = 4;
  MarkNone = 0;
  MarkBitten = 1;
  MarkChained = 2;
  MarkCross = 3;          { the silver cross (see Campaign): only a Wild card can claim it; on any tableau card }

type
  THazard = (hzNone, hzBitten, hzChained, hzHunger);

  TRemovedArray = array[0..TableauSize - 1] of Boolean;   { a named type, so copies compile everywhere }
  TMarkArray = array[0..TableauSize - 1] of Integer;       { MarkNone / MarkBitten / MarkChained / MarkCross per card }

  { One move that undo can take back: a play from the tableau, or a draw from
    the stock, with what the table looked like just before it. }
  TUndoMove = record
    Draw: Boolean;                      { a draw (else a play) }
    Index: Integer;                     { the tableau card played (plays only) }
    Missed: Boolean;                    { a draw made while a card could have been played }
    Bitten: Boolean;                    { a play of a bitten card }
    Ate: Boolean;                       { a draw after which the vampire ate a stock card }
    Broke: Boolean;                     { a play of a chained card that the Locksmith's Pick let through }
    PrevWasteTop: TCard;
    PrevStreak: Integer;
  end;
  TUndoArray = array of TUndoMove;      { oldest first }

  { Everything needed to put a hand back exactly as it was, including the moves
    undo can still take back. See GetState / SetState. }
  THandData = record
    HandId: Integer;                    { names this deal (see Session rewards) }
    StockSize: Integer;                 { stock cards the hand started with }
    Wrap: Boolean;                      { do King and Ace count as neighbours? }
    Spare: TCardArray;                  { the deal's unused cards (a Full deck puts them in the stock) }
    Revealed: Boolean;                  { Seer's eye: face-down cards are shown }
    Stakes: Integer;                    { free cards destroyed with a Wood Stake }
    Tableau: array[0..TableauSize - 1] of TCard;
    Removed: TRemovedArray;
    Stock: TCardArray;                  { the top of the stock is the last card }
    WasteTop: TCard;
    WasteCount, Streak, BestStreak, Plays: Integer;
    History: TUndoArray;                { the moves since the deal or the last special card }
    Hazard: Integer;                    { Ord(THazard) }
    Marks: TMarkArray;
    FeedOnce: Boolean;                  { the Iron Spoon: he feeds at most once in the hand }
    BreakStart, BreakLeft: Integer;     { the Locksmith's Pick: breaks the hand began with (0 or 1), and still unused }
  end;

  TTriPeaksGame = class
  private
    FTableau: array[0..TableauSize - 1] of TCard;
    FRemoved: TRemovedArray;
    FCover: array[0..TableauSize - 1, 0..1] of Integer;  { -1 = bottom row }
    FRow: array[0..TableauSize - 1] of Integer;
    FX: array[0..TableauSize - 1] of Integer;
    FStock: TCardArray;          { top of stock is the last element }
    FWasteTop: TCard;
    FWasteCount: Integer;
    FStreak: Integer;
    FBestStreak: Integer;
    FPlays: Integer;
    FWrapRanks: Boolean;
    FHistory: TUndoArray;        { every move undo could take back, oldest first }
    FHazard: THazard;
    FMarks: TMarkArray;
    FNeighbor: array[0..TableauSize - 1, 0..1] of Integer;   { the cards beside each one in its row (-1 = none) }
    FHandId: Integer;
    FStockSize: Integer;
    FSpare: TCardArray;
    FRevealed: Boolean;
    FStakes: Integer;
    FFeedOnce: Boolean;
    FBreakStart, FBreakLeft: Integer;
    procedure RecordMove(ADraw: Boolean; AIndex: Integer; AMissed: Boolean; ABitten: Boolean = False);
    procedure ForgetUndo;
    procedure EatCard;
    procedure UneatCard;
    function ValidState(const D: THandData): Boolean;
    procedure BuildLayout;
    procedure BuildNeighbours;
    function GetStockCount: Integer;
    function GetSpareCount: Integer;
    function GetTableauCard(I: Integer): TCard;
    function GetRemoved(I: Integer): Boolean;
    function GetRemaining: Integer;
    function GetRow(I: Integer): Integer;
    function GetX(I: Integer): Integer;
  public
    constructor Create;
    { Deals 28 tableau cards and turns the last card of the deck onto the waste.
      The stock is the next AStockSize cards (a smaller stock is a harder hand);
      any cards left over are not used. }
    procedure Deal(ADeck: TDeck; AStockSize: Integer = FullStock);
    function IsFree(I: Integer): Boolean;
    function CanPlay(I: Integer): Boolean;
    function PlayTableau(I: Integer): Boolean;   { False if not a legal play }
    function DrawStock: Boolean;                 { False if stock is empty }
    function HasMoves: Boolean;                  { any tableau play possible? }
    function IsWon: Boolean;
    function IsStuck: Boolean;                   { not won, stock empty, no plays }
    { Undo takes back the last move (a play or a draw), and again the one
      before it, as far back as the deal (or the last special card, which
      forgets them all). It is not allowed after the game is won. How many the
      player may take back is decided elsewhere (each costs an undo card: see
      Inventory). }
    function CanUndo: Boolean;
    function Undo: Boolean;
    function UndoDepth: Integer;          { how many moves could be taken back }
    function LastMoveMissed: Boolean;     { the move Undo would take back was a missed draw }
    function LastMoveBitten: Boolean;     { ... was the play of a bitten card }
    function LastMoveAte: Boolean;        { ... was a draw after which the vampire ate a card }

    { ---- a vampire's trick (see THazard). SetHazard chooses where the marks go
      for the hand just dealt, from the shuffle's own randomness. ---- }
    procedure SetHazard(AKind: THazard);
    procedure SetMark(I, Kind: Integer);          { by hand, for tests }
    { Lay the silver cross on a random tableau card that has no mark yet (face up
      in the bottom row, or face down higher up). Returns its index, or -1. }
    function PlaceCross: Integer;
    function HasMark(Kind: Integer): Boolean;     { a card of this mark is still on the table }
    function Mark(I: Integer): Integer;
    function IsLocked(I: Integer): Boolean;       { chained, with a neighbour still on the table, and no break left to spend }
    function IsLockedStrict(I: Integer): Boolean; { chained, with a neighbour still on the table (the plain rule) }
    { Relics that change the rules of the hand just dealt (call before the first
      move): the Iron Spoon lets him feed at most once, and the Locksmith's Pick gives
      ABreaks (0 or 1) chained cards that may be played anyway. }
    procedure SetRelicRules(AFeedOnce: Boolean; ABreaks: Integer);
    property FeedsOnce: Boolean read FFeedOnce;
    property BreaksLeft: Integer read FBreakLeft;
    property BreaksAtStart: Integer read FBreakStart;
    property Hazard: THazard read FHazard;
    { Capture the hand, and put one back. SetState checks the data against the
      game's own bookkeeping (card counts, which cards may be removed, ...) and
      returns False, changing nothing, if it cannot be a real hand. A finished
      (cleared) hand is also refused. }
    procedure GetState(out D: THandData);
    function SetState(const D: THandData): Boolean;
    { Ranks are adjacent: differ by one, or K/A when WrapRanks is on. }
    function Adjacent(A, B: TRank): Boolean;

    { ---- special cards (see Specials). Each changes this hand only, and none
      can be taken back with undo (using one forgets the undo). Each Can... says
      whether it would do anything now. ---- }
    function CanRestoreStock: Boolean;
    function RestoreStock: Boolean;      { the unused deal cards join the bottom of the stock }
    function CanOpenWrap: Boolean;
    function OpenWrap: Boolean;          { King and Ace become neighbours }
    function CanReveal: Boolean;
    function Reveal: Boolean;            { show every face-down tableau card }
    function CanWild(I: Integer): Boolean;
    function PlayWild(I: Integer): Boolean;   { a free card onto the waste, whatever its rank }
    function CanStake(I: Integer): Boolean;
    function Stake(I: Integer): Boolean;      { destroy a free card: the waste stays }
    function HasFreeCard: Boolean;       { any card with nothing covering it }

    property TableauCard[I: Integer]: TCard read GetTableauCard;
    property Removed[I: Integer]: Boolean read GetRemoved;
    property Remaining: Integer read GetRemaining;
    property Row[I: Integer]: Integer read GetRow;   { 0 = top }
    { Horizontal position in half-card-widths: bottom-row card k is at 2*k. }
    property X[I: Integer]: Integer read GetX;
    property WasteTop: TCard read FWasteTop;
    property WasteCount: Integer read FWasteCount;
    property StockCount: Integer read GetStockCount;
    property Streak: Integer read FStreak;
    property BestStreak: Integer read FBestStreak;
    property Plays: Integer read FPlays;
    property WrapRanks: Boolean read FWrapRanks write FWrapRanks;
    property HandId: Integer read FHandId;     { a number that names this deal }
    property StockSize: Integer read FStockSize;   { stock cards this hand started with }
    property SpareCount: Integer read GetSpareCount;   { unused deal cards a Full deck would add }
    property Revealed: Boolean read FRevealed;
    property Stakes: Integer read FStakes;
  end;

implementation

constructor TTriPeaksGame.Create;
begin
  inherited Create;
  FWrapRanks := True;
  FStockSize := FullStock;
  BuildLayout;
  BuildNeighbours;
end;

{ Neighbours: the cards in the same row one step (two half-cards) to either side. }
procedure TTriPeaksGame.BuildNeighbours;
var
  I, J: Integer;
begin
  for I := 0 to TableauSize - 1 do
  begin
    FNeighbor[I, 0] := -1;
    FNeighbor[I, 1] := -1;
    for J := 0 to TableauSize - 1 do
      if (J <> I) and (FRow[J] = FRow[I]) and (Abs(FX[J] - FX[I]) = 2) then
        if FX[J] < FX[I] then FNeighbor[I, 0] := J else FNeighbor[I, 1] := J;
  end;
end;

procedure TTriPeaksGame.BuildLayout;
var
  P, J, K, I: Integer;
begin
  { rows 0..2: cover indices; each row is built from the one below }
  for I := 0 to TableauSize - 1 do
  begin
    FCover[I, 0] := -1;
    FCover[I, 1] := -1;
  end;
  for P := 0 to 2 do
  begin
    FRow[P] := 0;                                  { row 0: index P }
    FCover[P, 0] := 3 + 2 * P;
    FCover[P, 1] := 3 + 2 * P + 1;
    for J := 0 to 1 do                             { row 1: 3 + 2P + J }
    begin
      K := 3 + 2 * P + J;
      FRow[K] := 1;
      FCover[K, 0] := 9 + 3 * P + J;
      FCover[K, 1] := 9 + 3 * P + J + 1;
    end;
    for J := 0 to 2 do                             { row 2: 9 + 3P + J }
    begin
      K := 9 + 3 * P + J;
      FRow[K] := 2;
      FCover[K, 0] := 18 + 3 * P + J;
      FCover[K, 1] := 18 + 3 * P + J + 1;
    end;
  end;
  for K := 18 to 27 do
  begin
    FRow[K] := 3;
    FX[K] := 2 * (K - 18);
  end;
  for K := 17 downto 0 do                          { children have higher index }
    FX[K] := (FX[FCover[K, 0]] + FX[FCover[K, 1]]) div 2;
end;

procedure TTriPeaksGame.Deal(ADeck: TDeck; AStockSize: Integer);
var
  I: Integer;
begin
  if AStockSize < 0 then AStockSize := 0;
  if AStockSize > FullStock then AStockSize := FullStock;
  FStockSize := AStockSize;
  for I := 0 to TableauSize - 1 do
  begin
    FTableau[I] := ADeck.Draw;
    FRemoved[I] := False;
  end;
  SetLength(FStock, 0);
  SetLength(FSpare, 0);
  while ADeck.Count > 1 do
    if Length(FStock) < AStockSize then
    begin
      SetLength(FStock, Length(FStock) + 1);
      FStock[High(FStock)] := ADeck.Draw;
    end
    else
    begin
      SetLength(FSpare, Length(FSpare) + 1);     { not in this hand's stock, but kept }
      FSpare[High(FSpare)] := ADeck.Draw;
    end;
  { the last card of the deck starts the waste }
  FWasteTop := ADeck.Draw;
  FWasteCount := 1;
  FStreak := 0;
  FBestStreak := 0;
  FPlays := 0;
  FStakes := 0;
  FRevealed := False;
  SetLength(FHistory, 0);                   { nothing of the last hand's undo lingers }
  FHazard := hzNone;
  FFeedOnce := False;
  FBreakStart := 0;
  FBreakLeft := 0;
  for I := 0 to TableauSize - 1 do FMarks[I] := MarkNone;
  FHandId := 1 + Random(MaxInt - 1);
end;

procedure TTriPeaksGame.RecordMove(ADraw: Boolean; AIndex: Integer; AMissed: Boolean; ABitten: Boolean);
begin
  { called before the move changes anything }
  SetLength(FHistory, Length(FHistory) + 1);
  with FHistory[High(FHistory)] do
  begin
    Draw := ADraw;
    Index := AIndex;
    Missed := AMissed;
    Bitten := ABitten;
    Ate := False;
    Broke := False;
    PrevWasteTop := FWasteTop;
    PrevStreak := FStreak;
  end;
end;

{ The vampire eats the bottom card of the stock: it goes to the unused cards. }
procedure TTriPeaksGame.EatCard;
var
  I: Integer;
begin
  SetLength(FSpare, Length(FSpare) + 1);
  FSpare[High(FSpare)] := FStock[0];
  for I := 1 to High(FStock) do FStock[I - 1] := FStock[I];
  SetLength(FStock, Length(FStock) - 1);
  Dec(FStockSize);
end;

{ ... and an undone feast puts it back. }
procedure TTriPeaksGame.UneatCard;
var
  I: Integer;
begin
  SetLength(FStock, Length(FStock) + 1);
  for I := High(FStock) downto 1 do FStock[I] := FStock[I - 1];
  FStock[0] := FSpare[High(FSpare)];
  SetLength(FSpare, Length(FSpare) - 1);
  Inc(FStockSize);
end;

procedure TTriPeaksGame.ForgetUndo;
begin
  SetLength(FHistory, 0);
end;

function TTriPeaksGame.CanUndo: Boolean;
begin
  Result := (Length(FHistory) > 0) and not IsWon;
end;

function TTriPeaksGame.UndoDepth: Integer;
begin
  if IsWon then Result := 0 else Result := Length(FHistory);
end;

function TTriPeaksGame.LastMoveMissed: Boolean;
begin
  Result := (Length(FHistory) > 0) and FHistory[High(FHistory)].Missed;
end;

function TTriPeaksGame.LastMoveBitten: Boolean;
begin
  Result := (Length(FHistory) > 0) and FHistory[High(FHistory)].Bitten;
end;

function TTriPeaksGame.LastMoveAte: Boolean;
begin
  Result := (Length(FHistory) > 0) and FHistory[High(FHistory)].Ate;
end;

function TTriPeaksGame.Undo: Boolean;
var
  M: TUndoMove;
begin
  Result := CanUndo;
  if not Result then Exit;
  M := FHistory[High(FHistory)];
  SetLength(FHistory, Length(FHistory) - 1);
  if M.Draw then
  begin
    SetLength(FStock, Length(FStock) + 1);     { the drawn card goes back on the stock }
    FStock[High(FStock)] := FWasteTop;
    if M.Ate then UneatCard;                   { and what he ate comes back under the stock }
  end
  else
  begin
    FRemoved[M.Index] := False;
    Dec(FPlays);
    if M.Broke then FBreakLeft := 1;           { the Pick's break is given back }
  end;
  FWasteTop := M.PrevWasteTop;
  Dec(FWasteCount);
  FStreak := M.PrevStreak;
end;

function TTriPeaksGame.Mark(I: Integer): Integer;
begin
  if (I < 0) or (I >= TableauSize) then Result := MarkNone else Result := FMarks[I];
end;

procedure TTriPeaksGame.SetMark(I, Kind: Integer);
begin
  if (I >= 0) and (I < TableauSize) then FMarks[I] := Kind;
end;

function TTriPeaksGame.PlaceCross: Integer;
var
  I, N: Integer;
begin
  Result := -1;
  N := 0;
  for I := 0 to TableauSize - 1 do
    if (FMarks[I] = MarkNone) and not FRemoved[I] then Inc(N);
  if N = 0 then Exit;
  N := Random(N);
  for I := 0 to TableauSize - 1 do
    if (FMarks[I] = MarkNone) and not FRemoved[I] then
    begin
      if N = 0 then
      begin
        FMarks[I] := MarkCross;
        Exit(I);
      end;
      Dec(N);
    end;
end;

function TTriPeaksGame.HasMark(Kind: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to TableauSize - 1 do
    if (FMarks[I] = Kind) and not FRemoved[I] then Exit(True);
end;

procedure TTriPeaksGame.SetRelicRules(AFeedOnce: Boolean; ABreaks: Integer);
begin
  FFeedOnce := AFeedOnce;
  if ABreaks < 0 then ABreaks := 0;
  if ABreaks > 1 then ABreaks := 1;
  FBreakStart := ABreaks;
  FBreakLeft := ABreaks;
end;

function TTriPeaksGame.IsLocked(I: Integer): Boolean;
begin
  Result := (FBreakLeft = 0) and IsLockedStrict(I);
end;

function TTriPeaksGame.IsLockedStrict(I: Integer): Boolean;
var
  Q: Integer;
begin
  Result := False;
  if (I < 0) or (I >= TableauSize) or (FMarks[I] <> MarkChained) or FRemoved[I] then Exit;
  for Q := 0 to 1 do
    if (FNeighbor[I, Q] >= 0) and not FRemoved[FNeighbor[I, Q]] then Result := True;
end;

procedure TTriPeaksGame.SetHazard(AKind: THazard);
var
  I, K, Q, N, Tries: Integer;
  Ok: Boolean;
begin
  FHazard := AKind;
  for I := 0 to TableauSize - 1 do FMarks[I] := MarkNone;
  case AKind of
    hzBitten:
    begin
      N := 0;
      while N < BittenCount do
      begin
        K := Random(TableauSize);
        if FMarks[K] = MarkNone then
        begin
          FMarks[K] := MarkBitten;
          Inc(N);
        end;
      end;
    end;
    hzChained:
    begin
      { in the lower three rows, never two beside each other (they would lock each other forever) }
      N := 0;
      Tries := 0;
      while (N < ChainedCount) and (Tries < 1000) do
      begin
        Inc(Tries);
        K := 3 + Random(TableauSize - 3);
        if FMarks[K] <> MarkNone then Continue;
        Ok := True;
        for Q := 0 to 1 do
          if (FNeighbor[K, Q] >= 0) and (FMarks[FNeighbor[K, Q]] = MarkChained) then Ok := False;
        if Ok then
        begin
          FMarks[K] := MarkChained;
          Inc(N);
        end;
      end;
    end;
  end;
end;

function TTriPeaksGame.Adjacent(A, B: TRank): Boolean;
begin
  Result := (Abs(A - B) = 1) or (FWrapRanks and (Abs(A - B) = 12));
end;

function TTriPeaksGame.IsFree(I: Integer): Boolean;
begin
  Result := (I >= 0) and (I < TableauSize) and not FRemoved[I]
    and ((FCover[I, 0] < 0) or FRemoved[FCover[I, 0]])
    and ((FCover[I, 1] < 0) or FRemoved[FCover[I, 1]]);
end;

function TTriPeaksGame.CanPlay(I: Integer): Boolean;
begin
  Result := IsFree(I) and not IsLocked(I) and Adjacent(FTableau[I].Rank, FWasteTop.Rank);
end;

function TTriPeaksGame.PlayTableau(I: Integer): Boolean;
begin
  Result := CanPlay(I);
  if not Result then Exit;
  RecordMove(False, I, False, FMarks[I] = MarkBitten);
  if IsLockedStrict(I) then                   { a chained card let through by the Pick: the one break is used }
  begin
    FHistory[High(FHistory)].Broke := True;
    FBreakLeft := 0;
  end;
  FRemoved[I] := True;
  FWasteTop := FTableau[I];
  Inc(FWasteCount);
  Inc(FPlays);
  if FMarks[I] = MarkBitten then
    FStreak := 0                              { the bite ends the streak }
  else
  begin
    Inc(FStreak);
    if FStreak > FBestStreak then FBestStreak := FStreak;
  end;
end;

function TTriPeaksGame.DrawStock: Boolean;
begin
  Result := Length(FStock) > 0;
  if not Result then Exit;
  RecordMove(True, 0, HasMoves);              { a miss if a card could have been played }
  FWasteTop := FStock[High(FStock)];
  SetLength(FStock, Length(FStock) - 1);
  Inc(FWasteCount);
  FStreak := 0;
  { hunger: after every FeedEvery-th draw he eats the bottom card of the stock }
  if (FHazard = hzHunger) and (Length(FStock) > 0)
    and ((FWasteCount - 1 - FPlays) mod FeedEvery = 0)
    and not (FFeedOnce and (FWasteCount - 1 - FPlays > FeedEvery)) then       { the Spoon: only the first feeding }
  begin
    EatCard;
    FHistory[High(FHistory)].Ate := True;
  end;
end;

function TTriPeaksGame.HasMoves: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to TableauSize - 1 do
    if CanPlay(I) then Exit;
  Result := False;
end;

function TTriPeaksGame.GetRemaining: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to TableauSize - 1 do
    if not FRemoved[I] then Inc(Result);
end;

function TTriPeaksGame.IsWon: Boolean;
begin
  Result := GetRemaining = 0;
end;

function TTriPeaksGame.IsStuck: Boolean;
begin
  Result := not IsWon and (Length(FStock) = 0) and not HasMoves;
end;

function TTriPeaksGame.GetSpareCount: Integer;
begin
  Result := Length(FSpare);
end;

function TTriPeaksGame.HasFreeCard: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to TableauSize - 1 do
    if IsFree(I) then Exit;
  Result := False;
end;

function TTriPeaksGame.CanRestoreStock: Boolean;
begin
  Result := (Length(FSpare) > 0) and not IsWon;
end;

function TTriPeaksGame.RestoreStock: Boolean;
var
  NewStock: TCardArray;
  I, N: Integer;
begin
  Result := CanRestoreStock;
  if not Result then Exit;
  { the extra cards go under the ones already waiting: the next draws are unchanged }
  SetLength(NewStock, Length(FSpare) + Length(FStock));
  N := 0;
  for I := 0 to High(FSpare) do begin NewStock[N] := FSpare[I]; Inc(N); end;
  for I := 0 to High(FStock) do begin NewStock[N] := FStock[I]; Inc(N); end;
  FStock := NewStock;
  FStockSize := FStockSize + Length(FSpare);
  SetLength(FSpare, 0);
  ForgetUndo;
end;

function TTriPeaksGame.CanOpenWrap: Boolean;
begin
  Result := not FWrapRanks and not IsWon;
end;

function TTriPeaksGame.OpenWrap: Boolean;
begin
  Result := CanOpenWrap;
  if not Result then Exit;
  FWrapRanks := True;
  ForgetUndo;
end;

function TTriPeaksGame.CanReveal: Boolean;
var
  I: Integer;
begin
  Result := False;
  if FRevealed or IsWon then Exit;
  for I := 0 to TableauSize - 1 do
    if not FRemoved[I] and not IsFree(I) then Exit(True);     { something is face down }
end;

function TTriPeaksGame.Reveal: Boolean;
begin
  Result := CanReveal;
  if not Result then Exit;
  FRevealed := True;
  ForgetUndo;
end;

function TTriPeaksGame.CanWild(I: Integer): Boolean;
begin
  Result := IsFree(I) and not IsWon;
end;

function TTriPeaksGame.PlayWild(I: Integer): Boolean;
begin
  Result := CanWild(I);
  if not Result then Exit;
  FRemoved[I] := True;
  FWasteTop := FTableau[I];
  Inc(FWasteCount);
  Inc(FPlays);
  Inc(FStreak);
  if FStreak > FBestStreak then FBestStreak := FStreak;
  ForgetUndo;
end;

function TTriPeaksGame.CanStake(I: Integer): Boolean;
begin
  Result := IsFree(I) and not IsWon;
end;

function TTriPeaksGame.Stake(I: Integer): Boolean;
begin
  Result := CanStake(I);
  if not Result then Exit;
  FRemoved[I] := True;
  Inc(FStakes);                            { not a play: the waste and the streak stay }
  ForgetUndo;
end;

function TTriPeaksGame.GetStockCount: Integer;
begin
  Result := Length(FStock);
end;

function TTriPeaksGame.GetTableauCard(I: Integer): TCard;
begin
  Result := FTableau[I];
end;

function TTriPeaksGame.GetRemoved(I: Integer): Boolean;
begin
  Result := FRemoved[I];
end;

function TTriPeaksGame.GetRow(I: Integer): Integer;
begin
  Result := FRow[I];
end;

function TTriPeaksGame.GetX(I: Integer): Integer;
begin
  Result := FX[I];
end;


{ ---- saving and loading a hand ---- }

procedure TTriPeaksGame.GetState(out D: THandData);
var
  I: Integer;
begin
  D.HandId := FHandId;
  D.StockSize := FStockSize;
  D.Wrap := FWrapRanks;
  D.Spare := Copy(FSpare);
  D.Revealed := FRevealed;
  D.Stakes := FStakes;
  for I := 0 to TableauSize - 1 do
  begin
    D.Tableau[I] := FTableau[I];
    D.Removed[I] := FRemoved[I];
  end;
  D.Stock := Copy(FStock);
  D.WasteTop := FWasteTop;
  D.WasteCount := FWasteCount;
  D.Streak := FStreak;
  D.BestStreak := FBestStreak;
  D.Plays := FPlays;
  D.History := Copy(FHistory);
  D.Hazard := Ord(FHazard);
  for I := 0 to TableauSize - 1 do D.Marks[I] := FMarks[I];
  D.FeedOnce := FFeedOnce;
  D.BreakStart := FBreakStart;
  D.BreakLeft := FBreakLeft;
end;

function TTriPeaksGame.ValidState(const D: THandData): Boolean;
var
  StockStart: Integer;                         { cards in the stock after the deal }
  I, K, Q, RemovedCount, VStock, VPlays, VWaste, VStreak, VStart, VSpare, Marked, Crosses, BreaksSeen: Integer;
  Broken: Boolean;
  VRemoved: TRemovedArray;
  VTop: TCard;
  M: TUndoMove;
  Su: TSuit;
  Rk: TRank;
  Seen: array[TSuit, TRank] of Boolean;

  function RemovedOk(const R: array of Boolean): Boolean;
  var
    J, Q: Integer;
  begin
    { a card can only be gone if both cards covering it are gone }
    Result := True;
    for J := 0 to TableauSize - 1 do
      if R[J] then
        for Q := 0 to 1 do
          if (FCover[J, Q] >= 0) and not R[FCover[J, Q]] then Result := False;
  end;

begin
  Result := False;
  if (D.StockSize < 0) or (D.StockSize > FullStock) then Exit;
  StockStart := D.StockSize;
  if Length(D.Stock) > StockStart then Exit;
  { the unused deal cards: what is left of the full stock (a save from before
    special cards has none, which is fine: a Full deck then has nothing to add) }
  if Length(D.Spare) > FullStock - StockStart then Exit;
  if D.Stakes < 0 then Exit;
  { the relic rules: the Pick gives at most one break, and the Spoon needs his hunger to matter (but is harmless without) }
  if (D.BreakStart < 0) or (D.BreakStart > 1) or (D.BreakLeft < 0) or (D.BreakLeft > D.BreakStart) then Exit;
  { a vampire's marks: only the kind his trick uses, in the places it can be }
  if (D.Hazard < Ord(Low(THazard))) or (D.Hazard > Ord(High(THazard))) then Exit;
  Marked := 0;
  Crosses := 0;
  for I := 0 to TableauSize - 1 do
  begin
    if (D.Marks[I] < MarkNone) or (D.Marks[I] > MarkCross) then Exit;
    if D.Marks[I] = MarkCross then Inc(Crosses)
    else if D.Marks[I] <> MarkNone then Inc(Marked);
    if (D.Marks[I] = MarkBitten) and (D.Hazard <> Ord(hzBitten)) then Exit;
    if (D.Marks[I] = MarkChained) and ((D.Hazard <> Ord(hzChained)) or (I < 3)) then Exit;
  end;
  if (Marked > BittenCount + ChainedCount) or (Crosses > 1) then Exit;
  for Su := Low(TSuit) to High(TSuit) do
    for Rk := Low(TRank) to High(TRank) do Seen[Su, Rk] := False;
  for I := 0 to TableauSize - 1 do
  begin
    if Seen[D.Tableau[I].Suit, D.Tableau[I].Rank] then Exit;     { no duplicates }
    Seen[D.Tableau[I].Suit, D.Tableau[I].Rank] := True;
  end;
  for K := 0 to High(D.Stock) do
  begin
    if Seen[D.Stock[K].Suit, D.Stock[K].Rank] then Exit;
    Seen[D.Stock[K].Suit, D.Stock[K].Rank] := True;
  end;
  for K := 0 to High(D.Spare) do
  begin
    if Seen[D.Spare[K].Suit, D.Spare[K].Rank] then Exit;
    Seen[D.Spare[K].Suit, D.Spare[K].Rank] := True;
  end;

  RemovedCount := 0;
  for I := 0 to TableauSize - 1 do
    if D.Removed[I] then Inc(RemovedCount);
  if RemovedCount >= TableauSize then Exit;             { a cleared hand is over }
  if not RemovedOk(D.Removed) then Exit;
  { the counters must agree with the cards, as the game itself keeps them }
  if D.Plays + D.Stakes <> RemovedCount then Exit;
  if D.WasteCount <> 1 + D.Plays + (StockStart - Length(D.Stock)) then Exit;
  if (D.Streak < 0) or (D.Streak > D.Plays) then Exit;
  { the best streak is not taken back by undo, so it can exceed the plays now;
    it can never be more than the whole board, or below the current streak }
  if (D.BestStreak < D.Streak) or (D.BestStreak > TableauSize) then Exit;
  { the waste card is the one last played (still in the tableau list) or drawn
    (so not in the stock or on the table) }
  if Seen[D.WasteTop.Suit, D.WasteTop.Rank] then
  begin
    { it must be a card already played from the tableau }
    K := -1;
    for I := 0 to TableauSize - 1 do
      if (D.Tableau[I].Suit = D.WasteTop.Suit) and (D.Tableau[I].Rank = D.WasteTop.Rank) then K := I;
    if (K < 0) or not D.Removed[K] then Exit;
  end;

  { the moves undo could take back: walk them backwards from now, and each
    step must leave a hand the rules could have produced }
  if Length(D.History) > TableauSize + StockStart then Exit;
  for I := 0 to TableauSize - 1 do VRemoved[I] := D.Removed[I];     { a copy: the walk changes it }
  VStock := Length(D.Stock);
  VStart := StockStart;
  VSpare := Length(D.Spare);
  VPlays := D.Plays;
  VWaste := D.WasteCount;
  VTop := D.WasteTop;
  VStreak := D.Streak;
  BreaksSeen := 0;
  for K := High(D.History) downto 0 do
  begin
    M := D.History[K];
    if M.PrevStreak < 0 then Exit;
    if M.Draw then
    begin
      if M.Bitten then Exit;
      if VStreak <> 0 then Exit;                      { a draw ends the streak }
      for I := 0 to TableauSize - 1 do                { a drawn card never came from the table }
        if (D.Tableau[I].Suit = VTop.Suit) and (D.Tableau[I].Rank = VTop.Rank) then Exit;
      if M.Broke then Exit;                           { a draw is never a break }
      Inc(VStock);
      if M.Ate then                                   { the card he ate comes back first }
      begin
        if (D.Hazard <> Ord(hzHunger)) or (VSpare <= 0) then Exit;
        Inc(VStock);
        Inc(VStart);
        Dec(VSpare);
      end;
      if VStock > VStart then Exit;                   { nowhere for the cards to go back to }
    end
    else
    begin
      if (M.Index < 0) or (M.Index >= TableauSize) or M.Missed or M.Ate then Exit;
      if M.Bitten <> (D.Marks[M.Index] = MarkBitten) then Exit;
      if not VRemoved[M.Index] then Exit;
      if (D.Tableau[M.Index].Suit <> VTop.Suit) or (D.Tableau[M.Index].Rank <> VTop.Rank) then Exit;
      if VPlays <= 0 then Exit;
      if M.Bitten then
      begin
        if VStreak <> 0 then Exit;                    { a bite ends the streak }
      end
      else if VStreak <> M.PrevStreak + 1 then Exit;
      for Q := 0 to 1 do                              { it was free when it was played }
        if (FCover[M.Index, Q] >= 0) and not VRemoved[FCover[M.Index, Q]] then Exit;
      if M.Broke then                                 { a break: a chained card, with a neighbour still on the table, and the Pick }
      begin
        if (D.Marks[M.Index] <> MarkChained) or (D.BreakStart <> 1) or (D.BreakLeft <> 0) then Exit;
        Broken := False;
        for Q := 0 to 1 do
          if (FNeighbor[M.Index, Q] >= 0) and not VRemoved[FNeighbor[M.Index, Q]] then Broken := True;
        if not Broken then Exit;
        Inc(BreaksSeen);
        if BreaksSeen > 1 then Exit;
      end;
      VRemoved[M.Index] := False;
      if not RemovedOk(VRemoved) then Exit;
      Dec(VPlays);
    end;
    Dec(VWaste);
    if VWaste < 1 then Exit;
    VTop := M.PrevWasteTop;
    VStreak := M.PrevStreak;
  end;
  Result := True;
end;

function TTriPeaksGame.SetState(const D: THandData): Boolean;
var
  I: Integer;
begin
  Result := ValidState(D);
  if not Result then Exit;
  FHandId := D.HandId;
  FStockSize := D.StockSize;
  FWrapRanks := D.Wrap;
  FSpare := Copy(D.Spare);
  FRevealed := D.Revealed;
  FStakes := D.Stakes;
  for I := 0 to TableauSize - 1 do
  begin
    FTableau[I] := D.Tableau[I];
    FRemoved[I] := D.Removed[I];
  end;
  FStock := Copy(D.Stock);
  FWasteTop := D.WasteTop;
  FWasteCount := D.WasteCount;
  FStreak := D.Streak;
  FBestStreak := D.BestStreak;
  FPlays := D.Plays;
  FHistory := Copy(D.History);
  FHazard := THazard(D.Hazard);
  for I := 0 to TableauSize - 1 do FMarks[I] := D.Marks[I];
  FFeedOnce := D.FeedOnce;
  FBreakStart := D.BreakStart;
  FBreakLeft := D.BreakLeft;
end;

end.
