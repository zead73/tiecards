unit Session;

{ Ties a Tri Peaks game to the player's inventory and decides what the player
  is allowed to do (undo and hints cost cards, wins pay rewards). No UI code,
  so every rule here can be tested without a window. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Cards, TriPeaks, Inventory, Specials, Relics;

type
  { A hand as it can be saved: the cards (and undo) plus the session's own
    counters for it. }
  TSavedHand = record
    Game: THandData;
    Misses: Integer;
    Bites: Integer;               { bitten cards played (Lucien's trick) }
    ForgivenBite: Integer;        { which bite the Garlic Wreath forgave (1 = the first of the hand), 0 = none yet }
    ForgivenMiss: Integer;        { which missed move the Steady Locket forgave, 0 = none yet }
    FreeHintUsed: Boolean;        { the Moonstone's free Show move was already used }
  end;

  { A Free Play hand was won (and paid): its longest streak and missed moves. }
  TWonEvent = procedure(BestStreak, Misses: Integer) of object;
  { Asked whenever the relics in use are needed: what is equipped now (bits, see Relics). }
  TRelicsEvent = function: Integer of object;

  THintResult = (
    hrShown,          { hint card spent, playable cards are now highlighted }
    hrAlreadyShown,   { already showing; nothing spent }
    hrNoMoves,        { nothing playable: hint card IS spent, UI plays the "no" sound }
    hrNoHintCards);   { player has no hint cards; nothing happens }

  TGameSession = class
  private
    FGame: TTriPeaksGame;
    FInventory: TPlayerInventory;
    FFile: string;
    FHintActive: Boolean;
    FRewarded: Boolean;
    FPayWinRewards: Boolean;
    FWrapRanks: Boolean;
    FStockSize: Integer;
    FMisses: Integer;
    FBites: Integer;
    FHazard: THazard;            { the trick for the hands dealt from now on }
    FHazardsOn: Boolean;
    FMissedLast: Boolean;        { the last draw was a missed move }
    FTouched: Boolean;           { a card has been played or drawn in this hand }
    FRelicProvider: TRelicsEvent;
    FRelics: Integer;            { the relics equipped (used when there is no provider) }
    FForgivenBite: Integer;      { the bite the Garlic Wreath forgave: the first taken while it was equipped }
    FForgivenMiss: Integer;      { the missed move the Steady Locket forgave }
    FFreeHintUsed: Boolean;
    FCrossClaimed: Boolean;      { a Wild card just took the silver cross: the duel has to hear of it }
    FRestored: Boolean;          { a saved hand was just put back and nothing has been done since }
    FOver: Boolean;              { the hand is finished (lost or given up) }
    FNote: string;
    FOnWon: TWonEvent;
    function GetRelics: Integer;
    function RawCanUndo: Boolean;
    function SpecialRescue: Boolean;
    procedure AfterSpecial;
    procedure CheckStuck;
    procedure SyncRelics;
    procedure Save;
    procedure CheckWin;
  public
    { InventoryFile = '' means do not load or save (used by tests). }
    constructor Create(const AInventoryFile: string);
    destructor Destroy; override;
    { The rules for the hands dealt from now on (a hand already dealt, or loaded
      from a save, keeps its own). Free Play is the ordinary rules: King and Ace
      are neighbours and the stock has FullStock cards. }
    procedure SetRules(AWrap: Boolean; AStockSize: Integer; AHazard: THazard = hzNone);
    property WrapRanks: Boolean read FWrapRanks;
    property StockSize: Integer read FStockSize;
    { The silver cross (see Campaign): lay it under a random peak card of the hand
      just dealt. A Wild card played on it claims it; any other play (or a Wood
      Stake) destroys it. }
    { ---- relics (see Relics) ---- }
    { Relics work the moment they are equipped, in the hand on the table too. What a
      hand has already used (the Pick's break, the Moonstone's hint, the bite and the
      miss that were forgiven) stays used however the relics are changed. }
    procedure SetRelics(AMask: Integer);       { equip or remove: tell the game }
    property Relics: Integer read GetRelics write SetRelics;
    property RelicProvider: TRelicsEvent read FRelicProvider write FRelicProvider;
    { Missed moves and bitten cards as they are charged: the Steady Locket and the
      Garlic Wreath forgive the first of each that happens while they are equipped. The
      raw counts (Misses, Bites) are what Records and the panel show. }
    function ChargedMisses: Integer;
    function ChargedBites: Integer;
    function FreeHintAvailable: Boolean;       { the Moonstone's free Show move is still to come }
    function PlaceCross: Boolean;
    function TakeCrossClaim: Boolean;        { True once after a Wild card claimed it }
    procedure SetNote(const AText: string);
    property Hazard: THazard read FHazard;
    { Tests switch the vampires' tricks off so that a rigged hand is not spoiled by
      marks put in random places. }
    property HazardsOn: Boolean read FHazardsOn write FHazardsOn;
    procedure NewGame;                       { shuffled deal }
    procedure NewGameFrom(ADeck: TDeck);     { caller-supplied deal (tests) }

    function Play(I: Integer): Boolean;
    function DrawStock: Boolean;
    function UseUndo: Boolean;               { takes back one move; costs an undo card each }
    function UseHint: THintResult;
    function BuyUndoPack: Boolean;
    function BuyHintPack: Boolean;
    { Special cards (see Specials). Buying follows the shop rule (CanShop). A
      card is usable when you own one, it would do something now (it is shown
      greyed out otherwise: Open wrap in a game that already wraps, a Full deck
      with no unused cards, ...), and the hand is still alive. Using one starts
      the hand (the shop shuts) and forgets the undo. }
    function BuySpecial(K: TSpecialKind): Boolean;
    function SpecialApplicable(K: TSpecialKind): Boolean;
    function CanUseSpecial(K: TSpecialKind): Boolean;
    function UseSpecial(K: TSpecialKind): Boolean;           { the kinds that need no target }
    function UseSpecialOn(K: TSpecialKind; I: Integer): Boolean;   { Wild card, Wood Stake }
    { Is there still something that could save a stuck hand: an undo, or a
      special card that would open a move? Then the hand is not lost yet. }
    function HasRescue: Boolean;

    function CanUseUndo: Boolean;
    { Cards can only be bought between hands: once a hand is won, lost or
      given up, and on a fresh deal until the first card is played or drawn.
      In the middle of a hand the shop is shut, so a pack can't rescue it.
      Being stuck with no undo card to use ends the hand (it cannot be undone
      afterwards, even if a pack is bought). }
    function CanShop: Boolean;
    { The hand is finished, whatever the reason (the duel gave it up). }
    procedure EndHand;
    property HandOver: Boolean read FOver;
    { True if a playable card should be drawn highlighted. }
    function IsHinted(I: Integer): Boolean;

    property Game: TTriPeaksGame read FGame;
    property Inventory: TPlayerInventory read FInventory;
    property HintActive: Boolean read FHintActive;
    property Note: string read FNote;        { one-line message for the status bar }
    { Free Play pays the flat win reward. A campaign duel turns this off and
      pays its own spoils instead. }
    property PayWinRewards: Boolean read FPayWinRewards write FPayWinRewards;
    { Called once when a hand is won and its reward paid (never for a hand that
      already paid, and not in a duel, which has its own event). }
    property OnWon: TWonEvent read FOnWon write FOnWon;
    { A card has been played or drawn (or a special card used) in this hand. }
    function HandStarted: Boolean;
    procedure SaveNow;                        { write the inventory to disk now }
    { A missed move is drawing from the stock while a card on the table could
      have been played. Each one cuts a little off this hand's reward. Taking
      back the draw (undo) takes the miss back too. }
    property Misses: Integer read FMisses;               { in this hand }
    property Bites: Integer read FBites;                 { bitten cards played in this hand }
    property MissedLast: Boolean read FMissedLast;       { was the last draw a miss? }
    { What winning this hand would pay now (Free Play). }
    function PayoutNow: Integer;
    { Capture this hand, or put a saved one back (False, changing nothing, if it
      is not a believable hand). Your coins and cards are not part of a hand. }
    procedure ExportHand(out H: TSavedHand);
    function ImportHand(const H: TSavedHand): Boolean;
  end;

implementation

constructor TGameSession.Create(const AInventoryFile: string);
begin
  inherited Create;
  FFile := AInventoryFile;
  FPayWinRewards := True;
  FWrapRanks := True;
  FStockSize := FullStock;
  FHazardsOn := True;
  FGame := TTriPeaksGame.Create;
  FInventory := TPlayerInventory.Create;
  if FFile <> '' then FInventory.LoadFromFile(FFile);
end;

destructor TGameSession.Destroy;
begin
  Save;
  FInventory.Free;
  FGame.Free;
  inherited Destroy;
end;

procedure TGameSession.Save;
begin
  if FFile <> '' then FInventory.SaveToFile(FFile);
end;

procedure TGameSession.SaveNow;
begin
  Save;
end;

procedure TGameSession.SetRules(AWrap: Boolean; AStockSize: Integer; AHazard: THazard);
begin
  FWrapRanks := AWrap;
  FStockSize := AStockSize;
  FHazard := AHazard;
end;

{ What is equipped now. }
function TGameSession.GetRelics: Integer;
begin
  if Assigned(FRelicProvider) then FRelics := FRelicProvider();
  if not ValidRelicMask(FRelics) then FRelics := 0;
  Result := FRelics;
end;

procedure TGameSession.SetRelics(AMask: Integer);
begin
  if not ValidRelicMask(AMask) then AMask := 0;
  FRelics := AMask;
  SyncRelics;
  if not FOver and not FGame.IsWon then CheckStuck;   { taking the Pick out can leave the hand with no move }
end;

{ Put the equipped relics into effect: the Spoon and the Pick change the game's rules. }
procedure TGameSession.SyncRelics;
var
  R: Integer;
begin
  R := GetRelics;
  FGame.SetRelicRules(HasRelic(R, rlSpoon), HasRelic(R, rlPick));
end;

function TGameSession.ChargedMisses: Integer;
begin
  Result := FMisses;
  if (FForgivenMiss > 0) and (FForgivenMiss <= FMisses) then Dec(Result);
end;

function TGameSession.ChargedBites: Integer;
begin
  Result := FBites;
  if (FForgivenBite > 0) and (FForgivenBite <= FBites) then Dec(Result);
end;

function TGameSession.FreeHintAvailable: Boolean;
begin
  Result := HasRelic(GetRelics, rlMoonstone) and not FFreeHintUsed and not FGame.IsWon;
end;

function TGameSession.PlaceCross: Boolean;
begin
  Result := FGame.PlaceCross >= 0;
end;

function TGameSession.TakeCrossClaim: Boolean;
begin
  Result := FCrossClaimed;
  FCrossClaimed := False;
end;

procedure TGameSession.SetNote(const AText: string);
begin
  FNote := AText;
end;

procedure TGameSession.NewGame;
var
  D: TDeck;
begin
  D := TDeck.Create;
  try
    D.Shuffle;
    NewGameFrom(D);
  finally
    D.Free;
  end;
end;

procedure TGameSession.NewGameFrom(ADeck: TDeck);
begin
  FGame.WrapRanks := FWrapRanks;
  FGame.Deal(ADeck, FStockSize);
  if FHazardsOn then FGame.SetHazard(FHazard);
  SyncRelics;
  FFreeHintUsed := False;
  FForgivenBite := 0;
  FForgivenMiss := 0;
  FMisses := 0;
  FBites := 0;
  FCrossClaimed := False;
  FMissedLast := False;
  FHintActive := False;
  FRewarded := False;
  FTouched := False;
  FRestored := False;
  FOver := False;
  FNote := '';
end;

procedure TGameSession.CheckWin;
begin
  if FGame.IsWon and not FRewarded then
  begin
    FRewarded := True;
    if not FPayWinRewards then Exit;
    if FInventory.HandPaid(FGame.HandId) then
    begin
      { a saved hand won a second time: the reward was already collected }
      FNote := 'YOU WIN!  You already collected the reward for this hand.';
      Exit;
    end;
    FInventory.MarkHandPaid(FGame.HandId);
    FInventory.AddCoins(PayoutNow);
    FInventory.AddUndoCards(WinUndoCards);
    FInventory.AddHintCards(WinHintCards);
    Save;
    if Assigned(FOnWon) then FOnWon(FGame.BestStreak, FMisses);
    FNote := Format('YOU WIN!  +%d coins, +%d undo, +%d hint cards.',
      [PayoutNow, WinUndoCards, WinHintCards]);
  end;
end;

procedure TGameSession.ExportHand(out H: TSavedHand);
begin
  FGame.GetState(H.Game);
  H.Misses := FMisses;
  H.Bites := FBites;
  H.ForgivenBite := FForgivenBite;
  H.ForgivenMiss := FForgivenMiss;
  H.FreeHintUsed := FFreeHintUsed;
end;

function TGameSession.ImportHand(const H: TSavedHand): Boolean;
begin
  Result := (H.Misses >= 0) and (H.Bites >= 0)
    and (H.ForgivenBite >= 0) and (H.ForgivenBite <= H.Bites)
    and (H.ForgivenMiss >= 0) and (H.ForgivenMiss <= H.Misses)
    and FGame.SetState(H.Game);
  if not Result then Exit;
  FMisses := H.Misses;
  FBites := H.Bites;
  FForgivenBite := H.ForgivenBite;
  FForgivenMiss := H.ForgivenMiss;
  SyncRelics;                                 { the relics equipped now, not the ones it was saved with }
  FFreeHintUsed := H.FreeHintUsed;
  FMissedLast := False;
  FHintActive := False;
  FRewarded := False;
  FTouched := FGame.WasteCount > 1;           { a card has been played or drawn }
  FRestored := True;                          { until the first move, the shop is open again }
  FOver := False;
  CheckStuck;
  FNote := '';
end;

function TGameSession.PayoutNow: Integer;
begin
  Result := RewardAfterCuts(WinCoins, ChargedMisses, ChargedBites);
end;

function TGameSession.Play(I: Integer): Boolean;
var
  Bite, Cross: Boolean;
begin
  Bite := FGame.Mark(I) = MarkBitten;
  Cross := FGame.Mark(I) = MarkCross;
  Result := FGame.PlayTableau(I);
  if not Result then Exit;
  if Bite then
  begin
    Inc(FBites);                          { the bite takes coins off this hand's reward }
    if (FForgivenBite = 0) and HasRelic(GetRelics, rlGarlic) then FForgivenBite := FBites;
  end;
  FMissedLast := False;
  FHintActive := False;
  FTouched := True;
  FRestored := False;
  FNote := '';
  if Bite then FNote := Format('Bitten! That cost %d coins.', [BitePenaltyCoins]);
  if Cross then FNote := 'The silver cross crumbles to dust. Only a Wild card could have claimed it.';
  CheckWin;
  CheckStuck;
end;

function TGameSession.DrawStock: Boolean;
var
  Missed: Boolean;
begin
  Missed := FGame.HasMoves;            { a card could have been played instead }
  Result := FGame.DrawStock;
  if not Result then Exit;
  FMissedLast := Missed;
  if Missed then
  begin
    Inc(FMisses);
    if (FForgivenMiss = 0) and HasRelic(GetRelics, rlLocket) then FForgivenMiss := FMisses;
  end;
  FHintActive := False;
  FTouched := True;
  FRestored := False;
  FNote := '';
  if FGame.LastMoveAte then FNote := 'The Count feeds: a card of the stock is gone.';
  CheckStuck;
end;

function TGameSession.RawCanUndo: Boolean;
begin
  Result := FGame.CanUndo and (FInventory.UndoCards > 0);
end;

function TGameSession.CanUseUndo: Boolean;
begin
  Result := RawCanUndo and not FOver;
end;

{ A special card that would give a stuck hand something to do. (Seer's eye
  would not.) }
function TGameSession.HandStarted: Boolean;
begin
  Result := FTouched;
end;

function TGameSession.SpecialRescue: Boolean;
var
  K: TSpecialKind;
begin
  Result := False;
  for K := Low(TSpecialKind) to High(TSpecialKind) do
    if (K <> skSeer) and (FInventory.SpecialCards(K) > 0) and SpecialApplicable(K) then
      Exit(True);
end;

function TGameSession.HasRescue: Boolean;
begin
  Result := RawCanUndo or SpecialRescue;
end;

{ Stuck with nothing that could help: the hand is over for good. }
procedure TGameSession.CheckStuck;
begin
  if FGame.IsStuck and not HasRescue then FOver := True;
end;

function TGameSession.SpecialApplicable(K: TSpecialKind): Boolean;
begin
  case K of
    skFullDeck: Result := FGame.CanRestoreStock;
    skOpenWrap: Result := FGame.CanOpenWrap;
    skDawn: Result := FGame.CanRestoreStock or FGame.CanOpenWrap;
    skWild, skStake: Result := FGame.HasFreeCard and not FGame.IsWon;
    skSeer: Result := FGame.CanReveal;
  else
    Result := False;
  end;
end;

function TGameSession.CanUseSpecial(K: TSpecialKind): Boolean;
begin
  Result := not FOver and not FGame.IsWon and (FInventory.SpecialCards(K) > 0)
    and SpecialApplicable(K);
end;

procedure TGameSession.AfterSpecial;
begin
  FTouched := True;                        { the hand is under way: the shop shuts }
  FRestored := False;
  FHintActive := False;
  FMissedLast := False;
  Save;
  CheckWin;
  CheckStuck;
end;

function TGameSession.UseSpecial(K: TSpecialKind): Boolean;
begin
  Result := CanUseSpecial(K) and not NeedsTarget(K);
  if not Result then Exit;
  case K of
    skFullDeck: FGame.RestoreStock;
    skOpenWrap: FGame.OpenWrap;
    skDawn:
    begin
      FGame.RestoreStock;                  { each half only if it has something to do }
      FGame.OpenWrap;
    end;
    skSeer: FGame.Reveal;
  end;
  FInventory.UseSpecialCard(K);
  FNote := SpecialName[K] + ' used.';
  AfterSpecial;
end;

function TGameSession.UseSpecialOn(K: TSpecialKind; I: Integer): Boolean;
var
  Cross: Boolean;
begin
  Result := CanUseSpecial(K) and NeedsTarget(K);
  if not Result then Exit;
  Cross := FGame.Mark(I) = MarkCross;
  case K of
    skWild: Result := FGame.PlayWild(I);
    skStake: Result := FGame.Stake(I);
  end;
  if not Result then Exit;                 { not a free card: the card is kept }
  FInventory.UseSpecialCard(K);
  FNote := '';
  if Cross and (K = skWild) then FCrossClaimed := True;
  AfterSpecial;
  if FNote = '' then
  begin
    if Cross and (K = skStake) then
      FNote := 'The Wood Stake splinters the silver cross. Only a Wild card could have claimed it.'
    else
      FNote := SpecialName[K] + ' used.';
  end;
end;

function TGameSession.BuySpecial(K: TSpecialKind): Boolean;
begin
  Result := CanShop and FInventory.BuySpecial(K);
  if Result then
  begin
    Save;
    FNote := Format('Bought a %s.', [SpecialName[K]]);
  end;
end;

function TGameSession.CanShop: Boolean;
begin
  Result := FGame.IsWon or FOver or not FTouched or FRestored;
end;

procedure TGameSession.EndHand;
begin
  FOver := True;
end;

function TGameSession.UseUndo: Boolean;
var
  Missed, Bitten: Boolean;
begin
  Result := CanUseUndo;        { check both first so a card is never wasted }
  if not Result then Exit;
  FInventory.UseUndoCard;
  FRestored := False;                      { the hand has changed: the shop shuts }
  Missed := FGame.LastMoveMissed;
  Bitten := FGame.LastMoveBitten;
  FGame.Undo;
  if Missed and (FMisses > 0) then               { the miss is taken back, and its forgiveness with it }
  begin
    if FMisses = FForgivenMiss then FForgivenMiss := 0;
    Dec(FMisses);
  end;
  if Bitten and (FBites > 0) then                { and so is the bite }
  begin
    if FBites = FForgivenBite then FForgivenBite := 0;
    Dec(FBites);
  end;
  FMissedLast := False;
  FHintActive := False;
  FNote := '';
  Save;
  CheckStuck;
end;

function TGameSession.UseHint: THintResult;
begin
  if FHintActive then
    Result := hrAlreadyShown
  else if FGame.IsWon then
    Result := hrNoMoves                       { game over: nothing to show, nothing spent }
  else if (FInventory.HintCards <= 0) and not FreeHintAvailable then
    Result := hrNoHintCards
  else
  begin
    if FreeHintAvailable then FFreeHintUsed := True      { the Moonstone's: no card used }
    else FInventory.UseHintCard;              { spent whether or not there is a move }
    Save;
    if FGame.HasMoves then
    begin
      FHintActive := True;
      Result := hrShown;
    end
    else
      Result := hrNoMoves;
  end;
end;

function TGameSession.IsHinted(I: Integer): Boolean;
begin
  Result := FHintActive and FGame.CanPlay(I);
end;

function TGameSession.BuyUndoPack: Boolean;
begin
  Result := CanShop and FInventory.BuyUndoPack;
  if Result then
  begin
    Save;
    FNote := Format('Bought %d undo cards.', [UndoPackSize]);
  end;
end;

function TGameSession.BuyHintPack: Boolean;
begin
  Result := CanShop and FInventory.BuyHintPack;
  if Result then
  begin
    Save;
    FNote := Format('Bought %d hint cards.', [HintPackSize]);
  end;
end;

end.
