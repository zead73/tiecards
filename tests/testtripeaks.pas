program TestTriPeaks;

{$mode objfpc}{$H+}

uses SysUtils, Cards, TriPeaks{$IFDEF PAS2JS}, JsCompat{$ENDIF};

var
  Failures: Integer = 0;

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
  begin
    WriteLn('FAIL: ', Msg);
    Inc(Failures);
  end;
end;

function MakeCard(Rank: Integer): TCard;
begin
  Result.Suit := suSpades;
  Result.Rank := Rank;
  Result.FaceUp := False;
end;

{ Deal order: 28 tableau cards (index 0..27), 24 stock (bottom first), waste last.
  Tableau card I is given ranks[I]; the rest is filled with the given stock rank. }
function BuildDeck(const TabRanks: array of Integer; StockRank, WasteRank: Integer): TDeck;
var
  A: TCardArray;
  I: Integer;
begin
  SetLength(A, 52);
  for I := 0 to 27 do A[I] := MakeCard(TabRanks[I]);
  for I := 28 to 50 do A[I] := MakeCard(StockRank);
  A[51] := MakeCard(WasteRank);
  Result := TDeck.CreateFromCards(A);
end;

procedure TestLayout;
var
  G: TTriPeaksGame;
  D: TDeck;
  I, FreeCount, BottomX: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do Ranks[I] := 5;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 1, 9);
  try
    G.Deal(D);
    Check(G.Remaining = 28, 'remaining at start is 28');
    Check(G.StockCount = 23, 'stock is 23 after deal (52 - 28 - 1)');
    FreeCount := 0;
    for I := 0 to 27 do
      if G.IsFree(I) then
      begin
        Inc(FreeCount);
        Check(I >= 18, 'only the bottom row is free at start');
      end;
    Check(FreeCount = 10, '10 free cards at start');
    BottomX := G.X[18];
    Check(BottomX = 0, 'bottom row starts at x=0');
    Check(G.X[27] = 18, 'bottom row ends at x=18');
    Check(G.X[0] = 3, 'first peak top at x=3');
    Check(G.X[1] = 9, 'second peak top at x=9');
    Check(G.X[2] = 15, 'third peak top at x=15');
    Check(G.Row[0] = 0, 'row of card 0');
    Check(G.Row[27] = 3, 'row of card 27');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestAdjacent;
var
  G: TTriPeaksGame;
begin
  G := TTriPeaksGame.Create;
  try
    Check(G.Adjacent(5, 6) and G.Adjacent(6, 5), 'adjacent both ways');
    Check(not G.Adjacent(5, 5), 'same rank not adjacent');
    Check(not G.Adjacent(5, 7), 'gap of two not adjacent');
    Check(G.Adjacent(1, 13) and G.Adjacent(13, 1), 'K/A adjacent by default');
    Check(not G.Adjacent(1, 12), 'Q/A not adjacent');
    G.WrapRanks := False;
    Check(not G.Adjacent(1, 13), 'K/A not adjacent when wrap is off');
  finally
    G.Free;
  end;
end;

procedure TestPlayRules;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do Ranks[I] := 12;
  Ranks[27] := 6;     { bottom right, free, matches waste 7 }
  Ranks[26] := 8;     { free, matches 7 }
  Ranks[25] := 9;     { free, does not match 7 }
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 3, 7);
  try
    G.Deal(D);
    Check(G.CanPlay(27), 'can play 6 on 7');
    Check(G.CanPlay(26), 'can play 8 on 7');
    Check(not G.CanPlay(25), 'cannot play 9 on 7');
    Check(not G.CanPlay(8), 'cannot play covered card');
    Check(not G.PlayTableau(25), 'PlayTableau rejects illegal play');
    Check(G.PlayTableau(27), 'play 6');
    Check(G.WasteTop.Rank = 6, 'waste top is now 6');
    Check(G.Removed[27], 'card 27 removed');
    Check(G.Streak = 1, 'streak 1');
    Check(not G.CanPlay(27), 'cannot replay removed card');
    Check(G.DrawStock, 'draw works');
    Check(G.WasteTop.Rank = 3, 'waste top is stock card');
    Check(G.Streak = 0, 'draw resets streak');
    Check(G.BestStreak = 1, 'best streak kept');
    Check(G.StockCount = 22, 'stock shrinks');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestUncover;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  { cards 27 and 26 cover row 2 card 17 (peak 2, j=2): 18+3*2+2=26, 27 }
  for I := 0 to 27 do Ranks[I] := 12;
  Ranks[26] := 6;
  Ranks[27] := 7;
  Ranks[17] := 6;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 3, 7);
  try
    G.Deal(D);
    Check(not G.IsFree(17), '17 is covered at start');
    Check(G.PlayTableau(26), 'play 6 on 7');
    Check(not G.IsFree(17), '17 still covered by 27');
    Check(G.PlayTableau(27), 'play 7 on 6');
    Check(G.IsFree(17), '17 free once both coverers gone');
    Check(G.PlayTableau(17), 'play uncovered 6 on 7');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestWin;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  { removal order 27,26,...,0 is always valid; alternate 6,7 starting on waste 7 }
  for I := 0 to 27 do
    if (27 - I) mod 2 = 0 then Ranks[I] := 6 else Ranks[I] := 7;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 1, 7);
  try
    G.Deal(D);
    for I := 27 downto 0 do
      Check(G.PlayTableau(I), 'winning play ' + IntToStr(I));
    Check(G.IsWon, 'game is won');
    Check(not G.IsStuck, 'won game is not stuck');
    Check(G.BestStreak = 28, 'streak of 28');
    Check(G.Plays = 28, '28 plays');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestStuck;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do Ranks[I] := 12;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 3, 1);       { waste 1, nothing adjacent (stock is 3s) }
  try
    G.Deal(D);
    Check(not G.HasMoves, 'no tableau moves');
    Check(not G.IsStuck, 'not stuck while stock remains');
    while G.DrawStock do ;
    Check(G.StockCount = 0, 'stock empty');
    Check(G.IsStuck, 'stuck when stock empty and no moves');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestUndo;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do Ranks[I] := 12;
  Ranks[27] := 6;
  Ranks[26] := 7;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 3, 7);
  try
    G.Deal(D);
    Check(not G.CanUndo, 'no undo before any move');
    Check(not G.Undo, 'Undo fails before any move');
    { undo a play }
    Check(G.PlayTableau(27), 'play 6');
    Check(G.PlayTableau(26), 'play 7');
    Check(G.Streak = 2, 'streak 2');
    Check(G.CanUndo, 'can undo after a play');
    Check(G.Undo, 'undo the 7');
    Check(not G.Removed[26], '7 is back');
    Check(G.Removed[27], 'only the last move is undone');
    Check(G.WasteTop.Rank = 6, 'waste top restored to 6');
    Check(G.Streak = 1, 'streak restored');
    Check(G.Plays = 1, 'plays restored');
    Check(G.Remaining = 27, 'remaining restored');
    Check(G.CanUndo, 'the play before can be undone too');
    Check(G.UndoDepth = 1, 'one move left to undo');
    Check(G.Undo, 'undo the 6 as well');
    Check(not G.Removed[27] and (G.Plays = 0) and (G.WasteCount = 1), 'back at the deal');
    Check(not G.CanUndo, 'nothing left to undo at the deal');
    Check(G.PlayTableau(27) and G.PlayTableau(26) and G.Undo, 'replayed, and the 7 is undone again');
    { undo a draw }
    Check(G.DrawStock, 'draw');
    Check(G.StockCount = 22, 'stock 22 after draw');
    Check(G.Undo, 'undo the draw');
    Check(G.StockCount = 23, 'stock restored');
    Check(G.WasteTop.Rank = 6, 'waste restored after undoing draw');
    Check(G.WasteCount = 2, 'waste count restored');
    { the undone card can be played again }
    Check(G.PlayTableau(26), 'replay the 7');
  finally
    G.Free;
    D.Free;
  end;
end;

function StatesEqual(const A, B: THandData): Boolean; forward;

{ Undo goes back through every move to the deal, whatever the mix of plays and
  draws, and lands on exactly the hand it started from. }
{ ---- the vampires' tricks ---- }

procedure ClearMarks(G: TTriPeaksGame);
var
  I: Integer;
begin
  for I := 0 to TableauSize - 1 do G.SetMark(I, MarkNone);
end;

procedure TestBittenCards;
var
  G: TTriPeaksGame;
  D: TDeck;
  I, N, Bitten: Integer;
  Ranks: array[0..27] of Integer;
begin
  Randomize;
  G := TTriPeaksGame.Create;
  try
    { where the marks go }
    for N := 1 to 200 do
    begin
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D);
      D.Free;
      G.SetHazard(hzBitten);
      Bitten := 0;
      for I := 0 to TableauSize - 1 do
        if G.Mark(I) = MarkBitten then Inc(Bitten)
        else Check(G.Mark(I) = MarkNone, 'a bitten hand has only bitten marks');
      Check(Bitten = BittenCount, 'exactly three cards are bitten');
    end;
    { what a bite does }
    for I := 0 to 27 do Ranks[I] := 12;
    Ranks[27] := 6;
    Ranks[26] := 7;
    D := BuildDeck(Ranks, 3, 7);
    try
      G.Deal(D);
    finally
      D.Free;
    end;
    G.SetHazard(hzBitten);
    ClearMarks(G);
    G.SetMark(26, MarkBitten);
    Check(G.PlayTableau(27), 'play the 6');
    Check(G.Streak = 1, 'a streak of one');
    Check(G.PlayTableau(26), 'play the bitten 7: it is allowed');
    Check(G.LastMoveBitten, 'the game knows it was a bite');
    Check(G.Streak = 0, 'the bite ended the streak');
    Check(G.BestStreak = 1, 'but not the best streak');
    Check(G.Undo and (G.Streak = 1) and not G.LastMoveBitten, 'undoing the bite gives the streak back');
    Check(G.PlayTableau(26) and (G.Plays = 2), 'and it can be bitten again');
  finally
    G.Free;
  end;
end;

procedure TestChainedCards;
var
  G: TTriPeaksGame;
  D: TDeck;
  I, N, K, Chained: Integer;
  Ranks: array[0..27] of Integer;
  Nb: Boolean;
begin
  G := TTriPeaksGame.Create;
  try
    for N := 1 to 300 do
    begin
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D);
      D.Free;
      G.SetHazard(hzChained);
      Chained := 0;
      for I := 0 to TableauSize - 1 do
        if G.Mark(I) = MarkChained then
        begin
          Inc(Chained);
          Check(I >= 3, 'a peak top is never chained');
          for K := 0 to TableauSize - 1 do
            if (K <> I) and (G.Row[K] = G.Row[I]) and (Abs(G.X[K] - G.X[I]) = 2) then
            begin
              Nb := G.Mark(K) = MarkChained;
              Check(not Nb, 'two chained cards are never neighbours');
            end;
        end;
      Check(Chained = ChainedCount, 'exactly three cards are chained');
    end;
    { the lock }
    for I := 0 to 27 do Ranks[I] := 12;
    Ranks[27] := 6;                          { chained, and right for the waste 7 }
    Ranks[26] := 8;                          { its neighbour, also playable on a 7 }
    D := BuildDeck(Ranks, 3, 7);
    try
      G.Deal(D);
    finally
      D.Free;
    end;
    G.SetHazard(hzChained);
    ClearMarks(G);
    G.SetMark(27, MarkChained);
    Check(G.IsFree(27) and G.IsLocked(27), 'a chained card with a neighbour is locked');
    Check(not G.CanPlay(27), 'and cannot be played, though its rank is right');
    Check(not G.PlayTableau(27), 'the play is refused');
    Check(G.CanWild(27) and G.CanStake(27), 'a Wild card or a Wood Stake still reach it');
    Check(G.CanPlay(26), 'the neighbour plays as usual');
    Check(G.HasMoves, 'there is a move');
    Check(G.PlayTableau(26), 'play the neighbour');
    Check(not G.IsLocked(27), 'now the chain is slack');
    Check(G.Undo and G.IsLocked(27), 'undoing it ties the chain again');
    { a Wood Stake on the neighbour also frees it }
    G.Stake(26);
    Check(not G.IsLocked(27), 'destroying the neighbour frees it too');
  finally
    G.Free;
  end;
end;

procedure TestHunger;
var
  G: TTriPeaksGame;
  D: TDeck;
  D2State: THandData;
  I, StockBefore: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do Ranks[I] := 12;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 3, 7);
  try
    G.Deal(D);
    G.SetHazard(hzHunger);
    Check(G.StockCount = FullStock, 'a full stock to begin with');
    for I := 1 to 3 do Check(G.DrawStock and not G.LastMoveAte, 'draw ' + IntToStr(I) + ': he is not hungry yet');
    Check(G.StockCount = FullStock - 3, 'three cards drawn');
    Check(G.SpareCount = 0, 'and none eaten');
    StockBefore := G.StockCount;
    Check(G.DrawStock, 'the fourth draw');
    Check(G.LastMoveAte, 'he eats after it');
    Check(G.StockCount = StockBefore - 2, 'one card drawn and one eaten');
    Check(G.SpareCount = 1, 'the eaten card is kept with the unused ones');
    Check(G.CanRestoreStock, 'so a Full deck would bring it back');
    { undo takes the feast back with the draw }
    Check(G.Undo, 'undo the draw');
    Check((G.StockCount = StockBefore) and (G.SpareCount = 0) and not G.LastMoveAte, 'the card he ate is back');
    Check(G.WasteCount = 4, 'and the waste is as it was');
    { the eaten card is the one at the bottom }
    Check(G.DrawStock and G.LastMoveAte, 'and he eats again after the redo');
    G.GetState(D2State);
    Check(D2State.Hazard = Ord(hzHunger), 'the state remembers the hunger');
    for I := 1 to 3 do G.DrawStock;
    Check(G.DrawStock and G.LastMoveAte, 'the eighth draw feeds him again');
    Check(G.SpareCount = 2, 'two cards eaten so far');
    Check(G.RestoreStock and (G.SpareCount = 0), 'a Full deck gives them back');
    Check(G.StockCount = FullStock - 8 - 2 + 2, 'the stock is whole again (8 drawn)');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestTrickStates;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, B: THandData;
  Kind: THazard;
  N, Steps, I, Rejected, Moves, Undone: Integer;
  Acted: Boolean;
begin
  Rejected := 0;
  Moves := 0;
  Undone := 0;
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    for Kind := hzBitten to hzHunger do
      for N := 1 to 150 do
      begin
        D := TDeck.Create;
        D.Shuffle;
        G.Deal(D, FullStock - Random(4));
        D.Free;
        G.SetHazard(Kind);
        for Steps := 1 to 80 do
        begin
          if G.IsWon or G.IsStuck then Break;
          Acted := False;
          if (Random(6) = 0) and G.CanUndo then
          begin
            G.Undo;
            Inc(Undone);
            Acted := True;
          end
          else
          begin
            for I := TableauSize - 1 downto 0 do
              if (Random(3) > 0) and G.PlayTableau(I) then
              begin
                Acted := True;
                Break;
              end;
            if not Acted then Acted := G.DrawStock;
          end;
          if not Acted or G.IsWon then Break;           { a cleared hand is over: nothing to reload }
          G.GetState(A);
          Inc(Moves);
          if not G2.SetState(A) then
          begin
            Inc(Rejected);
            Continue;
          end;
          G2.GetState(B);
          Check(StatesEqual(A, B), 'a hand with a trick reloads exactly');
        end;
      end;
  finally
    G.Free;
    G2.Free;
  end;
  Check(Rejected = 0, 'every real hand with a trick was accepted (' + IntToStr(Rejected) + ' of ' + IntToStr(Moves) + ' refused)');
  Check(Moves > 5000, 'enough states were checked (' + IntToStr(Moves) + '), including ' + IntToStr(Undone) + ' undos');
end;

procedure TestBadTrickStates;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, Bad: THandData;
  I, X, N: Integer;
  Rows: array[0..3] of Integer;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  D := TDeck.Create;
  try
    D.Shuffle;
    G.Deal(D);
    G.SetHazard(hzChained);
    G.GetState(A);
    Check(G2.SetState(A), 'a chained hand is accepted');
    Bad := A; Bad.Hazard := 9;
    Check(not G2.SetState(Bad), 'an unknown trick is refused');
    Bad := A; Bad.Marks[5] := 7;
    Check(not G2.SetState(Bad), 'an unknown mark is refused');
    Bad := A; Bad.Hazard := Ord(hzHunger);
    Check(not G2.SetState(Bad), 'chains in a hungry hand are refused');
    Bad := A; Bad.Marks[1] := MarkChained;
    Check(not G2.SetState(Bad), 'a chained peak top is refused');
    Bad := A; Bad.Hazard := Ord(hzNone);
    Check(not G2.SetState(Bad), 'marks in a hand with no trick are refused');
    G.SetHazard(hzBitten);
    G.GetState(A);
    Bad := A; Bad.Hazard := Ord(hzChained);
    Check(not G2.SetState(Bad), 'bites in a chained hand are refused');
    { the silver cross: one, anywhere on the table, with any trick or none }
    for I := 0 to 3 do
    begin
      D.Free;
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D);
      if I > 0 then G.SetHazard(THazard(I));
      Check(G.PlaceCross >= 0, 'the cross is laid on the table');
      G.GetState(A);
      Check(G2.SetState(A), 'a hand with the cross is accepted (trick ' + IntToStr(I) + ')');
      Bad := A;
      for X := 0 to TableauSize - 1 do
        if Bad.Marks[X] = MarkNone then
        begin
          Bad.Marks[X] := MarkCross;
          Break;
        end;
      Check(not G2.SetState(Bad), 'two crosses are refused');
    end;
    D.Free;
    D := TDeck.Create;
    D.Shuffle;
    G.Deal(D);
    for I := 0 to TableauSize - 1 do G.SetMark(I, MarkBitten);
    Check(G.PlaceCross < 0, 'with every card marked the cross finds no place');
    { where it can land: every row, bottom row included }
    for I := 0 to 3 do Rows[I] := 0;
    for N := 1 to 600 do
    begin
      D.Free;
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D);
      X := G.PlaceCross;
      Inc(Rows[G.Row[X]]);
    end;
    for I := 0 to 3 do
      Check(Rows[I] > 0, 'the cross lands in row ' + IntToStr(I) + ' sometimes');
  finally
    G.Free; G2.Free; D.Free;
  end;
end;

{ ---- the relics' rules: the Locksmith's Pick and the Iron Spoon ---- }

procedure TestPick;
var
  G: TTriPeaksGame;
  D: TDeck;
  I, N, K, Chained, Used: Integer;
  A, B, Start: THandData;
  Ranks: array[0..27] of Integer;
begin
  G := TTriPeaksGame.Create;
  try
    { a hand where bottom-row card 25 is chained and its neighbour 24 is still there }
    for I := 0 to 27 do Ranks[I] := 12;
    Ranks[25] := 6;
    Ranks[24] := 7;
    G.Deal(BuildDeck(Ranks, 3, 7));
    G.SetHazard(hzChained);
    ClearMarks(G);
    G.SetMark(25, MarkChained);
    Check(G.IsLocked(25) and not G.CanPlay(25), 'no Pick: the chained card is locked while its neighbour is there');
    G.SetRelicRules(False, 1);
    Check(G.BreaksLeft = 1, 'the Pick gives one break');
    Check(G.IsLockedStrict(25) and not G.IsLocked(25), 'with the Pick the card is let through (the plain rule still says locked)');
    Check(G.CanPlay(25), 'and it can be played');
    Check(G.HasMoves, 'a break counts as a move (a hand is not stuck while one could save it)');
    G.GetState(Start);
    Check(G.PlayTableau(25), 'play it');
    Check(G.BreaksLeft = 0, 'the break is spent');
    G.GetState(A);
    Check(A.History[High(A.History)].Broke, 'the move remembers it broke a chain');
    G.SetMark(23, MarkChained);                       { another chained card, its neighbours still there }
    Check(G.IsLocked(23), 'a second chained card is locked: one break a hand');
    Check(G.Undo, 'undo the play');
    Check(G.BreaksLeft = 1, 'and the break is given back');
    G.SetMark(23, MarkNone);                          { the test's own extra chain comes off }
    G.GetState(B);
    Check((B.Plays = 0) and (B.WasteCount = 1) and not B.Removed[25] and (B.BreakLeft = 1) and (Length(B.History) = 0),
      'back at the start: the card is back, the break unspent, nothing to undo');
  finally
    G.Free;
  end;
end;

procedure TestRelicStates;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, B, Start: THandData;
  Kind: THazard;
  N, Steps, I, Rejected, Moves, Breaks, Skips: Integer;
  Acted: Boolean;
begin
  Rejected := 0;
  Moves := 0;
  Breaks := 0;
  Skips := 0;
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    for Kind := hzChained to hzHunger do
      for N := 1 to 200 do
      begin
        D := TDeck.Create;
        D.Shuffle;
        G.Deal(D, FullStock - Random(4));
        D.Free;
        G.SetHazard(Kind);
        G.SetRelicRules(Random(2) = 0, Random(2));
        G.GetState(Start);
        for Steps := 1 to 90 do
        begin
          if G.IsWon or G.IsStuck then Break;
          Acted := False;
          if (Random(6) = 0) and G.CanUndo then
          begin
            G.Undo;
            Acted := True;
          end
          else
          begin
            for I := TableauSize - 1 downto 0 do
              if (Random(3) > 0) and G.PlayTableau(I) then
              begin
                Acted := True;
                Break;
              end;
            if not Acted then Acted := G.DrawStock;
          end;
          if not Acted or G.IsWon then Break;
          G.GetState(A);
          Inc(Moves);
          if (A.BreakStart = 1) and (A.BreakLeft = 0) then Inc(Breaks);
          if A.FeedSkip and (A.WasteCount - 1 - A.Plays > FeedEvery) then Inc(Skips);
          if not G2.SetState(A) then
          begin
            Inc(Rejected);
            Continue;
          end;
          G2.GetState(B);
          Check(StatesEqual(A, B), 'a hand with relic rules reloads exactly');
        end;
        { undo all the way: back to the deal, break and all }
        while G.CanUndo do G.Undo;
        if not G.IsWon then
        begin
          G.GetState(B);
          Check((B.BreakLeft = B.BreakStart) and (B.BreakStart = Start.BreakStart), 'undone to the start: the break is back');
          Check(B.WasteCount = 1, 'and the deal is as it was');
        end;
      end;
  finally
    G.Free;
    G2.Free;
  end;
  Check(Rejected = 0, 'every real hand with relic rules was accepted (' + IntToStr(Rejected) + ' of ' + IntToStr(Moves) + ' refused)');
  Check(Breaks > 50, 'enough hands used the Pick (' + IntToStr(Breaks) + ')');
  Check(Skips > 50, 'enough hands went past the Spoon''s skipped feeding (' + IntToStr(Skips) + ')');
end;

procedure TestSpoon;
var
  G: TTriPeaksGame;
  Ranks: array[0..27] of Integer;
  I, N: Integer;
begin
  for I := 0 to 27 do Ranks[I] := 12;
  G := TTriPeaksGame.Create;
  try
    { without the Spoon he feeds after the 4th draw }
    G.Deal(BuildDeck(Ranks, 3, 7));
    G.SetHazard(hzHunger);
    for N := 1 to 3 do G.DrawStock;
    Check(not G.LastMoveAte, 'three draws: nothing eaten');
    G.DrawStock;
    Check(G.LastMoveAte, 'the 4th draw: he feeds');
    { with it, the first feeding is skipped; the next is the 8th draw }
    G.Deal(BuildDeck(Ranks, 3, 7));
    G.SetHazard(hzHunger);
    G.SetRelicRules(True, 0);
    for N := 1 to 4 do G.DrawStock;
    Check(not G.LastMoveAte and (G.StockCount = 23 - 4), 'with the Spoon the 4th draw eats nothing');
    for N := 5 to 7 do G.DrawStock;
    Check(not G.LastMoveAte, 'nor the 5th to 7th');
    G.DrawStock;
    Check(G.LastMoveAte, 'the 8th draw is the first feeding');
    Check(G.Undo and not G.LastMoveAte, 'undo gives the eaten card back');
    { only the first is skipped: 12th feeds, too }
    G.DrawStock;
    for N := 9 to 11 do G.DrawStock;
    Check(not G.LastMoveAte, 'the 9th to 11th: nothing');
    G.DrawStock;
    Check(G.LastMoveAte, 'and the 12th');
  finally
    G.Free;
  end;
end;

procedure TestBadRelicStates;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, Bad: THandData;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  D := TDeck.Create;
  try
    D.Shuffle;
    G.Deal(D);
    G.SetHazard(hzChained);
    G.SetRelicRules(True, 1);
    G.GetState(A);
    Check(G2.SetState(A), 'a hand with both relic rules is accepted');
    Bad := A; Bad.BreakStart := 2; Bad.BreakLeft := 2;
    Check(not G2.SetState(Bad), 'two breaks are refused');
    Bad := A; Bad.BreakLeft := 2;
    Check(not G2.SetState(Bad), 'more breaks left than it began with is refused');
    Bad := A; Bad.BreakLeft := -1;
    Check(not G2.SetState(Bad), 'a negative count is refused');
    Bad := A; Bad.BreakStart := 0; Bad.BreakLeft := 0;
    SetLength(Bad.History, 1);
    Bad.History[0].Draw := False;
    Bad.History[0].Index := 0;
    Bad.History[0].Broke := True;
    Check(not G2.SetState(Bad), 'a break in the history with no Pick is refused');
  finally
    G.Free; G2.Free; D.Free;
  end;
end;

procedure TestUndoWholeHand;
var
  G: TTriPeaksGame;
  D: TDeck;
  Start, Now, Mid: THandData;
  N, I, Moves, Depth: Integer;
  Saved: Boolean;
  G2: TTriPeaksGame;
begin
  Randomize;
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    for N := 1 to 300 do
    begin
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D);
      D.Free;
      G.GetState(Start);
      Moves := 0;
      Saved := False;
      while not G.IsWon and not G.IsStuck and (Moves < 60) do
      begin
        I := Random(30);
        if (I < 28) and G.PlayTableau(I) then Inc(Moves)
        else if (I >= 28) and (Random(3) = 0) and G.DrawStock then Inc(Moves);
        if (Moves = 20) and not Saved then
        begin
          Saved := True;                     { a hand reloaded half way undoes just as far }
          G.GetState(Mid);
          Check(G2.SetState(Mid), 'game ' + IntToStr(N) + ': a hand with a long history reloads');
          Check(G2.UndoDepth = G.UndoDepth, 'game ' + IntToStr(N) + ': the reloaded hand keeps its undo');
        end;
      end;
      if G.IsWon then Continue;
      Check(G.UndoDepth = Moves, 'game ' + IntToStr(N) + ': one undo step per move');
      Depth := 0;
      while G.Undo do Inc(Depth);
      Check(Depth = Moves, 'game ' + IntToStr(N) + ': every move was taken back');
      G.GetState(Now);
      Now.BestStreak := Start.BestStreak;     { the best streak is a record: undo does not take it back }
      Check(StatesEqual(Start, Now), 'game ' + IntToStr(N) + ': undoing all moves restores the deal');
      Check(Length(Now.History) = 0, 'and the history is empty');
    end;
  finally
    G.Free;
    G2.Free;
  end;
end;

procedure TestUndoForgottenBySpecial;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do Ranks[I] := 12;
  Ranks[27] := 6;
  Ranks[26] := 7;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 3, 7);
  try
    G.Deal(D);
    G.PlayTableau(27);
    G.PlayTableau(26);
    G.DrawStock;
    Check(G.UndoDepth = 3, 'three moves to undo');
    Check(G.Reveal, 'a special card is used');
    Check((G.UndoDepth = 0) and not G.CanUndo, 'it forgets every move, not just the last');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestUndoBlockedAfterWin;
var
  G: TTriPeaksGame;
  D: TDeck;
  I: Integer;
  Ranks: array[0..27] of Integer;
begin
  for I := 0 to 27 do
    if (27 - I) mod 2 = 0 then Ranks[I] := 6 else Ranks[I] := 7;
  G := TTriPeaksGame.Create;
  D := BuildDeck(Ranks, 1, 7);
  try
    G.Deal(D);
    for I := 27 downto 0 do G.PlayTableau(I);
    Check(G.IsWon, 'won');
    Check(not G.CanUndo, 'no undo after winning');
    Check(not G.Undo, 'Undo refused after winning');
    Check(G.IsWon, 'still won');
  finally
    G.Free;
    D.Free;
  end;
end;

procedure TestRandomGames;
var
  G: TTriPeaksGame;
  D: TDeck;
  N, I, Wins: Integer;
begin
  Randomize;
  Wins := 0;
  for N := 1 to 2000 do
  begin
    G := TTriPeaksGame.Create;
    D := TDeck.Create;
    try
      D.Shuffle;
      G.Deal(D);
      Check(D.Count = 0, 'deal consumes the deck');
      repeat
        for I := 27 downto 0 do         { greedy: play anything playable }
          if G.PlayTableau(I) then Break;
        if not G.HasMoves then
          if not G.DrawStock then Break;
        Check(G.WasteCount = 1 + G.Plays + (23 - G.StockCount), 'waste count consistent');
      until G.IsWon or G.IsStuck;
      Check(G.IsWon or G.IsStuck, 'game ends either won or stuck');
      if G.IsWon then Inc(Wins);
    finally
      G.Free;
      D.Free;
    end;
  end;
  WriteLn('random greedy games: ', Wins, ' of 2000 won');
end;

function CardsEqual(const A, B: TCard): Boolean;
begin
  Result := (A.Suit = B.Suit) and (A.Rank = B.Rank);
end;

function StatesEqual(const A, B: THandData): Boolean;
var
  I: Integer;
begin
  Result := (A.HandId = B.HandId) and (A.WasteCount = B.WasteCount)
    and (A.StockSize = B.StockSize) and (A.Wrap = B.Wrap)
    and (A.Streak = B.Streak) and (A.BestStreak = B.BestStreak) and (A.Plays = B.Plays)
    and (Length(A.Stock) = Length(B.Stock)) and CardsEqual(A.WasteTop, B.WasteTop)
    and (Length(A.History) = Length(B.History)) and (A.Hazard = B.Hazard)
    and (A.FeedSkip = B.FeedSkip) and (A.BreakStart = B.BreakStart) and (A.BreakLeft = B.BreakLeft);
  if not Result then Exit;
  for I := 0 to TableauSize - 1 do
    if not CardsEqual(A.Tableau[I], B.Tableau[I]) or (A.Removed[I] <> B.Removed[I]) or (A.Marks[I] <> B.Marks[I]) then
      Result := False;
  for I := 0 to High(A.Stock) do
    if not CardsEqual(A.Stock[I], B.Stock[I]) then Result := False;
  for I := 0 to High(A.History) do
    if (A.History[I].Draw <> B.History[I].Draw) or (A.History[I].Index <> B.History[I].Index)
      or (A.History[I].Missed <> B.History[I].Missed) or (A.History[I].PrevStreak <> B.History[I].PrevStreak)
      or (A.History[I].Broke <> B.History[I].Broke)
      or (A.History[I].Bitten <> B.History[I].Bitten) or (A.History[I].Ate <> B.History[I].Ate)
      or not CardsEqual(A.History[I].PrevWasteTop, B.History[I].PrevWasteTop) then
      Result := False;
end;

procedure TestStateRoundTrip;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, B: THandData;
  N, I, Moves, Rejected: Integer;
  Won: Boolean;
begin
  Rejected := 0;
  Moves := 0;
  for N := 1 to 400 do
  begin
    G := TTriPeaksGame.Create;
    G2 := TTriPeaksGame.Create;
    D := TDeck.Create;
    try
      D.Shuffle;
      G.Deal(D);
      repeat
        { save and restore at every step, including right after the deal }
        G.GetState(A);
        if not G.IsWon then
        begin
          Inc(Moves);
          if not G2.SetState(A) then Inc(Rejected)
          else
          begin
            G2.GetState(B);
            if not StatesEqual(A, B) then
            begin
              Check(False, 'a restored hand differs from the saved one');
              Break;
            end;
          end;
        end;
        { make a move: play something, else draw; sometimes undo }
        Won := False;
        for I := 27 downto 0 do
          if G.PlayTableau(I) then Break;
        if not G.HasMoves then
          if not G.DrawStock then Break;
        if (Random(7) = 0) and G.CanUndo then G.Undo;
        Won := G.IsWon;
      until Won or G.IsStuck;
    finally
      G.Free; G2.Free; D.Free;
    end;
  end;
  Check(Rejected = 0, 'every real hand state was accepted (' + IntToStr(Rejected) + ' of ' + IntToStr(Moves) + ' rejected)');
  Check(Moves > 5000, 'enough states were checked (' + IntToStr(Moves) + ')');
end;

procedure TestStateRestoresBehaviour;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, B: THandData;
  I, K: Integer;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  D := TDeck.Create;
  try
    D.Shuffle;
    G.Deal(D);
    for K := 1 to 6 do                          { a few moves in }
    begin
      for I := 27 downto 0 do
        if G.PlayTableau(I) then Break;
      if not G.HasMoves then G.DrawStock;
    end;
    G.GetState(A);
    Check(G2.SetState(A), 'the state is accepted');
    Check(G2.HandId = G.HandId, 'the hand keeps its id');
    Check(G2.CanUndo = G.CanUndo, 'the undo carries over');
    { carry on playing both identically: they must stay in step }
    for K := 1 to 12 do
    begin
      for I := 27 downto 0 do
      begin
        if G.CanPlay(I) then
        begin
          Check(G2.CanPlay(I), 'the same cards are playable');
          G.PlayTableau(I);
          G2.PlayTableau(I);
          Break;
        end;
      end;
      if not G.HasMoves then
      begin
        Check(G.DrawStock = G2.DrawStock, 'drawing agrees');
      end;
    end;
    G.GetState(A);
    G2.GetState(B);
    Check(StatesEqual(A, B), 'after more play they are still identical');
    { and undo works the same on the restored game }
    if G.CanUndo then
    begin
      Check(G2.CanUndo, 'undo still available');
      G.Undo; G2.Undo;
      G.GetState(A); G2.GetState(B);
      Check(StatesEqual(A, B), 'undoing gives the same hand on both');
    end;
  finally
    G.Free; G2.Free; D.Free;
  end;
end;

{ A deck of 52 distinct cards in a known order, so we can see which went where. }
function KnownDeck: TDeck;
var
  A: TCardArray;
  I: Integer;
begin
  SetLength(A, 52);
  for I := 0 to 51 do
  begin
    A[I].Suit := TSuit(I div 13);
    A[I].Rank := (I mod 13) + 1;
    A[I].FaceUp := False;
  end;
  Result := TDeck.CreateFromCards(A);
end;

procedure TestStockSize;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, Bad: THandData;
  I, K, Draws: Integer;
  Probe: TDeck;
  Ref: TCard;
  StockRef: array[0..16] of TCard;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    Check(G.StockSize = FullStock, 'a game starts with the full stock size');
    D := KnownDeck;
    try
      G.Deal(D, 17);
    finally
      D.Free;
    end;
    Probe := KnownDeck;                            { the same deck, to read the cards from }
    try
      Check((G.StockCount = 17) and (G.StockSize = 17), 'the stock has the cards asked for');
      for I := 0 to TableauSize - 1 do
      begin
        Ref := Probe.Draw;
        Check((G.TableauCard[I].Suit = Ref.Suit) and (G.TableauCard[I].Rank = Ref.Rank),
          'the tableau is still the first 28 cards (card ' + IntToStr(I) + ')');
      end;
      { the next 17 cards of the deck are the stock; the first of them is drawn last }
      for K := 0 to 16 do StockRef[K] := Probe.Draw;
      for K := 16 downto 0 do
      begin
        G.DrawStock;
        Check((G.WasteTop.Suit = StockRef[K].Suit) and (G.WasteTop.Rank = StockRef[K].Rank),
          'stock card ' + IntToStr(K) + ' is the deck card it should be');
      end;
    finally
      Probe.Free;
    end;
    Check(G.StockCount = 0, 'seventeen draws empty it');
    Check(not G.DrawStock, 'and then there is nothing to draw');

    { the waste card is still the last card of the deck, and leftovers are unused }
    D := KnownDeck;
    try
      G.Deal(D, 10);
    finally
      D.Free;
    end;
    Check((G.WasteTop.Suit = suSpades) and (G.WasteTop.Rank = 13), 'the waste card is the last card of the deck');
    Check(G.StockCount = 10, 'stock of ten');
    Draws := 0;
    while G.DrawStock do Inc(Draws);
    Check(Draws = 10, 'ten draws');

    { sizes are clamped }
    D := KnownDeck;
    try
      G.Deal(D, 99);
    finally
      D.Free;
    end;
    Check(G.StockCount = FullStock, 'too big a stock is the full stock');
    D := KnownDeck;
    try
      G.Deal(D, -4);
    finally
      D.Free;
    end;
    Check((G.StockCount = 0) and (G.StockSize = 0), 'a negative stock is none');
    D := KnownDeck;
    try
      G.Deal(D);
    finally
      D.Free;
    end;
    Check(G.StockCount = FullStock, 'no size given: the full stock');

    { the hand's rules travel with its saved state }
    G.WrapRanks := False;
    D := KnownDeck;
    try
      G.Deal(D, 17);
    finally
      D.Free;
    end;
    G.PlayTableau(27);
    G.DrawStock;
    G.GetState(A);
    Check((A.StockSize = 17) and not A.Wrap, 'the state records the stock size and the wrap');
    G2.WrapRanks := True;
    Check(G2.SetState(A), 'a smaller-stock hand loads');
    Check((G2.StockSize = 17) and not G2.WrapRanks and (G2.StockCount = G.StockCount),
      'and it brings its rules with it');
    Check(not G2.Adjacent(1, 13), 'so King and Ace are not neighbours there');

    { bad rules are refused }
    Bad := A; Bad.StockSize := 24;
    Check(not G2.SetState(Bad), 'a stock size above the full stock is refused');
    { claiming 24 with the card counts adjusted to match: only the size limit can refuse it }
    G.WrapRanks := True;
    D := KnownDeck;
    try
      G.Deal(D);
    finally
      D.Free;
    end;
    G.GetState(Bad);
    Bad.StockSize := FullStock + 1;
    Bad.WasteCount := Bad.WasteCount + 1;
    Check(not G2.SetState(Bad), 'a stock size of 24 is refused even when the counts agree');
    Bad := A; Bad.StockSize := -1;
    Check(not G2.SetState(Bad), 'a negative stock size is refused');
    Bad := A; Bad.StockSize := FullStock;
    Check(not G2.SetState(Bad), 'a stock size the card counts do not fit is refused');
    Bad := A; Bad.StockSize := Length(A.Stock) - 1;
    Check(not G2.SetState(Bad), 'a stock bigger than its own size is refused');
  finally
    G.Free; G2.Free;
  end;
end;

{ Whole random hands with the harder rules: every position stays a believable
  hand (it saves and loads), and the stock never exceeds its size. }
procedure TestHardRules;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, B: THandData;
  Game, I, Draws, Size: Integer;
  Wrap, Moved: Boolean;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    for Game := 1 to 60 do
    begin
      Wrap := Game mod 2 = 0;
      Size := 5 + (Game mod 19);
      G.WrapRanks := Wrap;
      D := TDeck.Create;
      try
        D.Shuffle;
        G.Deal(D, Size);
      finally
        D.Free;
      end;
      Draws := 0;
      repeat
        Moved := False;
        for I := 27 downto 0 do
          if G.PlayTableau(I) then begin Moved := True; Break; end;
        if not Moved then
        begin
          Moved := G.DrawStock;
          if Moved then Inc(Draws);
        end;
        if not G.IsWon then
        begin
          G.GetState(A);
          if not G2.SetState(A) then
            Check(False, 'game ' + IntToStr(Game) + ': a real hand did not reload')
          else
          begin
            G2.GetState(B);
            Check(StatesEqual(A, B), 'game ' + IntToStr(Game) + ': saved and loaded state agree');
            Check(G2.WrapRanks = Wrap, 'game ' + IntToStr(Game) + ': the wrap rule survives');
          end;
        end;
      until not Moved or G.IsWon;
      Check(Draws <= Size, 'game ' + IntToStr(Game) + ': never more draws than the stock');
    end;
  finally
    G.Free; G2.Free;
  end;
end;

{ Each way a saved history can be wrong is refused on its own (everything else
  in the state is left true). }
procedure TestBadHistories;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  I, K, Plays: Integer;
  A, Bad: THandData;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    repeat                                     { a shuffled deal where two cards can be played in a row }
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D);
      D.Free;
      Plays := 0;
      for I := 0 to 1 do
        for K := 27 downto 0 do
          if (Plays = I) and G.PlayTableau(K) then Inc(Plays);
    until Plays = 2;
    G.DrawStock;                               { history: play, play, draw }
    G.GetState(A);
    Check(Length(A.History) = 3, 'three moves in the history');
    Check(G2.SetState(A), 'the true history is accepted');
    Check(G2.UndoDepth = 3, 'and kept');
    Bad := A; Bad.History := Copy(A.History); Bad.History[0].Missed := True;
    Check(not G2.SetState(Bad), 'a play marked as a missed draw is refused');
    Bad := A; Bad.History := Copy(A.History); Bad.History[1].PrevStreak := 5;
    Check(not G2.SetState(Bad), 'a play that does not follow its streak is refused');
    Bad := A; Bad.Streak := 1;                 { only a counter changes }
    Check(not G2.SetState(Bad), 'a draw that did not end the streak is refused');
    Bad := A; Bad.History := Copy(A.History); Bad.History[0].Index := 99;
    Check(not G2.SetState(Bad), 'a play of a card that is not on the table is refused');
    Bad := A; Bad.History := Copy(A.History); Bad.History[1].Index := (Bad.History[1].Index + 1) mod TableauSize;
    Check(not G2.SetState(Bad), 'a play of some other card than the waste card is refused');
    Bad := A; Bad.History := Copy(A.History); Bad.History[0].PrevStreak := -1;
    Check(not G2.SetState(Bad), 'a negative streak is refused');
    Bad := A; Bad.History := Copy(A.History); SetLength(Bad.History, 2);
    Check(not G2.SetState(Bad), 'a history that does not reach the waste count is refused');
  finally
    G.Free; G2.Free;
  end;
end;

procedure TestStateRejectsBadHands;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, Bad: THandData;
  I, K: Integer;
  Before: THandData;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  D := TDeck.Create;
  try
    D.Shuffle;
    G.Deal(D);
    for K := 1 to 5 do
    begin
      for I := 27 downto 0 do
        if G.PlayTableau(I) then Break;
      if not G.HasMoves then G.DrawStock;
    end;
    G.GetState(A);
    Check(G2.SetState(A), 'the untouched state is fine');

    Bad := A; Bad.Tableau[3] := Bad.Tableau[4];
    Check(not G2.SetState(Bad), 'a duplicated card is refused');
    Bad := A; Bad.WasteCount := Bad.WasteCount + 1;
    Check(not G2.SetState(Bad), 'a wrong waste count is refused');
    Bad := A; Bad.Plays := Bad.Plays + 1;
    Check(not G2.SetState(Bad), 'plays that do not match the removed cards are refused');
    Bad := A; Bad.Streak := -1;
    Check(not G2.SetState(Bad), 'a negative streak is refused');
    Bad := A; Bad.BestStreak := Bad.Streak - 1;
    Check(not G2.SetState(Bad), 'a best streak below the streak is refused');
    Bad := A; SetLength(Bad.Stock, 30);
    Check(not G2.SetState(Bad), 'an oversized stock is refused');
    Bad := A; Bad.WasteTop := Bad.Tableau[0];
    if not Bad.Removed[0] then
      Check(not G2.SetState(Bad), 'a waste card that is still on the table is refused');

    { a card removed while still covered }
    Bad := A;
    for I := 0 to TableauSize - 1 do Bad.Removed[I] := False;
    Bad.Removed[0] := True; Bad.Plays := 1; Bad.WasteCount := 1 + 1 + (23 - Length(Bad.Stock));
    Bad.Streak := 0; Bad.BestStreak := 0;
    Check(not G2.SetState(Bad), 'a covered card cannot already be gone');

    { everything cleared is a finished hand, not a resumable one }
    Bad := A;
    for I := 0 to TableauSize - 1 do Bad.Removed[I] := True;
    Bad.Plays := 28; Bad.WasteCount := 1 + 28 + (23 - Length(Bad.Stock));
    Bad.Streak := 0; Bad.BestStreak := 28;
    Bad.History := nil;                      { nothing else wrong, so only the cleared check can refuse it }
    Check(not G2.SetState(Bad), 'a cleared hand is refused');

    { a bad undo record }
    Bad := A;
    SetLength(Bad.History, Length(Bad.History) + 1);
    Bad.History[High(Bad.History)].Draw := False;
    Bad.History[High(Bad.History)].Index := 99;
    Bad.History[High(Bad.History)].PrevWasteTop := Bad.WasteTop;
    Check(not G2.SetState(Bad), 'an undo of a card that does not exist is refused');
    Bad := A;
    SetLength(Bad.History, Length(Bad.History) + 1);
    with Bad.History[High(Bad.History)] do
    begin
      Draw := False;
      Index := 0;                              { not the card on the waste }
      PrevWasteTop := Bad.WasteTop;
      PrevStreak := 0;
    end;
    Check(not G2.SetState(Bad), 'an undo of a play that is not the waste card is refused');
    Bad := A;
    SetLength(Bad.History, Length(Bad.History) + 1);
    with Bad.History[High(Bad.History)] do
    begin
      Draw := True;
      Index := 0;
      PrevWasteTop := Bad.WasteTop;
      PrevStreak := 0;
    end;
    Bad.Stock := nil;
    SetLength(Bad.Stock, 23);                  { a stock already full: nowhere for the card to return to }
    Check(not G2.SetState(Bad), 'an undo of a draw into a full stock is refused');
    Bad := A;
    SetLength(Bad.History, 200);               { more moves than a hand has }
    Check(not G2.SetState(Bad), 'an absurdly long history is refused');

    { a refused state leaves the game untouched }
    G2.GetState(Before);
    Bad := A; Bad.Tableau[3] := Bad.Tableau[4];
    G2.SetState(Bad);
    G2.GetState(A);
    Check(StatesEqual(Before, A), 'a refused state changes nothing');
  finally
    G.Free; G2.Free; D.Free;
  end;
end;

begin
  Randomize;
  TestLayout;
  TestAdjacent;
  TestPlayRules;
  TestUncover;
  TestWin;
  TestStuck;
  TestUndo;
  TestUndoBlockedAfterWin;
  TestUndoWholeHand;
  TestUndoForgottenBySpecial;
  TestBittenCards;
  TestChainedCards;
  TestHunger;
  TestTrickStates;
  TestBadTrickStates;
  TestPick;
  TestSpoon;
  TestRelicStates;
  TestBadRelicStates;
  TestRandomGames;
  TestStateRoundTrip;
  TestStateRestoresBehaviour;
  TestStateRejectsBadHands;
  TestBadHistories;
  TestStockSize;
  TestHardRules;
  if Failures = 0 then WriteLn('ALL TESTS PASSED') else
  begin
    WriteLn(Failures, ' FAILURES');
    Halt(1);
  end;
end.
