program TestSpecials;

{ The special cards: their prices and inventory, what each does to a hand, that
  every hand stays a believable (saveable, loadable) hand however they are
  mixed with plays, draws and undos, the rescue rule, and their use in duels. }

{$mode objfpc}{$H+}

uses SysUtils, Classes, Cards, TriPeaks, Inventory, Session, Specials, HandFile,
  Settings, Campaign, Duel, DuelSession
  {$IFDEF PAS2JS}, JsCompat{$ENDIF};

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

{ A rigged deal (not a real 52-card deck: for tests that never save). }
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

{ 52 different cards in a known order. }
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

procedure DealFrom(S: TGameSession; D: TDeck);
begin
  S.NewGameFrom(D);
  D.Free;
end;

function StatesEqual(const A, B: THandData): Boolean;
var
  I: Integer;

  function CardsEq(const X, Y: TCard): Boolean;
  begin
    Result := (X.Suit = Y.Suit) and (X.Rank = Y.Rank);
  end;

begin
  Result := (A.HandId = B.HandId) and (A.StockSize = B.StockSize) and (A.Wrap = B.Wrap)
    and (A.Revealed = B.Revealed) and (A.Stakes = B.Stakes)
    and (Length(A.Spare) = Length(B.Spare)) and (A.WasteCount = B.WasteCount)
    and (A.Streak = B.Streak) and (A.BestStreak = B.BestStreak) and (A.Plays = B.Plays)
    and (Length(A.Stock) = Length(B.Stock)) and CardsEq(A.WasteTop, B.WasteTop)
    and (Length(A.History) = Length(B.History));
  if not Result then Exit;
  for I := 0 to TableauSize - 1 do
    if not CardsEq(A.Tableau[I], B.Tableau[I]) or (A.Removed[I] <> B.Removed[I]) then
      Result := False;
  for I := 0 to High(A.Stock) do
    if not CardsEq(A.Stock[I], B.Stock[I]) then Result := False;
  for I := 0 to High(A.Spare) do
    if not CardsEq(A.Spare[I], B.Spare[I]) then Result := False;
end;

{ ---- the table of cards and the inventory ---- }

procedure TestTable;
var
  K, J: TSpecialKind;
begin
  for K := Low(TSpecialKind) to High(TSpecialKind) do
  begin
    Check(SpecialPrice[K] > 0, SpecialName[K] + ' has a price');
    Check((SpecialName[K] <> '') and (SpecialInfo[K] <> '') and (SpecialKey[K] <> ''), SpecialName[K] + ' has its words');
    for J := Low(TSpecialKind) to High(TSpecialKind) do
      if J <> K then Check(SpecialKey[J] <> SpecialKey[K], 'keys are distinct');
    Check(NeedsTarget(K) = (K in [skWild, skStake]), SpecialName[K] + ': only Wild and Stake need a target');
  end;
  Check(SpecialPrice[skDawn] > SpecialPrice[skFullDeck], 'Dawn costs more than half of it');
  Check(SpecialPrice[skDawn] > SpecialPrice[skOpenWrap], 'and the other half');
end;

procedure TestInventory;
var
  Inv, Inv2: TPlayerInventory;
  F: string;
  K: TSpecialKind;
  C: Integer;
begin
  Inv := TPlayerInventory.Create;
  Inv2 := TPlayerInventory.Create;
  F := GetTempDir + 'tiecards_test_specialinv.ini';
  if FileExists(F) then DeleteFile(F);
  try
    for K := Low(TSpecialKind) to High(TSpecialKind) do
      Check(Inv.SpecialCards(K) = 0, 'a new player has no ' + SpecialName[K]);
    Check(Inv.TotalSpecialCards = 0, 'and none in total');
    C := Inv.Coins;
    Check(Inv.BuySpecial(skWild), 'buy a Wild card');
    Check((Inv.Coins = C - SpecialPrice[skWild]) and (Inv.SpecialCards(skWild) = 1), 'it costs its price and arrives');
    Check(Inv.UseSpecialCard(skWild) and (Inv.SpecialCards(skWild) = 0), 'using spends it');
    Check(not Inv.UseSpecialCard(skWild), 'none left to use');
    Check(Inv.SpecialCards(skWild) = 0, 'and never negative');
    while Inv.CanBuySpecial(skDawn) do Inv.BuySpecial(skDawn);
    C := Inv.Coins;
    Check(not Inv.BuySpecial(skDawn) and (Inv.Coins = C), 'too poor: refused, nothing taken');
    Inv.AddSpecial(skSeer, 2);
    Inv.AddSpecial(skSeer, -5);
    Check(Inv.SpecialCards(skSeer) = 2, 'adding a negative number does nothing');
    Check(Inv.TotalSpecialCards = Inv.SpecialCards(skDawn) + 2, 'the total adds up');

    Inv.SaveToFile(F);
    Inv2.LoadFromFile(F);
    for K := Low(TSpecialKind) to High(TSpecialKind) do
      Check(Inv2.SpecialCards(K) = Inv.SpecialCards(K), SpecialName[K] + ' survives save and load');
    Inv.Reset;
    Check(Inv.TotalSpecialCards = 0, 'resetting clears them');
    { an old file with no special-card lines loads with none; a damaged one is made safe }
    DeleteFile(F);
    with TStringList.Create do
    try
      Text := '[Inventory]'#10'Coins=40'#10'UndoCards=1'#10'HintCards=2'#10'Special.wild=-4'#10;
      SaveToFile(F);
    finally
      Free;
    end;
    Inv2.LoadFromFile(F);
    Check((Inv2.Coins = 40) and (Inv2.TotalSpecialCards = 0), 'an old or damaged file gives none');
  finally
    Inv.Free; Inv2.Free;
    DeleteFile(F);
  end;
end;

{ ---- what each card does to the cards ---- }

procedure TestSpareAndRestore;
var
  G: TTriPeaksGame;
  D: TDeck;
  Top: TCard;
begin
  G := TTriPeaksGame.Create;
  try
    D := KnownDeck;
    G.Deal(D, 17);
    D.Free;
    Check(G.SpareCount = FullStock - 17, 'the cards the stock did not take are kept (6)');
    Check(G.CanRestoreStock, 'so a Full deck could restore them');
    G.DrawStock;
    Top := G.WasteTop;
    D := KnownDeck;
    G.Deal(D, 17);
    D.Free;
    Top := G.WasteTop;
    Check(G.RestoreStock, 'restore the stock');
    Check((G.StockCount = FullStock) and (G.StockSize = FullStock) and (G.SpareCount = 0),
      'a full stock, no spares');
    Check(not G.CanRestoreStock and not G.RestoreStock, 'nothing left to restore');
    Check((G.WasteTop.Suit = Top.Suit) and (G.WasteTop.Rank = Top.Rank), 'the waste is untouched');

    { the next draw is the card that was on top before (the extras go underneath) }
    D := KnownDeck;
    G.Deal(D, 17);
    D.Free;
    G.RestoreStock;
    G.DrawStock;
    Check((G.WasteTop.Suit = suSpades) and (G.WasteTop.Rank = 6), 'the next draw is unchanged by the restore');   { deck card 28 + 16 = 44: spades 6 }

    { a full deal has nothing spare }
    D := KnownDeck;
    G.Deal(D);
    D.Free;
    Check((G.SpareCount = 0) and not G.CanRestoreStock, 'an ordinary deal has no spare cards');
    { restoring cannot be taken back with undo }
    D := KnownDeck;
    G.Deal(D, 17);
    D.Free;
    G.DrawStock;
    Check(G.CanUndo, 'a draw can be undone');
    G.RestoreStock;
    Check(not G.CanUndo, 'but not across a Full deck');
  finally
    G.Free;
  end;
end;

procedure TestWrapAndReveal;
var
  G: TTriPeaksGame;
  D: TDeck;
begin
  G := TTriPeaksGame.Create;
  try
    D := KnownDeck;
    G.WrapRanks := False;
    G.Deal(D);
    D.Free;
    Check(G.CanOpenWrap and not G.Adjacent(1, 13), 'no wrap: Open wrap would help');
    G.DrawStock;
    Check(G.OpenWrap and G.Adjacent(1, 13), 'King and Ace are neighbours after it');
    Check(not G.CanOpenWrap and not G.OpenWrap, 'already open');
    Check(not G.CanUndo, 'forgets the undo');
    { already wrapping: nothing to do }
    D := KnownDeck;
    G.Deal(D);
    D.Free;
    Check(not G.CanOpenWrap, 'a wrapping hand has nothing to open');

    Check(G.CanReveal and not G.Revealed, 'face-down cards can be revealed');
    Check(G.Reveal and G.Revealed, 'reveal them');
    Check(not G.CanReveal and not G.Reveal, 'and only once');
  finally
    G.Free;
  end;
end;

procedure TestWildAndStake;
var
  G: TTriPeaksGame;
  D: TDeck;
  Waste: TCard;
  I, Free: Integer;
  Plays, Streak, Count, Rem: Integer;
begin
  G := TTriPeaksGame.Create;
  try
    D := KnownDeck;
    G.Deal(D);
    D.Free;
    Free := -1;
    for I := 27 downto 18 do
      if not G.CanPlay(I) then
      begin
        Free := I;                                   { a free card that does not fit the waste }
        Break;
      end;
    Check(Free >= 0, 'test set-up: a free card that cannot be played normally');
    G.DrawStock;                                     { something to undo }
    Check(G.CanUndo, 'test set-up: undo available');
    Plays := G.Plays; Streak := G.Streak; Count := G.WasteCount; Rem := G.Remaining;
    Check(not G.PlayWild(0), 'a covered card cannot be the target of a Wild card');
    Check(G.Remaining = Rem, 'and nothing happened');
    Check(G.PlayWild(Free), 'a Wild card plays a free card whatever its rank');
    Check(G.Removed[Free] and (G.Remaining = Rem - 1), 'the card is gone');
    Check((G.WasteTop.Suit = G.TableauCard[Free].Suit) and (G.WasteTop.Rank = G.TableauCard[Free].Rank),
      'and it is the new waste card');
    Check((G.Plays = Plays + 1) and (G.Streak = Streak + 1) and (G.WasteCount = Count + 1), 'counted as a play');
    Check(not G.CanUndo, 'forgets the undo');
    Check(not G.PlayWild(Free), 'a card that is gone is not a target');

    { the Wood Stake: removed, but the waste and the streak stay }
    D := KnownDeck;
    G.Deal(D);
    D.Free;
    G.DrawStock;
    Waste := G.WasteTop;
    Plays := G.Plays; Streak := G.Streak; Count := G.WasteCount; Rem := G.Remaining;
    Check(not G.Stake(0), 'a covered card cannot be staked');
    Check(G.Stake(20), 'stake a free card');
    Check(G.Removed[20] and (G.Remaining = Rem - 1), 'it is destroyed');
    Check((G.WasteTop.Suit = Waste.Suit) and (G.WasteTop.Rank = Waste.Rank), 'the waste is unchanged');
    Check((G.Plays = Plays) and (G.Streak = Streak) and (G.WasteCount = Count), 'no play, no streak');
    Check(G.Stakes = 1, 'one stake counted');
    Check(not G.CanUndo, 'forgets the undo');
    { it uncovers what was under it }
    Check(G.CanStake(20) = False, 'the same card cannot be staked twice');
    { staking away the whole board wins }
    D := KnownDeck;
    G.Deal(D);
    D.Free;
    repeat
      Free := -1;
      for I := 0 to TableauSize - 1 do
        if G.CanStake(I) then Free := I;
      if Free >= 0 then G.Stake(Free);
    until Free < 0;
    Check(G.IsWon and (G.Stakes = TableauSize), 'staking every card clears the board');
    Check(not G.HasFreeCard and not G.CanReveal, 'nothing left to do afterwards');
  finally
    G.Free;
  end;
end;

procedure TestStateRules;
var
  G, G2: TTriPeaksGame;
  D: TDeck;
  A, Bad: THandData;
begin
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  try
    D := KnownDeck;
    G.Deal(D, 17);
    D.Free;
    G.Stake(27);
    G.Reveal;
    G.GetState(A);
    Check((A.Stakes = 1) and A.Revealed and (Length(A.Spare) = 6), 'the state records stakes, reveal and spare');
    Check(G2.SetState(A), 'a hand with a stake, a reveal and spares loads');
    Check((G2.Stakes = 1) and G2.Revealed and (G2.SpareCount = 6), 'with all of it');
    Bad := A; Bad.Stakes := 0;
    Check(not G2.SetState(Bad), 'a removed card that no play or stake explains is refused');
    Bad := A; Bad.Stakes := 2;
    Check(not G2.SetState(Bad), 'more stakes than removed cards is refused');
    Bad := A; Bad.Stakes := -1;
    Check(not G2.SetState(Bad), 'negative stakes are refused');
    Bad := A; Bad.Spare[0] := Bad.Tableau[0];
    Check(not G2.SetState(Bad), 'a spare card that is also on the table is refused');
    Bad := A; SetLength(Bad.Spare, 7);
    Bad.Spare[6] := Bad.Spare[5];
    Check(not G2.SetState(Bad), 'more spare cards than the stock lacks is refused');
    Bad := A; Bad.Spare := nil;
    Check(G2.SetState(Bad), 'a hand with no spare cards (an old save) is fine');
  finally
    G.Free; G2.Free;
  end;
end;

{ ---- random hands: every position must be saveable and loadable ---- }

procedure TestRandomMix;
var
  G, G2, G3: TTriPeaksGame;
  D: TDeck;
  A, B: THandData;
  H, H2: TSavedHand;
  Stamp: string;
  N, I, Act, Steps, Pick: Integer;
  Wrap: Boolean;
  Bad: Integer;
begin
  Bad := 0;
  G := TTriPeaksGame.Create;
  G2 := TTriPeaksGame.Create;
  G3 := TTriPeaksGame.Create;
  try
    for N := 1 to 150 do
    begin
      Wrap := N mod 3 <> 0;
      G.WrapRanks := Wrap;
      D := TDeck.Create;
      D.Shuffle;
      G.Deal(D, 6 + (N mod 18));
      D.Free;
      for Steps := 1 to 70 do
      begin
        if G.IsWon then Break;
        Act := Random(10);
        case Act of
          0, 1, 2:                              { an ordinary play if there is one }
            for I := 27 downto 0 do
              if G.PlayTableau(I) then Break;
          3: G.DrawStock;
          4: if G.HasFreeCard then
             begin
               Pick := Random(TableauSize);
               for I := 0 to TableauSize - 1 do
                 if G.CanWild((Pick + I) mod TableauSize) then begin G.PlayWild((Pick + I) mod TableauSize); Break; end;
             end;
          5: if G.HasFreeCard and (G.Remaining > 2) then
             begin
               Pick := Random(TableauSize);
               for I := 0 to TableauSize - 1 do
                 if G.CanStake((Pick + I) mod TableauSize) then begin G.Stake((Pick + I) mod TableauSize); Break; end;
             end;
          6: G.RestoreStock;
          7: G.OpenWrap;
          8: G.Reveal;
          9: G.Undo;
        end;
        if G.IsWon then Break;
        G.GetState(A);
        if not G2.SetState(A) then
        begin
          Inc(Bad);
          if Bad < 4 then Check(False, 'game ' + IntToStr(N) + ' step ' + IntToStr(Steps) + ' act ' + IntToStr(Act) + ': a real hand did not reload');
          Continue;
        end;
        G2.GetState(B);
        if not StatesEqual(A, B) then
          Check(False, 'game ' + IntToStr(N) + ': a reloaded hand differs');
        H.Game := A;
        H.Misses := 0;
        if not (TextToHand(HandToText(H, 'x'), H2, Stamp) and G3.SetState(H2.Game)) then
        begin
          Inc(Bad);
          if Bad < 4 then Check(False, 'game ' + IntToStr(N) + ' step ' + IntToStr(Steps) + ' act ' + IntToStr(Act) + ': the saved text did not reload');
        end
        else
        begin
          G3.GetState(B);
          if not StatesEqual(A, B) then Check(False, 'game ' + IntToStr(N) + ': a hand through text differs');
        end;
      end;
    end;
    Check(Bad = 0, 'every position of every random hand reloaded (' + IntToStr(Bad) + ' did not)');
  finally
    G.Free; G2.Free; G3.Free;
  end;
end;

{ ---- the session: using, rescuing, buying ---- }

{ Nothing is ever playable: every card is a queen on a waste ace. }
function StuckDeck: TDeck;
var
  R: array[0..27] of Integer;
  I: Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  Result := BuildDeck(R, 3, 1);
end;

{ Clears by tapping cards 27 down to 0, except that card 0 is a queen (needs help). }
function OneShortDeck: TDeck;
var
  R: array[0..27] of Integer;
  I: Integer;
begin
  for I := 0 to 27 do
    if (27 - I) mod 2 = 0 then R[I] := 6 else R[I] := 7;
  R[0] := 12;
  Result := BuildDeck(R, 1, 7);
end;

procedure TestSession;
var
  S: TGameSession;
  I, C0: Integer;
begin
  S := TGameSession.Create('');
  try
    DealFrom(S, StuckDeck);
    Check(not S.CanUseSpecial(skWild), 'no card owned: nothing to use');
    S.Inventory.AddSpecial(skWild, 1);
    S.Inventory.AddSpecial(skStake, 1);
    S.Inventory.AddSpecial(skSeer, 1);
    S.Inventory.AddSpecial(skOpenWrap, 1);
    S.Inventory.AddSpecial(skFullDeck, 1);
    S.Inventory.AddSpecial(skDawn, 1);
    Check(S.CanShop, 'a fresh deal: the shop is open');
    Check(not S.CanUseSpecial(skOpenWrap), 'Open wrap does nothing in a wrapping hand: not usable');
    Check(not S.CanUseSpecial(skFullDeck), 'a Full deck has nothing to add in an ordinary deal');
    Check(not S.CanUseSpecial(skDawn), 'Dawn has nothing to do either');
    Check(S.CanUseSpecial(skWild) and S.CanUseSpecial(skStake) and S.CanUseSpecial(skSeer), 'the others can be used');
    Check(not S.UseSpecial(skWild), 'a card that needs a target cannot be used without one');
    Check(not S.UseSpecialOn(skWild, 0), 'a covered card is not a valid target');
    Check(S.Inventory.SpecialCards(skWild) = 1, 'and the card is kept');
    Check(not S.UseSpecialOn(skSeer, 27), 'a card that needs no target is not used on one');

    Check(S.UseSpecial(skSeer), 'use Seer''s eye');
    Check(S.Game.Revealed and (S.Inventory.SpecialCards(skSeer) = 0), 'revealed, and the card is spent');
    Check(not S.CanUseSpecial(skSeer), 'only once per hand');
    Check(not S.CanShop, 'using a card starts the hand: the shop shuts');
    C0 := S.Inventory.Coins;
    Check(not S.BuySpecial(skWild) and (S.Inventory.Coins = C0), 'no buying mid-hand');

    { stuck: special cards keep the hand alive }
    for I := 1 to 23 do S.DrawStock;
    Check(S.Game.IsStuck, 'stuck: no stock, no plays');
    Check(S.HasRescue, 'but a special card could still help');
    Check(not S.CanShop, 'the hand is not over');
    Check(S.UseSpecialOn(skWild, 27), 'the Wild card plays a free card');
    Check(S.Game.WasteTop.Rank = 12, 'it is the waste now');
    Check(S.Game.IsStuck, 'queens on a queen are still stuck');
    Check(S.HasRescue, 'the Wood Stake is still a way out');
    Check(S.UseSpecialOn(skStake, 26), 'stake a free card');
    Check(S.Game.IsStuck, 'still stuck');
    Check(not S.HasRescue, 'no Wild card or Stake left, and Open wrap, Full deck and Dawn have nothing to do');
    Check(S.CanShop, 'so the hand is over and the shop is open');
    Check(not S.CanUseSpecial(skOpenWrap) and not S.CanUseSpecial(skSeer), 'nothing can be used on a finished hand');
    S.Inventory.AddCoins(200);
    Check(S.BuySpecial(skWild), 'but a card can be bought');
    Check(not S.CanUseSpecial(skWild) and not S.UseSpecialOn(skWild, 25), 'and a bought card cannot rescue the finished hand');
  finally
    S.Free;
  end;
end;

procedure TestWinsBySpecials;
var
  S: TGameSession;
  I, C0: Integer;
begin
  { a Wild card plays the last card (a queen on a six) and the hand pays }
  S := TGameSession.Create('');
  try
    DealFrom(S, OneShortDeck);
    S.Inventory.AddSpecial(skWild, 1);
    C0 := S.Inventory.Coins;
    for I := 27 downto 1 do S.Play(I);
    Check(not S.Game.IsWon and S.Game.IsStuck = False, 'one card left, a queen that does not fit');
    Check(S.UseSpecialOn(skWild, 0), 'the Wild card plays it');
    Check(S.Game.IsWon, 'the board is cleared');
    Check(S.Inventory.Coins = C0 + WinCoins, 'and the win paid the reward');
    Check(S.Inventory.UndoCards = WinUndoCards, 'with its cards');
    Check(S.Note <> '', 'and a note');
  finally
    S.Free;
  end;
  { a Wood Stake destroys it instead }
  S := TGameSession.Create('');
  try
    DealFrom(S, OneShortDeck);
    S.Inventory.AddSpecial(skStake, 1);
    C0 := S.Inventory.Coins;
    for I := 27 downto 1 do S.Play(I);
    Check(S.UseSpecialOn(skStake, 0) and S.Game.IsWon, 'the Stake clears the board too');
    Check(S.Inventory.Coins = C0 + WinCoins, 'and it pays once');
    Check(not S.UseSpecialOn(skStake, 0), 'nothing more can be used after the win');
  finally
    S.Free;
  end;
end;

procedure TestLevelCards;
var
  S: TGameSession;
begin
  { the Queen's hand: a Full deck restores the 6 unused cards }
  S := TGameSession.Create('');
  try
    S.SetRules(True, 17);
    S.NewGame;
    S.Inventory.AddSpecial(skFullDeck, 2);
    S.Inventory.AddSpecial(skDawn, 1);
    S.Inventory.AddSpecial(skOpenWrap, 1);
    Check(S.CanUseSpecial(skFullDeck), 'a smaller stock: a Full deck helps');
    Check(not S.CanUseSpecial(skOpenWrap), 'but this hand already wraps');
    Check(S.CanUseSpecial(skDawn), 'Dawn is usable (the stock half)');
    Check(S.UseSpecial(skFullDeck), 'use the Full deck');
    Check(S.Game.StockCount = FullStock, 'the stock is full');
    Check(not S.CanUseSpecial(skFullDeck) and not S.CanUseSpecial(skDawn), 'now neither Full deck nor Dawn has anything to do');
    Check(S.Inventory.SpecialCards(skFullDeck) = 1, 'and the spare Full deck is kept');
  finally
    S.Free;
  end;
  { the King's hand: Open wrap, or Dawn }
  S := TGameSession.Create('');
  try
    S.SetRules(False, FullStock);
    S.NewGame;
    S.Inventory.AddSpecial(skOpenWrap, 1);
    S.Inventory.AddSpecial(skDawn, 2);
    Check(not S.CanUseSpecial(skFullDeck), 'no spare cards at the King');
    Check(S.CanUseSpecial(skOpenWrap) and S.CanUseSpecial(skDawn), 'Open wrap and Dawn both help');
    Check(S.UseSpecial(skDawn) and S.Game.WrapRanks, 'Dawn opens the wrap');
    Check(S.Game.StockCount = FullStock, 'and leaves the full stock as it was');
    Check(not S.CanUseSpecial(skDawn) and not S.CanUseSpecial(skOpenWrap), 'now there is nothing for them to do');
    Check(S.Inventory.SpecialCards(skDawn) = 1, 'the second Dawn is kept');
  finally
    S.Free;
  end;
  { the hardest hand of all (no wrap, small stock): Dawn does both in one }
  S := TGameSession.Create('');
  try
    S.SetRules(False, 10);
    S.NewGame;
    S.Inventory.AddSpecial(skDawn, 1);
    Check(S.UseSpecial(skDawn), 'use Dawn');
    Check(S.Game.WrapRanks and (S.Game.StockCount = FullStock) and (S.Game.StockSize = FullStock),
      'the gentlest rules in one card');
  finally
    S.Free;
  end;
  { at a fresh ordinary hand Dawn is greyed out (Jack, Free Play) }
  S := TGameSession.Create('');
  try
    S.NewGame;
    S.Inventory.AddSpecial(skDawn, 1);
    Check(not S.CanUseSpecial(skDawn) and not S.UseSpecial(skDawn), 'Dawn does nothing against the gentlest rules');
    Check(S.Inventory.SpecialCards(skDawn) = 1, 'and is not spent');
  finally
    S.Free;
  end;
end;

{ ---- in a duel ---- }

type
  TDecks = class
  public
    Mode: Integer;                       { 0 = stuck, 1 = one short of a win }
    function Next: TDeck;
  end;

function TDecks.Next: TDeck;
begin
  if Mode = 0 then Result := StuckDeck else Result := OneShortDeck;
end;

procedure TestDuel;
var
  S: TGameSession;
  C: TCampaign;
  DS: TDuelSession;
  Decks: TDecks;
  I: Integer;
begin
  S := TGameSession.Create('');
  C := TCampaign.Create('');
  DS := TDuelSession.Create(S, C);
  Decks := TDecks.Create;
  try
    DS.OnNeedDeck := @Decks.Next;
    DS.Activate;
    Check(not DS.UseSpecial(skSeer), 'no special cards during a scene');
    DS.SceneDone;
    { stuck, holding a Wood Stake: the duel waits instead of losing the hand }
    S.Inventory.AddSpecial(skStake, 1);
    for I := 1 to 23 do DS.DrawStock;
    Check(DS.Duel.State = dsPlaying, 'stuck with a special card: not lost');
    Check(DS.StuckWaiting, 'the window is told to wait');
    Check(DS.UseSpecialOn(skStake, 27), 'stake a card');
    Check(DS.Duel.State = dsFreeRound, 'stuck with nothing left to try: the free round');
    DS.SceneDone;
  finally
    Decks.Free; DS.Free; C.Free; S.Free;
  end;
  S := TGameSession.Create('');
  C := TCampaign.Create('');
  DS := TDuelSession.Create(S, C);
  Decks := TDecks.Create;
  try
    Decks.Mode := 1;
    DS.OnNeedDeck := @Decks.Next;
    DS.Activate;
    DS.SceneDone;
    S.Inventory.AddSpecial(skStake, 1);
    for I := 27 downto 1 do DS.Play(I);
    Check(DS.Duel.State = dsPlaying, 'one card left');
    Check(DS.UseSpecialOn(skStake, 0), 'stake it');
    Check(DS.Duel.State = dsHit, 'a Wood Stake can win a duel hand');
    Check(C.Wins = 1, 'and the win counts');
    Check(not DS.UseSpecial(skSeer), 'no special cards during the hit scene');
  finally
    Decks.Free; DS.Free; C.Free; S.Free;
  end;
end;

{ ---- the hand file ---- }

procedure TestHandText;
var
  G: TTriPeaksGame;
  D: TDeck;
  A: THandData;
  H, H2: TSavedHand;
  Stamp, Text: string;
  L: TStringList;
  K: Integer;

  function Without(const Prefix: string): string;
  var
    J: Integer;
  begin
    L.Text := Text;
    for J := L.Count - 1 downto 0 do
      if Pos(Prefix, L[J]) = 1 then L.Delete(J);
    Result := L.Text;
  end;

  function Replaced(const Prefix, NewLine: string): string;
  var
    J: Integer;
  begin
    L.Text := Text;
    for J := 0 to L.Count - 1 do
      if Pos(Prefix, L[J]) = 1 then L[J] := NewLine;
    Result := L.Text;
  end;

begin
  G := TTriPeaksGame.Create;
  L := TStringList.Create;
  try
    D := KnownDeck;
    G.Deal(D, 17);
    D.Free;
    G.Stake(27);
    G.Reveal;
    G.GetState(A);
    H.Game := A;
    H.Misses := 0;
    Text := HandToText(H, 'x');
    Check((Pos('spare=', Text) > 0) and (Pos('revealed=1', Text) > 0) and (Pos('stakes=1', Text) > 0),
      'the special-card state is written');
    Check(TextToHand(Text, H2, Stamp) and StatesEqual(H.Game, H2.Game), 'and read back exactly');
    Check(Length(H2.Game.Spare) = 6, 'six spare cards');

    { an old save has none of the three lines }
    Text := HandToText(H, 'x');
    Text := Without('stakes=');
    Text := Without('revealed=');
    Text := Without('spare=');
    Check(TextToHand(Text, H2, Stamp), 'a save without special-card lines loads');
    Check((H2.Game.Stakes = 0) and not H2.Game.Revealed and (Length(H2.Game.Spare) = 0), 'with defaults');
    Text := HandToText(H, 'x');
    Check(not TextToHand(Replaced('revealed=', 'revealed=2'), H2, Stamp), 'a bad reveal flag is refused');
    Check(not TextToHand(Replaced('stakes=', 'stakes=abc'), H2, Stamp), 'stakes that are not a number are refused');
    Check(not TextToHand(Replaced('stakes=', 'stakes=-1'), H2, Stamp), 'negative stakes are refused');
    Check(not TextToHand(Replaced('spare=', 'spare=zzz'), H2, Stamp), 'spare cards that are not cards are refused');
    for K := 0 to 0 do
      Check(TextToHand(Replaced('spare=', 'spare='), H2, Stamp) and (Length(H2.Game.Spare) = 0),
        'an empty spare line is fine (a Queen hand from before Full decks)');
  finally
    G.Free; L.Free;
  end;
end;

begin
  CrossCardsOn := False;                  { where the silver cross lies is random: it has its own tests }
  Randomize;
  TestTable;
  TestInventory;
  TestSpareAndRestore;
  TestWrapAndReveal;
  TestWildAndStake;
  TestStateRules;
  TestRandomMix;
  TestHandText;
  TestSession;
  TestWinsBySpecials;
  TestLevelCards;
  TestDuel;
  if Failures = 0 then WriteLn('ALL SPECIAL CARD TESTS PASSED') else
  begin
    WriteLn(Failures, ' FAILURES');
    Halt(1);
  end;
end.
