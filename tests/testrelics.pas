program testrelics;

{ Relics: what each one does to a hand, how it is paid for and saved, and the
  rules that keep it fair (one break, one skipped feeding, one free hint, one
  forgiven bite or miss, all undone and saved with the hand). }

{$mode objfpc}{$H+}

uses SysUtils, Classes, Cards, TriPeaks, Storage, Inventory, Session, Settings, Story, Trophies,
  Relics, HandFile, Campaign
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

function StoryPath: string;
begin
{$IFDEF PAS2JS}
  Result := 'assets/story/story.ini';          { run from the project folder }
{$ELSE}
  Result := ExtractFilePath(ParamStr(0)) + '../assets/story/story.ini';
{$ENDIF}
end;

function MakeCard(Rank: Integer): TCard;
begin
  Result.Suit := suSpades;
  Result.Rank := Rank;
  Result.FaceUp := False;
end;

{ 28 tableau cards, 23 stock cards, then the waste card. }
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

procedure TestTable;
var
  R: TRelic;
begin
  for R := Low(TRelic) to High(TRelic) do
  begin
    Check(RelicIndexOf(RelicKey(R)) = Ord(R), 'a key finds its relic: ' + RelicKey(R));
    Check(RelicPrice(R) > 0, RelicKey(R) + ' has a price');
    Check(HasRelic(RelicBit(R), R) and not HasRelic(0, R), 'its bit');
  end;
  Check(RelicIndexOf('nonsense') = -1, 'an unknown key is -1');
  Check((RelicSlots(0) = 1) and (RelicSlots(1) = 2) and (RelicSlots(3) = 4) and (RelicSlots(9) = MaxRelicSlots) and (RelicSlots(-2) = 1),
    'one slot, and one more for each vampire trophy, up to the cap');
  Check((RelicTrophy(rlLocket) = Ord(trPerfect)) and (RelicTrophy(rlMoonstone) = Ord(trVampire1)), 'the Locket and the Moonstone can also be earned');
  Check((RelicTrophy(rlGarlic) = NoRelicTrophy) and (RelicTrophy(rlPick) = NoRelicTrophy) and (RelicTrophy(rlSpoon) = NoRelicTrophy),
    'the first three are only bought');
  Check(ValidRelicMask(0) and ValidRelicMask(31) and not ValidRelicMask(32) and not ValidRelicMask(-1), 'a mask has five bits');
end;

procedure TestBuying;
var
  Inv, Inv2: TPlayerInventory;
  F, Text: string;
begin
  F := GetTempDir + 'tiecards_test_relic_inv.ini';
  StoreDelete(F);
  Inv := TPlayerInventory.Create;
  try
    Check(not Inv.BoughtRelic(rlPick) and not Inv.CanBuyRelic(rlPick), 'nothing bought; 50 coins do not reach 160');
    Check(not Inv.BuyRelic(rlPick) and (Inv.Coins = StartingCoins), 'a refused purchase takes nothing');
    Inv.AddCoins(1000);
    Check(Inv.BuyRelic(rlPick) and (Inv.Coins = StartingCoins + 1000 - RelicPrice(rlPick)), 'buy one at its price');
    Check(not Inv.BuyRelic(rlPick), 'not twice');
    Check(Inv.BoughtRelic(rlPick) and not Inv.BoughtRelic(rlSpoon), 'only that one');
    Inv.SaveToFile(F);
    Text := Inv.ExportText;
  finally
    Inv.Free;
  end;
  Inv2 := TPlayerInventory.Create;
  Inv2.LoadFromFile(F);
  try
    Check(Inv2.BoughtRelic(rlPick), 'saved on disk');
    Inv2.Reset;
    Check(not Inv2.BoughtRelic(rlPick), 'a reset takes it away');
    Inv2.ImportText(Text);
    Check(Inv2.BoughtRelic(rlPick), 'a save slot keeps it');
  finally
    Inv2.Free;
  end;
  StoreDelete(F);
end;

procedure TestSettings;
var
  F: string;
  S: TSettings;
begin
  F := GetTempDir + 'tiecards_test_relic_set.ini';
  StoreDelete(F);
  S := TSettings.Create(F);
  try
    Check(S.Equipped = '', 'nothing equipped to begin with');
    S.Equipped := 'pick,locket';
    S.Save;
  finally
    S.Free;
  end;
  S := TSettings.Create(F);
  try
    Check(S.Equipped = 'pick,locket', 'saved');
    S.ResetRelics;
    Check(S.Equipped = '', 'and reset');
  finally
    S.Free;
  end;
  StoreDelete(F);
end;

procedure TestCharges;
var
  S: TGameSession;
  R: array[0..27] of Integer;
  I: Integer;
begin
  for I := 0 to 27 do R[I] := 12;
  S := TGameSession.Create('');
  S.HazardsOn := False;
  try
    { every draw misses a move: the 7s on the table could be played onto the 7... use stock 6s }
    for I := 0 to 27 do R[I] := 6;
    R[26] := 7;                                    { 27 plays onto the 7 and 26 onto that }
    S.NewGameFrom(BuildDeck(R, 5, 7));             { the bottom row plays onto the 7 }
    S.DrawStock;
    S.DrawStock;
    Check((S.Misses = 2) and (S.ChargedMisses = 2), 'no relic: two misses charged');
    Check(S.PayoutNow = RewardAfterCuts(WinCoins, 2, 0), 'and paid for');
    { the Steady Locket forgives the first }
    S.Relics := RelicBit(rlLocket);
    S.NewGameFrom(BuildDeck(R, 5, 7));
    S.DrawStock;
    Check((S.Misses = 1) and (S.ChargedMisses = 0), 'the Locket: the first miss costs nothing');
    Check(S.PayoutNow = WinCoins, 'so the hand pays in full');
    S.DrawStock;
    Check((S.Misses = 2) and (S.ChargedMisses = 1) and (S.PayoutNow = RewardAfterCuts(WinCoins, 1, 0)), 'the second is charged');
    S.Inventory.AddUndoCards(2);
    S.UseUndo;
    Check((S.Misses = 1) and (S.ChargedMisses = 0), 'undo takes the miss back, and the forgiveness stays right');
    S.UseUndo;
    Check((S.Misses = 0) and (S.ChargedMisses = 0), 'and back to none');
    { the Garlic Wreath forgives the first bite }
    S.Relics := RelicBit(rlGarlic);
    S.NewGameFrom(BuildDeck(R, 5, 7));
    S.Game.SetHazard(hzBitten);
    for I := 0 to 27 do S.Game.SetMark(I, MarkNone);
    S.Game.SetMark(27, MarkBitten);
    S.Game.SetMark(26, MarkBitten);
    Check(S.Play(27), 'play a bitten card');
    Check((S.Bites = 1) and (S.ChargedBites = 0), 'the Garlic: the first bite is free');
    Check(S.PayoutNow = WinCoins, 'and costs the hand nothing');
    Check(S.Play(26), 'a second bitten card');
    Check((S.Bites = 2) and (S.ChargedBites = 1) and (S.PayoutNow = RewardAfterCuts(WinCoins, 0, 1)), 'costs its coins');
    { with both, each forgives its own }
    S.Relics := RelicBit(rlGarlic) or RelicBit(rlLocket);
    S.NewGameFrom(BuildDeck(R, 5, 7));
    Check(S.ActiveRelics = (RelicBit(rlGarlic) or RelicBit(rlLocket)), 'a hand keeps the relics it was dealt with');
  finally
    S.Free;
  end;
end;

procedure TestMoonstone;
var
  S, S2: TGameSession;
  H: TSavedHand;
begin
  S := TGameSession.Create('');
  S2 := TGameSession.Create('');
  S.HazardsOn := False;
  S2.HazardsOn := False;
  try
    Check(S.Inventory.HintCards = 0, 'test set-up: no hint cards');
    S.NewGame;
    Check((S.UseHint = hrNoHintCards) and not S.FreeHintAvailable, 'no relic and no cards: no hint');
    S.Relics := RelicBit(rlMoonstone);                 { a hand not yet started takes it at once }
    Check(S.FreeHintAvailable, 'equipped before the first move: this hand has the free hint');
    Check(S.UseHint <> hrNoHintCards, 'the free hint works');
    Check((S.Inventory.HintCards = 0) and not S.FreeHintAvailable, 'and used no card; it is spent');
    S.DrawStock;
    Check(S.UseHint = hrNoHintCards, 'a second hint needs a card');
    { saved and loaded: the free hint is not given back }
    S.ExportHand(H);
    Check(H.FreeHintUsed and HasRelic(H.Relics, rlMoonstone), 'the saved hand remembers');
    Check(S2.ImportHand(H), 'it loads');
    Check(not S2.FreeHintAvailable and (S2.UseHint = hrNoHintCards), 'a resumed hand does not give the hint back');
    { a hand under way does not take a new relic; the next one does }
    S.Relics := 0;
    Check(HasRelic(S.ActiveRelics, rlMoonstone), 'a hand under way keeps its relic');
    S.NewGame;
    Check(not HasRelic(S.ActiveRelics, rlMoonstone), 'the next hand does not have it');
  finally
    S.Free;
    S2.Free;
  end;
end;

procedure TestRulesRelics;
var
  S, S2: TGameSession;
  H: TSavedHand;
begin
  S := TGameSession.Create('');
  S2 := TGameSession.Create('');
  try
    S.Relics := RelicBit(rlPick) or RelicBit(rlSpoon);
    S.NewGame;
    Check((S.Game.BreaksAtStart = 1) and S.Game.FeedSkipped, 'the Pick and the Spoon reach the game''s rules');
    S.ExportHand(H);
    Check(H.Game.FeedSkip and (H.Game.BreakStart = 1), 'and the saved hand');
    Check(S2.ImportHand(H) and (S2.Game.BreaksAtStart = 1) and S2.Game.FeedSkipped, 'which loads back with them');
    H.Relics := 0;
    Check(not S2.ImportHand(H), 'a hand whose rules do not match its relics is refused');
    S.ExportHand(H);
    H.Relics := 99;
    Check(not S2.ImportHand(H), 'and so is an impossible relic set');
    S.Relics := 0;
    S.NewGame;
    Check((S.Game.BreaksAtStart = 0) and not S.Game.FeedSkipped, 'no relics: the plain rules');
  finally
    S.Free;
    S2.Free;
  end;
end;

procedure DeleteLine(var Text: string; const Key: string);
var
  P, Q: Integer;
begin
  P := Pos(Key + '=', Text);
  if P = 0 then Exit;
  Q := P + Pos(#10, Copy(Text, P, MaxInt)) - 1;
  Delete(Text, P, Q - P + 1);
end;

procedure TestHandText;
var
  S: TGameSession;
  H, H2: TSavedHand;
  Text, Stamp: string;
begin
  S := TGameSession.Create('');
  S.HazardsOn := False;
  try
    S.Relics := RelicBit(rlPick) or RelicBit(rlMoonstone);
    S.NewGame;
    S.UseHint;
    S.ExportHand(H);
    Text := HandToText(H, 'x');
    Check((Pos('relics=', Text) > 0) and (Pos('freehint=1', Text) > 0) and (Pos('breaks=1 1', Text) > 0), 'the new lines are written');
    Check(TextToHand(Text, H2, Stamp) and (H2.Relics = H.Relics) and H2.FreeHintUsed and (H2.Game.BreakStart = 1) and (H2.Game.BreakLeft = 1),
      'and read back');
    { an old save has none of them }
    DeleteLine(Text, 'relics');
    DeleteLine(Text, 'freehint');
    DeleteLine(Text, 'feedskip');
    DeleteLine(Text, 'breaks');
    Check(Pos('relics=', Text) = 0, 'test set-up: the lines are gone');
    Check(TextToHand(Text, H2, Stamp) and (H2.Relics = 0) and not H2.FreeHintUsed and (H2.Game.BreakStart = 0) and not H2.Game.FeedSkip,
      'a save without them loads with no relics');
  finally
    S.Free;
  end;
end;

procedure TestText;
var
  St: TStory;
  R: TRelic;
begin
  St := TStory.Create;
  try
    St.LoadFromFile(StoryPath);
    Check(Length(St.Validate) = 0, 'the story file has everything, the relic text included');
    for R := Low(TRelic) to High(TRelic) do
    begin
      Check(St.RelicName(RelicKey(R)) <> '', RelicKey(R) + ' has a name');
      Check(St.RelicLine(RelicKey(R)) <> '', RelicKey(R) + ' says what it does');
      Check(Pos('%', St.RelicLine(RelicKey(R))) = 0, RelicKey(R) + ' has no format marks');
    end;
  finally
    St.Free;
  end;
end;

begin
  CrossCardsOn := False;
  TestTable;
  TestBuying;
  TestSettings;
  TestCharges;
  TestMoonstone;
  TestRulesRelics;
  TestHandText;
  TestText;
  if Failures = 0 then WriteLn('ALL RELIC TESTS PASSED')
  else
  begin
    WriteLn(Failures, ' FAILURES');
    Halt(1);
  end;
end.
