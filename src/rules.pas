unit Rules;

{ The player's rules, in plain words, for the Rules button on the menu. No
  window code: both front ends show the same sections (the desktop as one
  scrolling text, the web page as a dialog).

  Every number is built from the constants the game really uses, so a balance
  change cannot leave this text wrong. Names come from the story file. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, TriPeaks, Specials, Inventory, Vampires, Duel, Story, HandFile, Trophies;

function RulesSectionCount: Integer;
function RulesHeading(I: Integer; AStory: TStory): string;
{ The paragraphs of a section, one per line (separated by LineBreak). }
function RulesBody(I: Integer; AStory: TStory): string;
{ Everything as one text: each heading, then its paragraphs. }
function RulesPlainText(AStory: TStory): string;

const
  RulesBreak = #10;       { between paragraphs, in the same way on every platform }

implementation

const
  Sections = 12;
  RankNames: array[0..VampireCount - 1] of string = ('Jack', 'Queen', 'King');

function RulesSectionCount: Integer;
begin
  Result := Sections;
end;

function RulesHeading(I: Integer; AStory: TStory): string;
begin
  case I of
    0: Result := 'The goal';
    1: Result := 'Playing cards';
    2: Result := 'Drawing, missed moves and streaks';
    3: Result := 'Winning and losing a hand';
    4: Result := 'Undo and hint cards';
    5: Result := 'The Store and special cards';
    6: Result := 'The Campaign';
    7: Result := 'The vampires and their tricks';
    8: Result := 'The silver cross';
    9: Result := 'Saving your game';
    10: Result := 'Trophies';
  else
    Result := 'Free Play and Records';
  end;
end;

{ "Lucien Vale (the Jack)" }
function VampireLabel(V: Integer; AStory: TStory): string;
begin
  Result := Format('%s (the %s)', [AStory.Name(V), RankNames[V]]);
end;

function BodyPlaying(AStory: TStory): string;
begin
  Result :=
    'A card can be played when it is free: nothing is lying on top of it. The bottom row starts free and face up. ' +
    'A face-down card turns face up as soon as both cards covering it are gone.' + RulesBreak +
    'A free card can be played onto the pile beside the stock (the waste pile) if its rank is one higher or one lower than the top card of that pile. ' +
    'Suits do not matter. A 7 plays on a 6 or an 8.' + RulesBreak +
    'King and Ace count as neighbours (a King plays on an Ace and an Ace on a King) in most hands. ' +
    'Where that is switched off, the panel says "King and Ace do not wrap".' + RulesBreak +
    'Tap a card to play it. Cards that cannot be played do nothing.';
end;

function BodyDrawing(AStory: TStory): string;
begin
  Result :=
    'When nothing can be played, tap the stock to turn its top card onto the waste pile. ' +
    'An ordinary hand has ' + IntToStr(FullStock) + ' cards in the stock, and it does not refill by itself.' + RulesBreak +
    Format('If you draw while a card on the table could have been played, that is a missed move. Each missed move takes %d coins off what the hand pays (it never pays less than %d).',
      [MissPenaltyCoins, RewardFloorCoins]) + RulesBreak +
    'Every card you play in a row builds your streak. Drawing from the stock ends it. Your longest streak goes in your Records.';
end;

function BodyWinLose(AStory: TStory): string;
begin
  Result :=
    'You win a hand by clearing all 28 cards from the three peaks.' + RulesBreak +
    'You lose a hand when the stock is empty and no card on the table can be played. ' +
    'If you still have an undo card or a special card that could help, the game waits so that you can use one. ' +
    'In the Campaign, pressing New Game gives up the hand you are playing, and it counts as a lost hand.';
end;

function BodyUndoHint(AStory: TStory): string;
begin
  Result :=
    'An undo card takes back your last move. You can use as many as you have cards for, one card for each move, all the way back to the deal. ' +
    'Taking back a missed move or a bitten card gives its coins back. ' +
    'Using a special card clears the history, so you cannot undo past it.' + RulesBreak +
    'A hint card (the Show move button) points out a card you could play. ' +
    'The card is used up even when there is no move to show.' + RulesBreak +
    Format('You start with %d coins, and clearing hands earns more coins and cards. Packs are sold in the Store: %d undo cards for %d coins, %d hint cards for %d coins (list prices).',
      [StartingCoins, UndoPackSize, UndoPackCost, HintPackSize, HintPackCost]);
end;

function SpecialLine(K: TSpecialKind; const Text: string): string;
begin
  Result := Format('%s (%d coins): %s', [SpecialName[K], SpecialPrice[K], Text]);
end;

function BodyStore(AStory: TStory): string;
begin
  Result :=
    'The Store is run by Fenwick Grimm. It is open between hands, and on a fresh hand until you make your first move. It is also open at the start of a hand you have loaded. ' +
    'Prices are fixed and nothing in the Store is random: you always get what you pay for.' + RulesBreak +
    'Your special cards are kept in My cards. A special card can be used in any hand, as many as you like:' + RulesBreak +
    SpecialLine(skFullDeck, 'the cards left out of the stock (and any the Count ate) join it again.') + RulesBreak +
    SpecialLine(skOpenWrap, 'King and Ace become neighbours for this hand.') + RulesBreak +
    SpecialLine(skDawn, 'both of the above in one card.') + RulesBreak +
    SpecialLine(skWild, 'tap a free card and it plays onto the waste pile whatever its rank.') + RulesBreak +
    SpecialLine(skSeer, 'turns every face-down card face up for this hand.') + RulesBreak +
    SpecialLine(skStake, 'tap a free card to destroy it. It counts towards clearing the table, and your streak and the waste pile stay as they were.') + RulesBreak +
    Format('Fenwick starts selling the Full deck once you reach %s, and Open wrap once you reach %s.',
      [VampireLabel(FirstSmallStockVampire, AStory), VampireLabel(FirstNoWrapVampire, AStory)]);
end;

function BodyCampaign(AStory: TStory): string;
var
  V: Integer;
  Pays: string;
begin
  Pays := '';
  for V := 0 to VampireCount - 1 do
  begin
    if Pays <> '' then Pays := Pays + ', ';
    Pays := Pays + Format('%d', [VampireWinCoins[V]]);
  end;
  Result :=
    Format('In the Campaign you duel %d vampires in turn. To kill one you must win %d hands against that vampire.', [VampireCount, WinsToKill]) + RulesBreak +
    Format('Each won hand pays coins at once (%s coins for the %s, %s and %s). The last hand, the one that kills the vampire, pays a bonus on top: ',
      [Pays, RankNames[0], RankNames[1], RankNames[2]]) +
    Format('%d, %d and %d coins.', [VampireKillBonus[0], VampireKillBonus[1], VampireKillBonus[2]]) + RulesBreak +
    Format('Winning also earns cards: %d hint card for each of the first %d wins, and %d undo card and %d hint cards for the kill.',
      [HitHintCards, WinsToKill - 1, WinUndoCards, WinHintCards]) + RulesBreak +
    Format('Losing a hand never costs you a win. The vampire drinks your blood, you deal again, and the next win pays %d coins less for each hand you have lost since your last win (never less than %d).',
      [SpoilsStep, RewardFloorCoins]) + RulesBreak +
    Format('Missed moves still take %d coins each off a hand''s pay.', [MissPenaltyCoins]) + RulesBreak +
    Format('The Store is cheaper at the earlier vampires: %d%% of list price against %s, %d%% against %s and %d%% against %s.',
      [VampirePricePercent[0], AStory.Name(0), VampirePricePercent[1], AStory.Name(1), VampirePricePercent[2], AStory.Name(2)]) + RulesBreak +
    'After the last vampire falls, the Campaign is over and you can play it again from the Start over button.';
end;

function StockText(V: Integer): string;
begin
  Result := Format('%d stock cards', [VampireStockCards[V]]);
  if VampireWrapRanks[V] then Result := Result + ', King and Ace wrap'
  else Result := Result + ', King and Ace do not wrap';
end;

function BodyVampires(AStory: TStory): string;
begin
  Result :=
    'Each vampire changes the rules a little, and each has a trick. The panel beside the table always reminds you.' + RulesBreak +
    Format('%s: %s. Bitten cards: %d cards carry a bat. Playing one costs %d coins off the hand''s pay and ends your streak.',
      [VampireLabel(0, AStory), StockText(0), BittenCount, BitePenaltyCoins]) + RulesBreak +
    Format('%s: %s. Chained cards: %d cards are chained. A chained card cannot be played while a card beside it in its row is still on the table. A Wood Stake or a Wild card still reaches it.',
      [VampireLabel(1, AStory), StockText(1), ChainedCount]) + RulesBreak +
    Format('%s: %s. Hunger: after every %dth draw he eats the bottom card of the stock. A Full deck brings the eaten cards back.',
      [VampireLabel(2, AStory), StockText(2), FeedEvery]) + RulesBreak +
    'Special cards are the answer to the tricks: Wild card or Wood Stake for chains, Wood Stake for a bite, Seer''s eye to see the marks early, Full deck for hunger.';
end;

function BodyCross(AStory: TStory): string;
begin
  Result :=
    Format('In the duel against %s, and again in the duel against %s, a silver cross lies on the table once, in one of the first three games of that duel. It is never in the last two games.',
      [AStory.Name(1), AStory.Name(2)]) + RulesBreak +
    'It is drawn on one card. If the card is face down you cannot see it, but the panel tells you a cross is on the table, and the Store is open until your first move, so you can buy a Wild card first.' + RulesBreak +
    'Only a Wild card claims it: use the Wild card on the cross card. Playing that card as an ordinary move, or using a Wood Stake on it, destroys the cross. The game asks before it lets you play it as an ordinary card.' + RulesBreak +
    Format('Once claimed, from the next hand on the vampire plays like %s: a full stock, King and Ace wrap, and no trick. The pay stays the same. For %s it lasts until the duel ends. For %s it lasts %d hands, won or lost (the hand you claim it in does not count).',
      [AStory.Name(0), AStory.Name(1), AStory.Name(2), VampireEaseHands[2]]) + RulesBreak +
    'If you lose the game that carries the cross, the next deal still has it, in a new place.';
end;

function BodySaving(AStory: TStory): string;
begin
  Result :=
    'The game saves your hand after every move, and your coins and cards as soon as they change. Close it at any time: next time it opens where you left off.' + RulesBreak +
    Format('The Menu button opens the start menu. From there you can Save game or Load game into one of %d slots for each mode. ', [SlotCount]) +
    'Loading a Campaign slot takes your campaign back to that moment, including your coins and cards.' + RulesBreak +
    'Start over lets you restart the Campaign only, or erase everything.';
end;

function BodyTrophies(AStory: TStory): string;
var
  T: TTrophy;
  List: string;
begin
  List := '';
  for T := Low(TTrophy) to High(TTrophy) do
  begin
    if List <> '' then List := List + RulesBreak;
    List := List + AStory.TrophyName(TrophyKeys[T]) + ': ' + AStory.TrophyHow(TrophyKeys[T]);
  end;
  Result :=
    'Trophies are keepsakes you earn by playing, and they are always earned the same way: nothing about them is random.' + RulesBreak +
    List + RulesBreak +
    'They sit on a shelf at the foot of the side panel: a small picture for each one you have, and an empty tile for the rest. Tap the shelf to see their names and what each one says. On a narrow screen the shelf is a single Trophies button.' + RulesBreak +
    'Starting the Campaign again keeps your trophies. Only Erase everything clears them.' + RulesBreak +
    'Trophies you already deserved from your earlier wins and kills were put on the shelf the first time the game started with trophies. The flawless trophy is only earned in a run that is played from the start.';
end;

function BodyFree(AStory: TStory): string;
begin
  Result :=
    Format('Free Play is plain Tri Peaks with no vampires. Clearing a hand pays %d coins, %d undo card and %d hint cards, less %d coins for every missed move.',
      [WinCoins, WinUndoCards, WinHintCards, MissPenaltyCoins]) + RulesBreak +
    'The Store charges list prices in Free Play.' + RulesBreak +
    'The Records button keeps your personal bests: longest streaks, wins in a row, perfect hands and, in the Campaign, your fewest lost hands against each vampire. ' +
    'When you break a record you can type your initials.';
end;

function RulesBody(I: Integer; AStory: TStory): string;
begin
  case I of
    0: Result := 'Tri Peaks is played with one deck. Clear all 28 cards from the three peaks to win the hand.' + RulesBreak +
         'Three pyramids of cards stand on the table. Below them is a stock pile you draw from, and a waste pile you play onto.';
    1: Result := BodyPlaying(AStory);
    2: Result := BodyDrawing(AStory);
    3: Result := BodyWinLose(AStory);
    4: Result := BodyUndoHint(AStory);
    5: Result := BodyStore(AStory);
    6: Result := BodyCampaign(AStory);
    7: Result := BodyVampires(AStory);
    8: Result := BodyCross(AStory);
    9: Result := BodySaving(AStory);
    10: Result := BodyTrophies(AStory);
  else
    Result := BodyFree(AStory);
  end;
end;

function RulesPlainText(AStory: TStory): string;
var
  I, P: Integer;
  B, Para: string;
begin
  Result := '';
  for I := 0 to Sections - 1 do
  begin
    if Result <> '' then Result := Result + LineEnding + LineEnding;
    Result := Result + UpperCase(RulesHeading(I, AStory)) + LineEnding;
    B := RulesBody(I, AStory);
    while B <> '' do
    begin
      P := Pos(RulesBreak, B);
      if P = 0 then
      begin
        Para := B;
        B := '';
      end
      else
      begin
        Para := Copy(B, 1, P - 1);
        B := Copy(B, P + 1, Length(B));
      end;
      Result := Result + LineEnding + Para + LineEnding;
    end;
  end;
end;

end.
