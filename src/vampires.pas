unit Vampires;

{ The fixed facts about the three vampires of the campaign. The words they say
  live in assets/story/story.ini (see Story); the numbers that affect play live
  here. Order = the order you fight them. }

{$mode objfpc}{$H+}

interface

uses
  TriPeaks;

const
  VampireCount = 3;
  { Section name in the story file for each vampire. }
  VampireKey: array[0..VampireCount - 1] of string = ('jack', 'queen', 'king');
  { The court card each one wears (11 = Jack, 12 = Queen, 13 = King). }
  VampireCardRank: array[0..VampireCount - 1] of Integer = (11, 12, 13);
  { The pictures of the vampires shown in the scenes: 0..2 are the three of them,
    3..5 the same with blood on his fangs, 6..8 with a goblet of your blood (what
    he does after a lost hand). }
  PortraitCount = VampireCount * 3;
  { Won hands it takes to kill a vampire. }
  WinsToKill = 5;
  { Coins each won hand pays when you did not lose a hand first. Jack plays the
    ordinary rules, so he pays close to a Free Play win (25); each later
    vampire pays more because his hands are harder to win. }
  VampireWinCoins: array[0..VampireCount - 1] of Integer = (20, 30, 40);
  { What the killing (fifth) win adds on top; never cut by lost hands or
    missed moves. }
  VampireKillBonus: array[0..VampireCount - 1] of Integer = (30, 45, 60);
  { How hard each vampire's hands are (difficulty levels 1..3, Jack to King).
    Free Play and the first level are the ordinary rules. Two things change:
    whether King and Ace count as neighbours, and how many cards the stock has
    (23 is the full stock; fewer means fewer draws, a harder hand). Measured on
    random deals with perfect play, about 98% / 82% / 58% could be won before
    the tricks below (a simple "play the card that uncovers most" player won about
    53% / 20% / 12%); with the tricks, see VampireHazard. The King's stock is back
    to full now that his hunger eats it, and Dawn still has work to do at his
    table (no wrap, and a stock to refill). }
  VampireWrapRanks: array[0..VampireCount - 1] of Boolean = (True, True, False);
  VampireStockCards: array[0..VampireCount - 1] of Integer = (23, 20, 23);
  { Each vampire's trick in the middle of a hand (see THazard in TriPeaks):
    Lucien bites, Carmilla chains, Alaric starves you of cards. Measured with
    perfect play on random deals: Lucien's hands stay 98% winnable (a bite only
    costs coins); Carmilla's (wrap, 20 stock cards, 3 chained cards) 76%;
    Alaric's (no wrap, 23 stock cards, hunger every 4th draw) 48%. A plain
    "play the card that uncovers most" player wins about 52% / 18% / 8%. The special
    cards are the answers: Wood Stake or Wild card for a chained card, Wood Stake
    for a bitten one, Seer's eye to see the marks early, Full deck to refill
    what he ate. }
  VampireHazard: array[0..VampireCount - 1] of THazard = (hzBitten, hzChained, hzHunger);
  { What the Store charges while you face each vampire, as a percentage of the
    list prices: the early levels are cheaper. Free Play, and the campaign once
    it is won, pay the list price. }
  VampirePricePercent: array[0..VampireCount - 1] of Integer = (50, 60, 75);
  { How long the silver cross (the Easy-Vampire card) weakens each vampire once a
    Wild card has claimed it: -1 = until he falls, otherwise that many hands (won
    or lost). Jack never carries one. A weakened vampire plays Jack's hands:
    wrap on, the full stock and no trick. }
  VampireEaseHands: array[0..VampireCount - 1] of Integer = (0, -1, 2);
  { Hint cards each of the first four wins gives (the kill gives the full
    set: WinUndoCards and WinHintCards in Inventory). }
  HitHintCards = 1;

{ The picture of vampire V drinking: Variant 0 = blood on his fangs, 1 = the goblet. }
function BleedPortrait(V, Variant: Integer): Integer;
{ The image's name (as in assets/vampires and the embedded resources). }
function PortraitName(P: Integer): string;

{ The first vampire whose hands have no wrap (VampireCount if none). The Open
  wrap card is only worth buying from there on. }
function FirstNoWrapVampire: Integer;
{ The first vampire whose hands have a smaller stock: from there on a Full deck
  has cards to add. }
function FirstSmallStockVampire: Integer;

implementation

function BleedPortrait(V, Variant: Integer): Integer;
begin
  Result := V + VampireCount * (1 + (Variant and 1));
end;

function PortraitName(P: Integer): string;
begin
  Result := 'vampire_' + VampireKey[P mod VampireCount];
  case P div VampireCount of
    1: Result := Result + '_fangs';
    2: Result := Result + '_cup';
  end;
end;

function FirstNoWrapVampire: Integer;
var
  V: Integer;
begin
  Result := VampireCount;
  for V := VampireCount - 1 downto 0 do
    if not VampireWrapRanks[V] then Result := V;
end;

function FirstSmallStockVampire: Integer;
var
  V: Integer;
begin
  Result := VampireCount;
  for V := VampireCount - 1 downto 0 do
    if VampireStockCards[V] < 23 then Result := V;      { 23 = the full stock }
end;

end.
