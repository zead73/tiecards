program TestSession;

{$mode objfpc}{$H+}

uses SysUtils, DateUtils, Cards, TriPeaks, Inventory, Session, Specials, Sound{$IFDEF PAS2JS}, JsCompat{$ENDIF};

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

procedure TestHint;
var
  S: TGameSession;
  D: TDeck;
  I: Integer;
  R: array[0..27] of Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;                       { playable on waste 7 }
  S := TGameSession.Create('');
  D := BuildDeck(R, 3, 7);
  try
    S.NewGameFrom(D);
    Check(not S.IsHinted(27), 'nothing highlighted without a hint');
    Check(S.UseHint = hrNoHintCards, 'no hint cards -> refused');
    Check(not S.HintActive, 'still not showing');

    S.Inventory.AddHintCards(2);
    Check(S.UseHint = hrShown, 'hint shown');
    Check(S.Inventory.HintCards = 1, 'one hint card spent');
    Check(S.IsHinted(27), 'playable card highlighted');
    Check(not S.IsHinted(26), 'non-playable card not highlighted');
    Check(S.UseHint = hrAlreadyShown, 'second press while showing');
    Check(S.Inventory.HintCards = 1, 'no second charge while showing');

    Check(S.Play(27), 'play the hinted card');
    Check(not S.HintActive, 'hint cleared after a move');
    Check(not S.IsHinted(26), 'no highlight after the move');
  finally
    S.Free;
    D.Free;
  end;
end;

procedure TestHintNoMoves;
var
  S: TGameSession;
  D: TDeck;
  I: Integer;
  R: array[0..27] of Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  S := TGameSession.Create('');
  D := BuildDeck(R, 3, 1);          { waste A, bottom row all Qs: no moves }
  try
    S.NewGameFrom(D);
    S.Inventory.AddHintCards(3);
    Check(not S.Game.HasMoves, 'no moves in this deal');
    Check(S.UseHint = hrNoMoves, 'no moves -> hrNoMoves');
    Check(S.Inventory.HintCards = 2, 'hint card IS spent when there is no move');
    Check(not S.HintActive, 'nothing highlighted');
    Check(S.Game.StockCount = 23, 'board untouched: stock unchanged');
    Check(S.Game.Plays = 0, 'board untouched: no plays made');
    Check(not S.Game.CanUndo, 'no move was recorded');
    Check(S.UseHint = hrNoMoves, 'second press, still no moves');
    Check(S.Inventory.HintCards = 1, 'spent again');
    Check(S.UseHint = hrNoMoves, 'third press');
    Check(S.Inventory.HintCards = 0, 'out of hint cards');
    Check(S.UseHint = hrNoHintCards, 'no cards left: refused, no buzz result');
    Check(S.Inventory.HintCards = 0, 'never negative');
  finally
    S.Free;
    D.Free;
  end;
end;

procedure TestUndoGate;
var
  S: TGameSession;
  D: TDeck;
  I: Integer;
  R: array[0..27] of Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;
  S := TGameSession.Create('');
  D := BuildDeck(R, 3, 7);
  try
    S.NewGameFrom(D);
    Check(S.Play(27), 'play');
    Check(not S.UseUndo, 'undo refused without an undo card');
    Check(S.Game.Removed[27], 'move not undone');
    S.Inventory.AddUndoCards(1);
    Check(S.UseUndo, 'undo works with a card');
    Check(not S.Game.Removed[27], 'move undone');
    Check(S.Inventory.UndoCards = 0, 'card spent');
    Check(not S.UseUndo, 'nothing left to undo');
    S.Inventory.AddUndoCards(1);
    Check(not S.UseUndo, 'card kept when there is nothing to undo');
    Check(S.Inventory.UndoCards = 1, 'card not wasted');
  finally
    S.Free;
    D.Free;
  end;
end;

procedure TestWinReward;
var
  S: TGameSession;
  D: TDeck;
  I, C0: Integer;
  R: array[0..27] of Integer;
begin
  for I := 0 to 27 do
    if (27 - I) mod 2 = 0 then R[I] := 6 else R[I] := 7;
  S := TGameSession.Create('');
  D := BuildDeck(R, 1, 7);
  try
    S.NewGameFrom(D);
    C0 := S.Inventory.Coins;
    for I := 27 downto 0 do S.Play(I);
    Check(S.Game.IsWon, 'won');
    Check(S.Inventory.Coins = C0 + WinCoins, 'coins rewarded');
    Check(S.Inventory.UndoCards = WinUndoCards, 'undo card rewarded');
    Check(S.Inventory.HintCards = WinHintCards, 'hint cards rewarded');
    Check(S.Note <> '', 'win note set');
    Check(not S.UseUndo, 'cannot undo after the win (no reward farming)');
    Check(S.Inventory.Coins = C0 + WinCoins, 'reward paid once');
  finally
    S.Free;
    D.Free;
  end;
end;

procedure TestShop;
var
  S: TGameSession;
  C: Integer;
begin
  S := TGameSession.Create('');
  try
    C := S.Inventory.Coins;
    Check(S.BuyHintPack, 'buy hint pack');
    Check(S.Inventory.Coins = C - HintPackCost, 'hint pack price');
    Check(S.Inventory.HintCards = HintPackSize, 'hint pack size');
    while S.BuyHintPack do ;
    Check(S.Inventory.Coins < HintPackCost, 'ran out of coins');
    C := S.Inventory.Coins;
    Check(not S.BuyHintPack, 'cannot afford');
    Check(not S.BuyUndoPack or (C >= UndoPackCost), 'consistent affordability');
  finally
    S.Free;
  end;
end;

{ Cards can only be bought between hands. }
procedure TestShopRule;
var
  S, S2: TGameSession;
  D: TDeck;
  I, C: Integer;
  R, W: array[0..27] of Integer;
  H: TSavedHand;
  Tries: Integer;
  Stuck, Moved: Boolean;

  procedure Deal(ASession: TGameSession; const Tab: array of Integer;
    StockRank, WasteRank: Integer);
  begin
    D := BuildDeck(Tab, StockRank, WasteRank);
    try
      ASession.NewGameFrom(D);
    finally
      D.Free;
    end;
  end;

begin
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;                                   { one playable card, on a waste 7 }
  for I := 0 to 27 do
    if (27 - I) mod 2 = 0 then W[I] := 6 else W[I] := 7;

  S := TGameSession.Create('');
  try
    Deal(S, R, 3, 7);
    Check(S.CanShop, 'a fresh deal: the shop is open');
    C := S.Inventory.Coins;
    Check(S.BuyUndoPack, 'a pack can be bought before the first move');
    Check(S.Inventory.Coins = C - UndoPackCost, 'and it costs its price');

    S.Inventory.AddCoins(200);                  { so only the rule can refuse a purchase }
    Check(S.Play(27), 'play a card');
    Check(not S.CanShop, 'mid-hand: the shop is shut');
    C := S.Inventory.Coins;
    Check(not S.BuyUndoPack, 'no undo pack mid-hand');
    Check(not S.BuyHintPack, 'no hint pack mid-hand');
    Check(S.Inventory.Coins = C, 'a refused purchase costs nothing');
    Check(S.Inventory.HintCards = 0, 'and gives nothing');

    Check(S.UseUndo, 'undo the only move');
    Check(not S.CanShop, 'back at the start by undo: still shut (a card was played)');
    Check(not S.BuyHintPack, 'still no packs');

    { a new deal opens it again }
    Deal(S, R, 3, 7);
    Check(S.CanShop, 'the next deal opens the shop again');

    { a draw also starts the hand }
    S.DrawStock;
    Check(not S.CanShop, 'drawing from the stock starts the hand');

    { the hand is over once the duel (or a New Game) gives it up }
    S.EndHand;
    Check(S.CanShop, 'a hand that has ended: open');
    Check(not S.CanUseUndo, 'and it can no longer be undone');
  finally
    S.Free;
  end;

  { winning opens it }
  S := TGameSession.Create('');
  try
    Deal(S, W, 1, 7);
    for I := 27 downto 0 do S.Play(I);
    Check(S.Game.IsWon, 'won');
    Check(S.CanShop, 'a won hand: open');
    C := S.Inventory.Coins;
    Check(S.BuyHintPack and (S.Inventory.Coins = C - HintPackCost), 'and a pack can be bought');
  finally
    S.Free;
  end;

  { stuck with no undo card: the hand is over and a pack cannot rescue it }
  S := TGameSession.Create('');
  try
    Deal(S, R, 3, 1);                          { waste A, bottom row of Qs: nothing to play }
    Check(not S.Game.HasMoves, 'no moves in this deal');
    for I := 1 to 23 do S.DrawStock;
    Check(S.Game.IsStuck, 'stuck: stock empty, nothing playable');
    Check(S.CanShop, 'stuck with no undo card: the hand is over, shop open');
    Check(S.BuyUndoPack, 'buy a pack');
    Check(S.Inventory.UndoCards = UndoPackSize, 'the cards arrived');
    Check(not S.CanUseUndo, 'but they cannot rescue the finished hand');
    Check(not S.UseUndo, 'undo refused');
    Check(S.Inventory.UndoCards = UndoPackSize, 'and no card is wasted');
  finally
    S.Free;
  end;

  { stuck WITH an undo card: still the middle of the hand }
  S := TGameSession.Create('');
  try
    Deal(S, R, 3, 1);
    S.Inventory.AddUndoCards(1);
    for I := 1 to 23 do S.DrawStock;
    Check(S.Game.IsStuck, 'stuck');
    Check(S.CanUseUndo, 'an undo card is available');
    Check(not S.CanShop, 'so it is not over: the shop stays shut');
    Check(not S.BuyHintPack, 'no packs');
    Check(S.UseUndo, 'use the undo card');
    Check(not S.Game.IsStuck, 'no longer stuck');
    Check(not S.CanShop, 'still mid-hand');
    for I := 1 to 1 do S.DrawStock;
    Check(S.Game.IsStuck and not S.CanUseUndo, 'stuck again with no card');
    Check(S.CanShop, 'now the hand is over');
  finally
    S.Free;
  end;

  { a saved hand keeps its state when it is loaded back (real deals: the
    loader rejects rigged ones) }
  S := TGameSession.Create('');
  S2 := TGameSession.Create('');
  try
    RandSeed := 12345;
    S.NewGame;
    S.ExportHand(H);
    Check(S2.ImportHand(H), 'import a fresh hand');
    Check(S2.CanShop, 'a fresh hand comes back with the shop open');
    for I := 0 to 27 do if S.Play(I) then Break;
    if S.Game.Plays = 0 then S.DrawStock;
    S.ExportHand(H);
    Check(S2.ImportHand(H), 'import a hand in progress');
    Check(S2.CanShop, 'a hand in progress comes back with the shop open: a restored hand is a fresh start');
    Check(S2.HandStarted, 'though it still counts as a hand under way (for the records)');
    S2.Inventory.AddCoins(200);
    Check(S2.BuyHintPack, 'and a pack can be bought at the start of it');
    for I := 27 downto 0 do if S2.Play(I) then Break;
    if S2.Game.Plays = S.Game.Plays then S2.DrawStock;
    Check(not S2.CanShop, 'but the first move after it comes back shuts the shop again');
    Check(S2.ImportHand(H) and S2.CanShop, 'a hand put back again reopens it');
    S2.Inventory.AddUndoCards(1);
    if S2.CanUseUndo then
    begin
      S2.UseUndo;
      Check(not S2.CanShop, 'taking back a move shuts it too');
    end;
    Check(S2.ImportHand(H) and S2.CanShop, 'again reopened');
    S2.Inventory.AddSpecial(skSeer, 1);
    if S2.UseSpecial(skSeer) then Check(not S2.CanShop, 'and so does using a special card');
    S2.NewGame;
    Check(S2.CanShop, 'a fresh deal is open');
    Check(S2.ImportHand(H), 'restore once more');
    { play deals out greedily until one ends stuck }
    S.PayWinRewards := False;                 { winning deals must not hand out undo cards }
    Stuck := False;
    for Tries := 1 to 200 do
    begin
      S.NewGame;
      repeat
        Moved := False;
        for I := 27 downto 0 do if S.Play(I) then begin Moved := True; Break; end;
        if not Moved then Moved := S.DrawStock;
      until not Moved;
      if S.Game.IsStuck then begin Stuck := True; Break; end;
    end;
    Check(Stuck, 'found a hand that ends stuck (test set-up)');
    if Stuck then
    begin
      Check(S.CanShop, 'the stuck hand is over');
      S.ExportHand(H);
      Check(S2.ImportHand(H), 'import a finished hand');
      Check(S2.CanShop, 'a finished (stuck) hand comes back with the shop open');
      Check(not S2.CanUseUndo, 'and still cannot be rescued');
    end;
  finally
    S.Free; S2.Free;
  end;
end;

{ The rules (wrap, stock size) apply to hands dealt after SetRules. }
procedure TestRules;
var
  S, S2: TGameSession;
  D: TDeck;
  H: TSavedHand;
  R: array[0..27] of Integer;
  I: Integer;
begin
  S := TGameSession.Create('');
  S2 := TGameSession.Create('');
  try
    Check((S.StockSize = FullStock) and S.WrapRanks, 'a new session has the ordinary rules');
    S.NewGame;
    Check((S.Game.StockCount = FullStock) and S.Game.Adjacent(1, 13), 'and so does its first hand');

    S.SetRules(False, 17);
    Check((S.StockSize = 17) and not S.WrapRanks, 'the rules can be changed');
    Check((S.Game.StockCount = FullStock) and S.Game.WrapRanks, 'but the hand already dealt keeps its own');
    S.NewGame;
    Check(S.Game.StockCount = 17, 'the next shuffled hand has the smaller stock');
    Check(not S.Game.Adjacent(1, 13), 'and no wrap');
    Check(S.Game.StockSize = 17, 'and knows its size');

    for I := 0 to 27 do R[I] := 12;
    D := BuildDeck(R, 3, 1);
    try
      S.NewGameFrom(D);
    finally
      D.Free;
    end;
    Check(S.Game.StockCount = 17, 'a rigged deal gets the rules too');

    { a loaded hand brings its own rules; the next deal uses the session's }
    S.SetRules(True, FullStock);
    S.NewGame;
    S.ExportHand(H);
    S2.SetRules(False, 12);
    Check(S2.ImportHand(H), 'load a full-stock hand into a session set for 12');
    Check((S2.Game.StockSize = FullStock) and S2.Game.WrapRanks, 'it keeps the rules it was dealt with');
    S2.NewGame;
    Check((S2.Game.StockSize = 12) and not S2.Game.WrapRanks, 'the next deal uses the session rules');
  finally
    S.Free; S2.Free;
  end;
end;

procedure TestPersistence;
var
  F: string;
  S: TGameSession;
begin
  F := GetTempDir + 'tiecards_test_session.ini';
  if FileExists(F) then DeleteFile(F);
  S := TGameSession.Create(F);
  try
    S.BuyHintPack;
    S.BuyUndoPack;
  finally
    S.Free;
  end;
  S := TGameSession.Create(F);
  try
    Check(S.Inventory.HintCards = HintPackSize, 'hint cards persisted');
    Check(S.Inventory.UndoCards = UndoPackSize, 'undo cards persisted');
    Check(S.Inventory.Coins = StartingCoins - HintPackCost - UndoPackCost,
      'coins persisted');
  finally
    S.Free;
  end;
  DeleteFile(F);
end;

procedure TestWav;
var
  W: string;
  DataLen: LongWord;
begin
  W := MakeNoWav;
  Check(Copy(W, 1, 4) = 'RIFF', 'wav RIFF header');
  Check(Copy(W, 9, 4) = 'WAVE', 'wav WAVE tag');
  Check(Copy(W, 37, 4) = 'data', 'wav data chunk');
  DataLen := Ord(W[41]) or (Ord(W[42]) shl 8) or (Ord(W[43]) shl 16) or (LongWord(Ord(W[44])) shl 24);
  Check(Length(W) = 44 + Integer(DataLen), 'wav length matches header');
  Check(DataLen > 1000, 'wav has audio data');
end;

procedure TestWinWav;
var
  W: string;
  DataLen: LongWord;
  N, I, Peak, V: Integer;
  T0: TDateTime;
  Ms: Int64;

  function Sample(K: Integer): Integer;
  begin
    Result := SmallInt(Word(Ord(W[45 + 2 * K])) or (Word(Ord(W[46 + 2 * K])) shl 8));
  end;

begin
  T0 := Now;
  W := MakeWinWav;
  Ms := MilliSecondsBetween(Now, T0);
  Check(Ms < 1500, 'win jingle builds quickly (took ' + IntToStr(Ms) + ' ms)');
  Check(Copy(W, 1, 4) = 'RIFF', 'win wav RIFF header');
  Check(Copy(W, 9, 4) = 'WAVE', 'win wav WAVE tag');
  Check(Copy(W, 37, 4) = 'data', 'win wav data chunk');
  DataLen := Ord(W[41]) or (Ord(W[42]) shl 8) or (Ord(W[43]) shl 16) or (LongWord(Ord(W[44])) shl 24);
  Check(Length(W) = 44 + Integer(DataLen), 'win wav length matches header');
  N := Integer(DataLen) div 2;
  Check((N > 22050 * 3) and (N < 22050 * 5), 'win jingle is 3-5 seconds');
  Peak := 0;
  for I := 0 to N - 1 do
  begin
    V := Abs(Sample(I));
    if V > Peak then Peak := V;
  end;
  Check(Peak > 20000, 'win jingle is loud enough (peak ' + IntToStr(Peak) + ')');
  Check(Peak < 30000, 'win jingle does not clip (peak ' + IntToStr(Peak) + ')');
  Check(Abs(Sample(0)) < 500, 'starts near silence (no click)');
  Check(Abs(Sample(N - 1)) < 500, 'ends near silence (no click)');
end;

procedure TestUndoMany;
var
  S: TGameSession;
  D: TDeck;
  I: Integer;
  R: array[0..27] of Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;                               { playable on the waste 7, and stays so after every draw }
  S := TGameSession.Create('');
  D := BuildDeck(R, 7, 7);
  try
    S.NewGameFrom(D);
    Check(S.DrawStock and S.DrawStock and S.DrawStock, 'three draws');
    Check(S.Misses = 3, 'three misses');
    Check(S.Play(27), 'then the 6 is played');
    S.Inventory.AddUndoCards(3);
    Check(S.UseUndo and (S.Inventory.UndoCards = 2), 'one undo card takes back the play');
    Check(S.Game.UndoDepth = 3, 'three draws are still there to take back');
    Check(S.UseUndo and S.UseUndo, 'and two more cards take back two draws');
    Check((S.Inventory.UndoCards = 0) and (S.Misses = 1), 'each draw refunded its own miss, once');
    Check(not S.UseUndo and (S.Game.UndoDepth = 1), 'out of cards: the first draw stays');
    S.Inventory.AddUndoCards(5);
    Check(S.UseUndo and not S.UseUndo, 'one more card undoes the last move; the deal itself cannot be undone');
    Check((S.Misses = 0) and (S.Inventory.UndoCards = 4), 'all misses refunded, and the unused cards are kept');
    { and new moves start a new history }
    Check(S.DrawStock and S.Play(27), 'two moves');
    Check(S.Game.UndoDepth = 2, 'two to undo');
  finally
    S.Free;
    D.Free;
  end;
end;

procedure TestBites;
var
  S: TGameSession;
  D: TDeck;
  H: TSavedHand;
  I: Integer;
  R: array[0..27] of Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;
  R[26] := 7;
  S := TGameSession.Create('');
  D := BuildDeck(R, 3, 7);
  try
    S.SetRules(True, FullStock, hzBitten);
    S.NewGameFrom(D);
    Check(S.Hazard = hzBitten, 'the session deals the trick it was told to');
    Check(S.Game.Hazard = hzBitten, 'and the hand has it');
    for I := 0 to 27 do S.Game.SetMark(I, MarkNone);
    S.Game.SetMark(26, MarkBitten);                 { just the 7 }
    Check(S.Play(27) and (S.Bites = 0), 'an ordinary card costs nothing');
    Check(S.PayoutNow = WinCoins, 'so the reward is whole');
    Check(S.Play(26), 'a bitten card can be played');
    Check(S.Bites = 1, 'and is counted');
    Check(Pos('Bitten', S.Note) > 0, 'with a note: ' + S.Note);
    Check(S.PayoutNow = WinCoins - BitePenaltyCoins, 'the reward is cut by the bite');
    Check(S.Misses = 0, 'which is not a missed move');
    S.Inventory.AddUndoCards(1);
    Check(S.UseUndo and (S.Bites = 0), 'undoing the play takes the bite back');
    Check(S.PayoutNow = WinCoins, 'and the reward is whole again');
    Check(S.Play(26) and (S.Bites = 1), 'bitten again');
    { the bites are part of a saved hand (a real deal: a rigged one would not reload) }
    S.NewGame;
    S.ExportHand(H);
    H.Bites := 2;
    S.NewGame;
    Check(S.Bites = 0, 'a new deal starts clean');
    Check(S.ImportHand(H) and (S.Bites = 2), 'a loaded hand brings its bites back');
    S.ExportHand(H);
    Check(H.Bites = 2, 'and saves them again');
    H.Bites := -1;
    Check(not S.ImportHand(H), 'a negative count is refused');
    { Free Play has no trick }
    S.SetRules(True, FullStock);
    S.NewGame;
    Check((S.Hazard = hzNone) and (S.Game.Hazard = hzNone), 'Free Play hands have no trick');
    { and tests can switch them off }
    S.SetRules(True, FullStock, hzChained);
    S.HazardsOn := False;
    S.NewGame;
    Check(S.Game.Hazard = hzNone, 'HazardsOn = False deals plain hands');
  finally
    S.Free;
  end;
end;

procedure TestFeeding;
var
  S: TGameSession;
  I: Integer;
begin
  S := TGameSession.Create('');
  try
    S.SetRules(False, FullStock, hzHunger);
    S.NewGame;
    for I := 1 to 3 do S.DrawStock;
    Check(Pos('feeds', S.Note) = 0, 'no feast before the fourth draw');
    S.DrawStock;
    Check(Pos('feeds', S.Note) > 0, 'the fourth is followed by a note: ' + S.Note);
    Check(S.Game.SpareCount = 1, 'and a card is gone from the stock');
    Check(S.Inventory.SpecialCards(skFullDeck) = 0, 'a Full deck gives it back:');
    S.Inventory.AddSpecial(skFullDeck, 1);
    Check(S.CanUseSpecial(skFullDeck), 'it can be used');
    S.UseSpecial(skFullDeck);
    Check(S.Game.SpareCount = 0, 'and the eaten card is back in the stock');
  finally
    S.Free;
  end;
end;

procedure TestMisses;
var
  S: TGameSession;
  D: TDeck;
  I: Integer;
  R: array[0..27] of Integer;
  Coins0: Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;                               { playable on the waste 7 }
  S := TGameSession.Create('');
  D := BuildDeck(R, 7, 7);                  { a stock of 7s: the 6 stays playable after every draw }
  try
    S.NewGameFrom(D);
    Check(S.Misses = 0, 'no misses at the start');
    Check(S.PayoutNow = WinCoins, 'full reward at the start');
    Check(S.DrawStock, 'draw while a move exists');
    Check(S.MissedLast, 'that was a missed move');
    Check(S.Misses = 1, 'counted');
    Check(S.PayoutNow = WinCoins - MissPenaltyCoins, 'the reward shrinks by the penalty');
    { undo takes the miss back }
    S.Inventory.AddUndoCards(2);
    Check(S.UseUndo, 'undo the draw');
    Check(S.Misses = 0, 'undoing the draw takes the miss back');
    Check(not S.MissedLast, 'and it is no longer "the last draw"');
    Check(S.PayoutNow = WinCoins, 'reward restored');
    Check(not S.UseUndo, 'nothing left to undo, so the penalty cannot be refunded twice');
    Check(S.Misses = 0, 'misses never go negative');
    { drawing again after the undo is a miss again, since the 6 is still playable }
    Check(S.DrawStock and S.MissedLast and (S.Misses = 1), 'drawing again with the 6 still there misses again');
    { a hint does not excuse it }
    S.Inventory.AddHintCards(1);
    Check(S.UseHint = hrShown, 'show the move');
    Check(S.DrawStock and (S.Misses = 2), 'drawing even with the move shown is a miss');
    { play the card: not a miss; waste is now 3 so card 27 (6) is no longer playable anyway }
    Check(S.Misses = 2, 'misses stay for the hand');
    S.NewGameFrom(BuildDeck(R, 7, 7));
    Check(S.Misses = 0, 'a new hand starts clean');
    Check(not S.MissedLast, 'with nothing flagged');
  finally
    S.Free;
  end;

  { a draw when nothing is playable is never a miss }
  for I := 0 to 27 do R[I] := 12;
  S := TGameSession.Create('');
  try
    S.NewGameFrom(BuildDeck(R, 3, 1));        { waste A, all queens: no moves }
    Check(not S.Game.HasMoves, 'no moves in this deal');
    Check(S.DrawStock, 'draw');
    Check(not S.MissedLast, 'drawing with nothing playable is fine');
    Check(S.Misses = 0, 'not counted');
  finally
    S.Free;
  end;

  { playing a card is never a miss, and clears the flag }
  for I := 0 to 27 do R[I] := 12;
  R[27] := 6;
  S := TGameSession.Create('');
  try
    S.NewGameFrom(BuildDeck(R, 3, 7));
    Check(S.Play(27), 'play the card');
    Check((S.Misses = 0) and not S.MissedLast, 'playing is not a miss');
    Check(S.PayoutNow = WinCoins, 'full reward');
  finally
    S.Free;
  end;

  { winning pays the reduced reward in Free Play, down to the floor }
  for I := 0 to 27 do
    if (27 - I) mod 2 = 0 then R[I] := 6 else R[I] := 7;
  S := TGameSession.Create('');
  try
    S.NewGameFrom(BuildDeck(R, 7, 7));        { stock of 7s: every draw is a miss until the board is cleared }
    Coins0 := S.Inventory.Coins;
    S.DrawStock; S.DrawStock; S.DrawStock;     { three misses: waste stays 7... draws 7s }
    Check(S.Misses = 3, 'three misses');
    for I := 27 downto 0 do S.Play(I);
    Check(S.Game.IsWon, 'won');
    Check(S.Inventory.Coins = Coins0 + WinCoins - 3 * MissPenaltyCoins, 'the win paid the reduced reward');
    Check(Pos(IntToStr(WinCoins - 3 * MissPenaltyCoins), S.Note) > 0, 'and the message says what it paid: ' + S.Note);
  finally
    S.Free;
  end;
  S := TGameSession.Create('');
  try
    S.NewGameFrom(BuildDeck(R, 7, 7));
    Coins0 := S.Inventory.Coins;
    for I := 1 to 20 do S.DrawStock;           { 20 misses: far past the floor }
    for I := 27 downto 0 do S.Play(I);
    Check(S.Inventory.Coins = Coins0 + RewardFloorCoins, 'a hundred misses still pay the floor, never nothing');
  finally
    S.Free;
  end;
end;

begin
  TestHint;
  TestHintNoMoves;
  TestUndoGate;
  TestWinReward;
  TestShop;
  TestShopRule;
  TestRules;
  TestPersistence;
  TestWav;
  TestWinWav;
  TestMisses;
  TestBites;
  TestFeeding;
  TestUndoMany;
  if Failures = 0 then WriteLn('ALL SESSION TESTS PASSED') else
  begin
    WriteLn(Failures, ' FAILURES');
    Halt(1);
  end;
end.
