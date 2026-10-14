program TestHands;

{$mode objfpc}{$H+}

uses SysUtils, Classes, Cards, TriPeaks, Inventory, Session, Vampires, Campaign, Duel,
  DuelSession, Settings, HandFile{$IFDEF PAS2JS}, JsCompat{$ENDIF};

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

function CardsEq(const A, B: TCard): Boolean;
begin
  Result := (A.Suit = B.Suit) and (A.Rank = B.Rank);
end;

function HistoriesEqual(const A, B: TUndoArray): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for I := 0 to High(A) do
    if (A[I].Draw <> B[I].Draw) or (A[I].Index <> B[I].Index) or (A[I].Missed <> B[I].Missed)
      or (A[I].PrevStreak <> B[I].PrevStreak) or not CardsEq(A[I].PrevWasteTop, B[I].PrevWasteTop)
      or (A[I].Bitten <> B[I].Bitten) or (A[I].Ate <> B[I].Ate) then
      Result := False;
end;

function HandsEqual(const A, B: TSavedHand): Boolean;
var
  I: Integer;
begin
  Result := (A.Misses = B.Misses) and (A.Bites = B.Bites) and (A.Game.Hazard = B.Game.Hazard)
    and (A.Game.StockSize = B.Game.StockSize) and (A.Game.Wrap = B.Game.Wrap)
    and (A.Game.HandId = B.Game.HandId) and (A.Game.WasteCount = B.Game.WasteCount)
    and (A.Game.Streak = B.Game.Streak) and (A.Game.BestStreak = B.Game.BestStreak)
    and (A.Game.Plays = B.Game.Plays) and (Length(A.Game.Stock) = Length(B.Game.Stock))
    and CardsEq(A.Game.WasteTop, B.Game.WasteTop) and HistoriesEqual(A.Game.History, B.Game.History);
  if not Result then Exit;
  for I := 0 to TableauSize - 1 do
    if not CardsEq(A.Game.Tableau[I], B.Game.Tableau[I]) or (A.Game.Removed[I] <> B.Game.Removed[I])
      or (A.Game.Marks[I] <> B.Game.Marks[I]) then
      Result := False;
  for I := 0 to High(A.Game.Stock) do
    if not CardsEq(A.Game.Stock[I], B.Game.Stock[I]) then Result := False;
end;

{ Plays a few moves of a shuffled hand so the state is interesting. }
procedure PlaySome(S: TGameSession; Moves: Integer);
var
  K, I: Integer;
begin
  for K := 1 to Moves do
  begin
    for I := 27 downto 0 do
      if S.Play(I) then Break;
    if not S.Game.HasMoves then S.DrawStock;
  end;
end;

procedure TestTextRoundTrip;
var
  N, Moves: Integer;
  S, S2: TGameSession;
  A, B: TSavedHand;
  Text, Stamp: string;
  Ok: Boolean;
  Undos: Integer;
begin
  Undos := 0;
  for N := 1 to 300 do
  begin
    S := TGameSession.Create('');
    S2 := TGameSession.Create('');
    try
      S.NewGame;
      S.Inventory.AddUndoCards(2);
      Moves := Random(25);
      PlaySome(S, Moves);
      if (Random(3) = 0) and S.CanUseUndo then
      begin
        S.UseUndo;
        Inc(Undos);
      end;
      if not S.Game.IsWon then
      begin
        S.ExportHand(A);
        Text := HandToText(A, '2026-01-01 12:00');
        Ok := TextToHand(Text, B, Stamp);
        if not Ok then
        begin
          Check(False, 'a real hand did not survive text: ' + Text);
          Break;
        end;
        if not HandsEqual(A, B) then
        begin
          Check(False, 'a hand changed on its way through text');
          Break;
        end;
        if not S2.ImportHand(B) then
        begin
          Check(False, 'a hand read back from text was refused');
          Break;
        end;
        S2.ExportHand(B);
        if not HandsEqual(A, B) then
        begin
          Check(False, 'the session did not restore the hand exactly');
          Break;
        end;
        if S2.Game.UndoDepth <> S.Game.UndoDepth then
        begin
          Check(False, 'the reloaded hand lost some of its undo');
          Break;
        end;
        if Stamp <> '2026-01-01 12:00' then
        begin
          Check(False, 'the timestamp was lost');
          Break;
        end;
      end;
    finally
      S.Free; S2.Free;
    end;
  end;
  Check(Undos > 10, 'the round trips included hands with undo available');
  Check(Failures = 0, 'three hundred real hands survive the text format');
end;

{ The hand's rules (stock size, wrap) are saved with it; old saves have none. }
procedure TestHandRules;
var
  S, S2: TGameSession;
  A, B: TSavedHand;
  Text, Stamp: string;
  L: TStringList;
  I, N: Integer;

  function WithLine(const Old, New: string): string;
  var
    K: Integer;
  begin
    L.Text := Text;
    for K := L.Count - 1 downto 0 do
      if Pos(Old, L[K]) = 1 then
      begin
        if New = '' then L.Delete(K) else L[K] := New;
      end;
    Result := L.Text;
  end;

begin
  L := TStringList.Create;
  S := TGameSession.Create('');
  S2 := TGameSession.Create('');
  try
    S.SetRules(False, 17);
    S.NewGame;
    PlaySome(S, 6);
    S.ExportHand(A);
    Text := HandToText(A, '2026-01-01 12:00');
    Check(Pos('stocksize=17', Text) > 0, 'the stock size is written');
    Check(Pos('wrap=0', Text) > 0, 'and the wrap rule');
    Check(TextToHand(Text, B, Stamp) and HandsEqual(A, B), 'a hand with its own rules reads back exactly');
    Check((B.Game.StockSize = 17) and not B.Game.Wrap, 'with those rules');
    Check(S2.ImportHand(B), 'and loads into a session');
    Check((S2.Game.StockSize = 17) and not S2.Game.WrapRanks, 'bringing the rules along');

    { many rule combinations survive the text }
    for N := 1 to 40 do
    begin
      S.SetRules(N mod 2 = 0, 1 + (N * 7) mod FullStock);
      S.NewGame;
      PlaySome(S, N mod 20);
      if not S.Game.IsWon then
      begin
        S.ExportHand(A);
        Check(TextToHand(HandToText(A, 'x'), B, Stamp) and HandsEqual(A, B),
          'rules combination ' + IntToStr(N) + ' survives');
      end;
    end;

    { a save from before difficulty levels has neither line: ordinary rules }
    S.SetRules(True, FullStock);
    S.NewGame;
    PlaySome(S, 5);
    S.ExportHand(A);
    Text := HandToText(A, 'x');
    Check(TextToHand(WithLine('stocksize=', '') , B, Stamp), 'an old save without a stock size loads');
    Check(B.Game.StockSize = FullStock, 'with the full stock');
    Check(TextToHand(WithLine('wrap=', ''), B, Stamp) and B.Game.Wrap, 'an old save without a wrap line wraps');
    Text := HandToText(A, 'x');

    { bad values are refused }
    Check(not TextToHand(WithLine('stocksize=', 'stocksize=abc'), B, Stamp), 'a stock size that is not a number');
    Check(not TextToHand(WithLine('stocksize=', 'stocksize='), B, Stamp), 'an empty stock size');
    Check(not TextToHand(WithLine('stocksize=', 'stocksize=24'), B, Stamp), 'a stock size above the full stock');
    Check(not TextToHand(WithLine('stocksize=', 'stocksize=-1'), B, Stamp), 'a negative stock size');
    Check(not TextToHand(WithLine('stocksize=', 'stocksize=3'), B, Stamp), 'a stock bigger than the stock size');
    Check(not TextToHand(WithLine('wrap=', 'wrap=2'), B, Stamp), 'a wrap value that is not 0 or 1');
    Check(not TextToHand(WithLine('wrap=', 'wrap='), B, Stamp), 'an empty wrap value');
    { a hand that was dealt with 17 cannot be claimed to be a 23 hand }
    S.SetRules(True, 17);
    S.NewGame;
    S.ExportHand(A);
    Text := HandToText(A, 'x');
    Check(TextToHand(Text, B, Stamp) and S2.ImportHand(B), 'a 17-card hand is fine as it is');
    Check(not (TextToHand(WithLine('stocksize=', 'stocksize=23'), B, Stamp) and S2.ImportHand(B)),
      'but claiming a full stock does not fit its card counts');
  finally
    S.Free; S2.Free; L.Free;
  end;
end;

{ Hands with a vampire's trick: the marks, the bites and the moves that can be taken
  back (a bitten play, a feast) survive the text format, and old saves have none. }
procedure TestTrickHands;
var
  N, K, Moves, Reloaded: Integer;
  Kind: THazard;
  S, S2: TGameSession;
  A, B: TSavedHand;
  Text, Stamp: string;
begin
  Reloaded := 0;
  for Kind := hzBitten to hzHunger do
    for N := 1 to 80 do
    begin
      S := TGameSession.Create('');
      S2 := TGameSession.Create('');
      try
        S.SetRules(True, FullStock - Random(3), Kind);
        S.NewGame;
        if Random(2) = 0 then S.PlaceCross;          { the silver cross rides along with any trick }
        S.Inventory.AddUndoCards(3);
        Moves := 4 + Random(30);
        PlaySome(S, Moves);
        if (Random(3) = 0) and S.CanUseUndo then S.UseUndo;
        if S.Game.IsWon then Continue;
        S.ExportHand(A);
        Text := HandToText(A, 'x');
        if not TextToHand(Text, B, Stamp) then
        begin
          Check(False, 'a real hand with a trick did not survive text (kind ' + IntToStr(Ord(Kind)) + ')');
          Break;
        end;
        Check(HandsEqual(A, B), 'a hand with a trick changed on its way through text');
        Check(S2.ImportHand(B), 'the session accepted it');
        S2.ExportHand(B);
        Check(HandsEqual(A, B), 'and gave it back unchanged');
        Check((S2.Bites = S.Bites) and (S2.Game.UndoDepth = S.Game.UndoDepth), 'with its bites and its undo');
        Inc(Reloaded);
      finally
        S.Free;
        S2.Free;
      end;
    end;
  Check(Reloaded > 150, 'enough hands were checked (' + IntToStr(Reloaded) + ')');
  { an old save has none of the new lines }
  S := TGameSession.Create('');
  try
    S.NewGame;
    S.ExportHand(A);
    Text := HandToText(A, 'x');
    Check((Pos('hazard=', Text) > 0) and (Pos('marks=', Text) > 0) and (Pos('bites=', Text) > 0), 'the new lines are written');
    K := Pos('bites=', Text);
    Delete(Text, K, Pos(LineEnding, Copy(Text, K, MaxInt)) + Length(LineEnding) - 1);
    Check(TextToHand(Text, B, Stamp) and (B.Bites = 0) and (B.Game.Hazard = 0), 'a save without them loads as a hand with no trick');
    Check(not TextToHand(StringReplace(HandToText(A, 'x'), 'marks=' + StringOfChar('0', 28), 'marks=xyz', []), B, Stamp), 'damaged marks are refused');
    Check(not TextToHand(StringReplace(HandToText(A, 'x'), 'bites=0', 'bites=-3', []), B, Stamp), 'a negative bite count is refused');
  finally
    S.Free;
  end;
end;

procedure TestBadText;
var
  S: TGameSession;
  A, B: TSavedHand;
  Good, Bad, Stamp: string;
  L: TStringList;
  I: Integer;

  function Without(const Key: string): string;
  var
    J: Integer;
  begin
    L.Text := Good;
    for J := L.Count - 1 downto 0 do
      if Copy(L[J], 1, Length(Key) + 1) = Key + '=' then L.Delete(J);
    Result := L.Text;
  end;

  function Replace(const Key, Value: string): string;
  begin
    L.Text := Good;
    L.Values[Key] := Value;
    Result := L.Text;
  end;

begin
  S := TGameSession.Create('');
  L := TStringList.Create;
  try
    S.NewGame;
    S.Inventory.AddUndoCards(1);
    PlaySome(S, 6);
    S.ExportHand(A);
    Good := HandToText(A, 'x');
    Check(TextToHand(Good, B, Stamp), 'the good text reads');

    Check(not TextToHand('', B, Stamp), 'empty text is refused');
    Check(not TextToHand('hello world', B, Stamp), 'text that is not a save is refused');
    Check(not TextToHand(StringReplace(Good, 'tiecards-hand 1', 'tiecards-hand 9', []), B, Stamp),
      'an unknown version is refused');
    for I := 0 to 11 do
    begin
      case I of
        0: Bad := Without('tableau');
        1: Bad := Without('removed');
        2: Bad := Without('stock');
        3: Bad := Without('waste');
        4: Bad := Without('counts');
        5: Bad := Without('misses');
        6: Bad := Without('id');
        7: Bad := Replace('tableau', '0-1 0-2');
        8: Bad := Replace('removed', '0101');
        9: Bad := Replace('waste', '9-99');
        10: Bad := Replace('counts', '1 2 three 4');
        11: Bad := Replace('misses', '-3');
      end;
      Check(not TextToHand(Bad, B, Stamp), 'damaged entry #' + IntToStr(I) + ' is refused');
    end;
    Check(not TextToHand(Replace('id', '0'), B, Stamp), 'an id of zero is refused');
    Check(not TextToHand(Replace('removed', StringOfChar('2', 28)), B, Stamp), 'non-binary removed flags are refused');
    Check(not TextToHand(Replace('undo', '7'), B, Stamp), 'an unknown undo flag is refused');
    Check(not TextToHand(Replace('undo', 'P3:1-5'), B, Stamp), 'an undo move missing its streak is refused');
    Check(not TextToHand(Replace('undo', 'X3:1-5:0'), B, Stamp), 'an undo move of no known kind is refused');
    Check(not TextToHand(Replace('undo', 'D:9-99:0'), B, Stamp), 'an undo move with a bad card is refused');
    { a save from the one-move days says "undo=1" and the old snapshot lines }
    Check(TextToHand(Replace('undo', '1'), B, Stamp) and (Length(B.Game.History) = 0),
      'an old save loads, with nothing to undo');
    Check(not TextToHand(Replace('stock', StringOfChar('x', 40)), B, Stamp), 'a garbage stock is refused');
    Check(not TextToHand(Replace('counts', '1 2 3 4 5'), B, Stamp), 'too many counters are refused');
    Check(not TextToHand(Replace('counts', '1 2 3'), B, Stamp), 'too few counters are refused');
    { text that reads fine but is not a believable hand is refused by the game }
    Bad := Replace('counts', '99 0 0 0');
    Check(TextToHand(Bad, B, Stamp), 'syntactically fine text reads');
    Check(not S.ImportHand(B), 'but the game refuses counters that do not add up');
    S.ExportHand(A);                    { the session was left untouched by the refusal }
    Check(S.Game.Remaining < 28, 'and the current hand is untouched');
  finally
    L.Free;
    S.Free;
  end;
end;

procedure TestFiles;
var
  S: TGameSession;
  A, B: TSavedHand;
  F, Dir: string;
  Info: TSlotInfo;
  L: TStringList;
begin
  Dir := GetTempDir + 'tiecards_test_hands' + PathDelim;
  F := Dir + 'one.hand';
  if FileExists(F) then DeleteFile(F);
  S := TGameSession.Create('');
  L := TStringList.Create;
  try
    S.NewGame;
    PlaySome(S, 8);
    S.ExportHand(A);
    Check(not ReadHandFile(F, B), 'a missing file reads as no hand');
    Check(not PeekHandFile(F).Exists, 'and does not count as a save');
    Check(WriteHandFile(F, A), 'writing works (and makes the folder)');
    Check(not FileExists(F + '.tmp'), 'no temporary file is left behind');
    Check(ReadHandFile(F, B) and HandsEqual(A, B), 'the file reads back exactly');
    Info := PeekHandFile(F);
    Check(Info.Exists and (Info.CardsLeft = S.Game.Remaining), 'peeking reports the cards left');
    Check(Info.Stamp <> '', 'and when it was saved');

    { overwriting replaces it }
    PlaySome(S, 3);
    S.ExportHand(A);
    Check(WriteHandFile(F, A) and ReadHandFile(F, B) and HandsEqual(A, B), 'saving again replaces the old save');

    { a leftover temp file from a crash is harmless }
    L.Text := 'garbage';
    L.SaveToFile(F + '.tmp');
    Check(ReadHandFile(F, B) and HandsEqual(A, B), 'a stale temp file does not matter');
    Check(WriteHandFile(F, A), 'and is overwritten by the next save');
    Check(not FileExists(F + '.tmp'), 'cleanly');

    { a damaged file is simply "no save" }
    L.Text := 'tiecards-hand 1'#10'id=5'#10;
    L.SaveToFile(F);
    Check(not ReadHandFile(F, B), 'a truncated file reads as no hand');
    Check(not PeekHandFile(F).Exists, 'and is not offered as a save');
    L.Text := '';
    L.SaveToFile(F);
    Check(not ReadHandFile(F, B), 'an empty file reads as no hand');
    DeleteHandFile(F);
    Check(not FileExists(F), 'deleting removes it');
    DeleteHandFile(F);                           { and deleting nothing is fine }
  finally
    L.Free;
    S.Free;
    DeleteFile(F + '.tmp');
    RemoveDir(Dir);
  end;
  Check(AutoSaveFile(gmFreePlay) <> AutoSaveFile(gmCampaign), 'each mode has its own autosave');
  Check(SlotFile(1) <> SlotFile(2), 'each slot has its own file');
  Check(SlotFile(SlotCount) <> '', 'the last slot has a file too');
end;

{$IFNDEF PAS2JS}     { these replay a deal from a random seed, which JavaScript cannot do }
{ Finds a shuffled deal the greedy bot wins, and the moves it made. Moves are
  tile numbers 0..27 for plays and -1 for a draw. }
procedure FindWinningDeal(out Seed: LongInt; out Moves: TList);
var
  S: TGameSession;
  D: TDeck;
  I: Integer;
  Won: Boolean;
  Played: Boolean;
begin
  Moves := TList.Create;
  Seed := 0;
  repeat
    Inc(Seed);
    Moves.Clear;
    RandSeed := Seed;
    S := TGameSession.Create('');
    D := TDeck.Create;
    try
      D.Shuffle;
      S.NewGameFrom(D);
      repeat
        Played := False;
        for I := 27 downto 0 do
          if S.Play(I) then
          begin
            Moves.Add(Pointer(PtrInt(I)));
            Played := True;
            Break;
          end;
        if not Played then
        begin
          if S.Game.HasMoves then Break;
          if not S.DrawStock then Break;
          Moves.Add(Pointer(PtrInt(-1)));
        end;
      until S.Game.IsWon;
      Won := S.Game.IsWon;
    finally
      D.Free;
      S.Free;
    end;
  until Won;
end;

procedure Replay(S: TGameSession; Moves: TList);
var
  K, M: Integer;
begin
  for K := 0 to Moves.Count - 1 do
  begin
    M := PtrInt(Moves[K]);
    if M < 0 then S.DrawStock else S.Play(M);
  end;
end;

procedure TestRewardOnce;
var
  Seed: LongInt;
  Moves: TList;
  S: TGameSession;
  D: TDeck;
  Start: TSavedHand;
  F: string;
  Coins0: Integer;
begin
  FindWinningDeal(Seed, Moves);
  F := GetTempDir + 'tiecards_test_paid.ini';
  if FileExists(F) then DeleteFile(F);
  S := TGameSession.Create(F);
  try
    RandSeed := Seed;
    D := TDeck.Create;
    D.Shuffle;
    S.NewGameFrom(D);
    D.Free;
    S.ExportHand(Start);                       { "save at the start of the hand" }
    Coins0 := S.Inventory.Coins;
    Replay(S, Moves);
    Check(S.Game.IsWon, 'the hand is won');
    Check(S.Inventory.Coins > Coins0, 'the first win pays');
    Coins0 := S.Inventory.Coins;
    Check(Pos('already', S.Note) = 0, 'with no complaint');

    { load the save from before the win and win it again }
    Check(S.ImportHand(Start), 'the saved hand loads');
    Check(not S.Game.IsWon, 'it is a fresh hand again');
    Replay(S, Moves);
    Check(S.Game.IsWon, 'and can be won again');
    Check(S.Inventory.Coins = Coins0, 'but pays nothing the second time');
    Check(Pos('already', S.Note) > 0, 'and says why: ' + S.Note);

    { a different deal pays normally }
    D := TDeck.Create;
    D.Shuffle;
    S.NewGameFrom(D);
    D.Free;
    Check(not S.Inventory.HandPaid(S.Game.HandId), 'a new deal has not paid yet');
  finally
    S.Free;
  end;
  { the memory of paid hands survives a restart, so quitting does not reopen the loophole }
  S := TGameSession.Create(F);
  try
    Check(S.Inventory.HandPaid(Start.Game.HandId), 'paid hands are remembered across runs');
    Check(S.ImportHand(Start), 'the old save still loads');
    Coins0 := S.Inventory.Coins;
    Replay(S, Moves);
    Check(S.Game.IsWon and (S.Inventory.Coins = Coins0), 'and still pays nothing after a restart');
  finally
    S.Free;
    Moves.Free;
    DeleteFile(F);
  end;
end;

{$ENDIF}

procedure TestPaidList;
var
  Inv, Inv2: TPlayerInventory;
  F: string;
  I: Integer;
begin
  F := GetTempDir + 'tiecards_test_paidlist.ini';
  if FileExists(F) then DeleteFile(F);
  Inv := TPlayerInventory.Create;
  Inv2 := TPlayerInventory.Create;
  try
    Check(not Inv.HandPaid(7), 'nothing is paid at first');
    Inv.MarkHandPaid(7);
    Check(Inv.HandPaid(7) and not Inv.HandPaid(8), 'a marked hand is remembered');
    Inv.MarkHandPaid(7);                         { twice is fine }
    for I := 1 to RememberedHands + 50 do Inv.MarkHandPaid(1000 + I);
    Check(not Inv.HandPaid(7), 'the oldest are forgotten past the limit');
    Check(Inv.HandPaid(1000 + RememberedHands + 50), 'the newest are kept');
    Inv.SaveToFile(F);
    Inv2.LoadFromFile(F);
    Check(Inv2.HandPaid(1000 + RememberedHands + 50), 'the list survives saving');
    Check(not Inv2.HandPaid(7), 'and so does the limit');
    { junk in the file is ignored, not a crash }
    with TStringList.Create do
    try
      Text := '[Inventory]'#10'Coins=10'#10'PaidHands=5,abc,,-4,0,6,5'#10;
      SaveToFile(F);
    finally
      Free;
    end;
    Inv2.LoadFromFile(F);
    Check(Inv2.HandPaid(5) and Inv2.HandPaid(6), 'good ids are read');
    Check(not Inv2.HandPaid(0) and not Inv2.HandPaid(-4), 'bad ids are ignored');
    Check(Inv2.Coins = 10, 'and the rest of the file still loads');
  finally
    Inv.Free; Inv2.Free;
    DeleteFile(F);
  end;
end;

procedure TestKillPending;
var
  F: string;
  C, C2: TCampaign;
begin
  F := GetTempDir + 'tiecards_test_kill.ini';
  if FileExists(F) then DeleteFile(F);
  C := TCampaign.Create(F);
  try
    C.AddLostHand;
    C.RecordKill;                                { the kill, then a crash }
  finally
    C.Free;
  end;
  C2 := TCampaign.Create(F);
  try
    Check(C2.Current = 1, 'a recorded kill moves the campaign on when it is loaded');
    Check(C2.LostHands = 0, 'and clears the lost hands');
  finally
    C2.Free;
  end;
  C2 := TCampaign.Create(F);
  try
    Check(C2.Current = 1, 'loading again does not move it on twice');
    C2.RecordKill;
    C2.Advance;                                  { the normal path: the scenes finish }
    Check(C2.Current = 2, 'the normal path moves on exactly once');
  finally
    C2.Free;
  end;
  C2 := TCampaign.Create(F);
  try
    Check(C2.Current = 2, 'and loading afterwards does not move on again');
    C2.Reset;
    C2.RecordKill;
    C2.Reset;
    Check(C2.Current = 0, 'resetting clears a pending kill');
  finally
    C2.Free;
  end;
  C2 := TCampaign.Create(F);
  try
    Check(C2.Current = 0, 'and that is saved');
  finally
    C2.Free;
  end;
  DeleteFile(F);
end;

procedure TestResumeHand;
var
  S, Src: TGameSession;
  C: TCampaign;
  DS: TDuelSession;
  H, H2: TSavedHand;
  Bad: TSavedHand;
begin
  S := TGameSession.Create('');
  Src := TGameSession.Create('');
  C := TCampaign.Create('');
  DS := TDuelSession.Create(S, C);
  try
    Src.NewGame;
    PlaySome(Src, 7);
    Src.ExportHand(H);

    DS.Activate;
    Check(DS.Duel.State = dsIntro, 'at the intro');
    Bad := H;
    Bad.Game.Plays := Bad.Game.Plays + 5;
    Check(not DS.ResumeHand(Bad), 'a hand that is not believable is not resumed');
    Check(DS.Duel.State = dsIntro, 'the duel stays at its intro');
    Check(DS.ResumeHand(H), 'a believable hand is resumed');
    Check(DS.Duel.State = dsPlaying, 'straight into play, skipping the intro');
    S.ExportHand(H2);
    Check(HandsEqual(H, H2), 'with exactly the saved cards');
    Check(not DS.ResumeHand(H), 'a hand cannot be resumed over a hand in progress');
    { play carries on from the restored hand }
    Check(DS.DrawStock or DS.Session.Game.HasMoves, 'play goes on');

    { restored misses count towards the pay }
    Src.NewGame;
    Src.ExportHand(H);
    H.Misses := 2;
    DS.Restart;
    Check(DS.ResumeHand(H), 'a hand with misses resumes');
    Check(DS.PayoutNow = VampireWinCoins[0] - 2 * MissPenaltyCoins, 'and its misses still cost');
  finally
    DS.Free; C.Free; Src.Free; S.Free;
  end;
end;

begin
  CrossCardsOn := False;                  { where the silver cross lies is random: it has its own tests }
  Randomize;
  TestTextRoundTrip;
  TestTrickHands;
  TestHandRules;
  TestBadText;
  TestFiles;
  TestPaidList;
{$IFNDEF PAS2JS}
  TestRewardOnce;
{$ENDIF}
  TestKillPending;
  TestResumeHand;
  if Failures = 0 then WriteLn('ALL HAND TESTS PASSED') else
  begin
    WriteLn(Failures, ' FAILURES');
    Halt(1);
  end;
end.
