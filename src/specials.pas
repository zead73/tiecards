unit Specials;

{ The special cards sold in the Store. No window code. A special card changes
  the hand you are playing (never the deal: nothing here gives a new shuffle),
  is bought one at a time at a fixed price, and any number may be used in a hand.
  What each one does to the cards is in TriPeaks (RestoreStock, OpenWrap, ...);
  who owns how many is in Inventory; the rules for using one are in Session. }

{$mode objfpc}{$H+}

interface

type
  TSpecialKind = (
    skFullDeck,     { the deal's unused cards join the stock }
    skOpenWrap,     { King and Ace become neighbours }
    skDawn,         { both of the above: the "lowest level" card }
    skWild,         { play any free card onto the waste }
    skSeer,         { show every face-down card }
    skStake);       { destroy any free card }

const
  SpecialCount = 6;

  { Fixed prices in coins. Measured on simulated hands (a player who plays the
    card that uncovers most, and uses a card when stuck): Full deck and Open
    wrap each add about 30 points of win chance where they apply (and nothing
    elsewhere), so they are the cheapest; Wild card and Wood Stake add about 25
    anywhere (the Wild card a little more, so they cost the same); Dawn does
    both softenings in one card for less than the two; the Seer's eye changes
    no cards, it only lets you plan. }
  SpecialPrice: array[TSpecialKind] of Integer = (25, 25, 45, 35, 30, 35);

  { Names used in the save file and the story file (lower case, no spaces). }
  SpecialKey: array[TSpecialKind] of string =
    ('fulldeck', 'openwrap', 'dawn', 'wild', 'seer', 'stake');

  SpecialName: array[TSpecialKind] of string =
    ('Full deck', 'Open wrap', 'Dawn', 'Wild card', 'Seer''s eye', 'Wood Stake');

  { One line for the Store and the card tray. }
  SpecialInfo: array[TSpecialKind] of string = (
    'Puts the unused cards of the deal into the stock.',
    'King and Ace count as neighbours this hand.',
    'Full deck and Open wrap in one: the gentlest rules.',
    'Play any free card onto the waste, whatever its rank.',
    'Turns every face-down card face up this hand.',
    'Destroy any free card. The waste stays as it is.');

{ Wild card and Wood Stake need the player to pick a card on the table. }
function NeedsTarget(K: TSpecialKind): Boolean;

implementation

function NeedsTarget(K: TSpecialKind): Boolean;
begin
  Result := K in [skWild, skStake];
end;

end.
