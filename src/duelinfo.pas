unit DuelInfo;

{ The facts the duel panel shows, worked out in one place. No window code, so
  the panel can never disagree with what is actually paid. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Vampires, Inventory, Story, TriPeaks, Duel, DuelSession;

type
  TDuelInfo = record
    Active: Boolean;          { False once the campaign is complete }
    Vampire: Integer;         { 0..VampireCount-1 }
    DuelNumber: Integer;      { 1-based, for "Duel 2 of 3" }
    DuelCount: Integer;
    Name, Title: string;
    Wins: Integer;            { won hands against him so far }
    WinsNeeded: Integer;      { how many it takes to kill him }
    PerWin: Integer;          { what a win pays to begin with }
    KillBonus: Integer;       { added by the next win: 0 unless it is the fifth }
    LostHands: Integer;       { lost hands since the last win }
    LostHandsCut: Integer;    { coins those take off the next win }
    Misses: Integer;          { missed moves in this hand }
    MissCut: Integer;         { coins those take off }
    Bites: Integer;           { bitten cards played in this hand }
    BiteCut: Integer;         { coins those take off }
    HazardText: string;       { his trick, in a short line (see VampireHazard) }
    PayNow: Integer;          { what winning this hand pays right now, bonus included }
    AtFloor: Boolean;         { the minimum is holding the per-win pay up }
    StuckWaiting: Boolean;    { stuck, but an undo card could still help }
    StockCards: Integer;      { stock cards in this vampire's hands }
    WrapRanks: Boolean;       { King and Ace count as neighbours in his hands }
    Eased: Boolean;           { this hand was dealt at the lowest level (the silver cross) }
    CrossText: string;        { about the silver cross, if there is anything to say }
  end;

{ The numbers in the side panel's stats block (both modes). In Free Play the
  panel also shows what the hand pays: PerWin, less MissCut for the misses. }
type
  TPanelStats = record
    Remaining, Stock, Streak, BestStreak, Coins: Integer;
    FreePlay: Boolean;
    PerWin, Misses, MissCut, PayNow: Integer;
  end;

function GetDuelInfo(ADuel: TDuelSession; AStory: TStory): TDuelInfo;

implementation

function GetDuelInfo(ADuel: TDuelSession; AStory: TStory): TDuelInfo;
var
  V: Integer;
begin
  Result.Active := False;
  Result.Vampire := -1;
  Result.DuelNumber := 0;
  Result.DuelCount := VampireCount;
  Result.Name := '';
  Result.Title := '';
  Result.Wins := 0;
  Result.WinsNeeded := WinsToKill;
  Result.PerWin := 0;
  Result.KillBonus := 0;
  Result.LostHands := 0;
  Result.LostHandsCut := 0;
  Result.Misses := 0;
  Result.MissCut := 0;
  Result.Bites := 0;
  Result.BiteCut := 0;
  Result.HazardText := '';
  Result.PayNow := 0;
  Result.AtFloor := False;
  Result.StuckWaiting := False;
  Result.StockCards := FullStock;
  Result.WrapRanks := True;
  Result.Eased := False;
  Result.CrossText := '';
  V := ADuel.Duel.Vampire;
  if (V < 0) or (V >= VampireCount) or (ADuel.Duel.State = dsComplete) then Exit;

  Result.Active := True;
  Result.Vampire := V;
  Result.DuelNumber := V + 1;
  Result.Name := AStory.Name(V);
  Result.Title := AStory.Title(V);
  Result.Wins := ADuel.Duel.Wins;
  Result.PerWin := VampireWinCoins[V];
  Result.KillBonus := ADuel.Duel.KillBonus;
  Result.LostHands := ADuel.Duel.LostHands;
  { the cuts as they really apply (the floor can stop them short) }
  Result.LostHandsCut := Result.PerWin - ADuel.Duel.Spoils;
  Result.Misses := ADuel.Session.Misses;
  Result.MissCut := ADuel.Duel.Spoils - RewardAfterMisses(ADuel.Duel.Spoils, Result.Misses);
  Result.Bites := ADuel.Session.Bites;
  Result.BiteCut := RewardAfterMisses(ADuel.Duel.Spoils, Result.Misses)
    - RewardAfterCuts(ADuel.Duel.Spoils, Result.Misses, Result.Bites);
  Result.Eased := ADuel.Campaign.EaseLive;
  if not Result.Eased then                 { the silver cross switches his trick off }
    case VampireHazard[V] of
      hzBitten: Result.HazardText := Format('Bitten cards: playing one costs %d coins', [BitePenaltyCoins]);
      hzChained: Result.HazardText := 'Chained cards: clear the cards beside them';
      hzHunger: Result.HazardText := Format('Hunger: every %dth draw eats a stock card', [FeedEvery]);
    end;
  Result.PayNow := ADuel.PayoutNow;
  { the floor is holding the per-win pay up if the plain sums would go lower }
  Result.AtFloor := Result.PayNow - Result.KillBonus
    > Result.PerWin - SpoilsStep * Result.LostHands - MissPenaltyCoins * Result.Misses
      - BitePenaltyCoins * Result.Bites;
  Result.StuckWaiting := ADuel.StuckWaiting;
  if Result.Eased then
  begin
    Result.StockCards := VampireStockCards[0];
    Result.WrapRanks := VampireWrapRanks[0];
  end
  else
  begin
    Result.StockCards := VampireStockCards[V];
    Result.WrapRanks := VampireWrapRanks[V];
  end;
  { the silver cross }
  if ADuel.Campaign.Ease <> 0 then
  begin
    if not Result.Eased then
      Result.CrossText := 'Silver cross claimed: he is weakened from the next hand'
    else if ADuel.Campaign.Ease < 0 then
      Result.CrossText := 'Weakened by the silver cross until he falls'
    else if ADuel.Campaign.Ease = 1 then
      Result.CrossText := 'Weakened by the silver cross: this is the last hand'
    else
      Result.CrossText := Format('Weakened by the silver cross: %d hands left', [ADuel.Campaign.Ease]);
  end
  else if ADuel.Session.Game.HasMark(MarkCross) then
    Result.CrossText := 'A silver cross lies on the table: a Wild card can claim it';
end;

end.
