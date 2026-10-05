import {
  findDrawTarget,
  type GameActionSummary,
  type GameCard,
  type PlayerProfile,
  type RoomState,
} from "./lobby.ts";
import {
  applyRoundScores,
  removePairs,
  shuffleCards,
  type RandomSource,
} from "./round-rules.ts";

export type { RandomSource } from "./round-rules.ts";

export type GameErrorCode =
  | "not_room_creator"
  | "not_enough_players"
  | "invalid_game_phase"
  | "not_your_turn"
  | "invalid_draw_target"
  | "invalid_card_index"
  | "player_not_found";

export type GameResult =
  | { readonly ok: true; readonly state: RoomState }
  | { readonly ok: false; readonly code: GameErrorCode; readonly message: string };

const SUITS = ["hearts", "diamonds", "clubs", "spades"] as const;

export function startGame(
  state: RoomState,
  actorUserId: string,
  now: string,
  random: RandomSource = Math.random,
): GameResult {
  if (state.phase !== "lobby") return invalidPhase();
  if (state.creatorUserId !== actorUserId) {
    return { ok: false, code: "not_room_creator", message: "Only the room creator can start." };
  }
  if (state.players.length < 2 || state.players.some((player) => !player.connected)) {
    return {
      ok: false,
      code: "not_enough_players",
      message: "At least two seated players must be connected.",
    };
  }
  return {
    ok: true,
    state: dealRound(state, actorUserId, "game_started", state.roundNumber, now, random),
  };
}

export function drawCard(
  state: RoomState,
  actorUserId: string,
  targetUserId: string,
  cardIndex: number,
  now: string,
  random: RandomSource = Math.random,
): GameResult {
  if (state.phase !== "playing") return invalidPhase();
  const current = state.players[state.currentPlayerIndex];
  if (current?.userId !== actorUserId) {
    return { ok: false, code: "not_your_turn", message: "It is not your turn." };
  }
  const target = findDrawTarget(state);
  if (target?.userId !== targetUserId) {
    return {
      ok: false,
      code: "invalid_draw_target",
      message: "You must draw from the previous active player.",
    };
  }
  if (!Number.isInteger(cardIndex) || cardIndex < 0 || cardIndex >= target.hand.length) {
    return { ok: false, code: "invalid_card_index", message: "That card position is invalid." };
  }

  const drawnCard = target.hand[cardIndex];
  if (drawnCard === undefined) {
    return { ok: false, code: "invalid_card_index", message: "That card position is invalid." };
  }
  const targetHand = [...target.hand];
  targetHand.splice(cardIndex, 1);
  const drawerHand = [...current.hand, drawnCard];
  const matchIndex = current.hand.findIndex((card) => card.rank === drawnCard.rank);
  const madePair = matchIndex >= 0;
  if (madePair) {
    drawerHand.splice(drawerHand.findIndex((card) => card.id === drawnCard.id), 1);
    const matchedId = current.hand[matchIndex]!.id;
    drawerHand.splice(drawerHand.findIndex((card) => card.id === matchedId), 1);
  }
  shuffleCards(drawerHand, random);

  let nextFinishPosition = state.nextFinishPosition;
  let players = state.players.map((player) => {
    const hand = player.userId === current.userId
      ? drawerHand
      : player.userId === target.userId
        ? targetHand
        : player.hand;
    if (player.status === "playing" && hand.length === 0) {
      return { ...player, hand, status: "finished" as const, finishPosition: nextFinishPosition++ };
    }
    return hand === player.hand ? player : { ...player, hand };
  });

  const stillPlaying = players.filter((player) => player.status === "playing");
  let phase: RoomState["phase"] = "playing";
  if (stillPlaying.length <= 1) {
    if (stillPlaying[0] !== undefined) {
      players = players.map((player) =>
        player.userId === stillPlaying[0]?.userId
          ? { ...player, status: "shayeb" as const, finishPosition: nextFinishPosition }
          : player,
      );
    }
    players = applyRoundScores(players);
    phase = "round_end";
  }

  const lastAction: GameActionSummary = {
    type: "card_drawn",
    actorUserId,
    targetUserId,
    madePair,
    drawnCard,
  };
  const nextPlayerIndex = phase === "playing"
    ? findNextConnectedPlayerIndex(players, state.currentPlayerIndex)
    : state.currentPlayerIndex;
  return {
    ok: true,
    state: {
      ...state,
      players,
      phase,
      currentPlayerIndex: nextPlayerIndex,
      nextFinishPosition,
      lastAction,
      stateVersion: state.stateVersion + 1,
      updatedAt: now,
    },
  };
}

export function shuffleHand(
  state: RoomState,
  actorUserId: string,
  now: string,
  random: RandomSource = Math.random,
): GameResult {
  if (state.phase !== "playing") return invalidPhase();
  const playerIndex = state.players.findIndex((player) => player.userId === actorUserId);
  if (playerIndex < 0) {
    return { ok: false, code: "player_not_found", message: "Player is not in this room." };
  }
  const hand = [...state.players[playerIndex]!.hand];
  shuffleCards(hand, random);
  const players = state.players.map((player, index) =>
    index === playerIndex ? { ...player, hand } : player,
  );
  return {
    ok: true,
    state: mutate(state, players, { type: "hand_shuffled", actorUserId }, now),
  };
}

export function startNewRound(
  state: RoomState,
  actorUserId: string,
  now: string,
  random: RandomSource = Math.random,
): GameResult {
  if (state.phase !== "round_end") return invalidPhase();
  if (state.creatorUserId !== actorUserId) {
    return { ok: false, code: "not_room_creator", message: "Only the room creator can start a new round." };
  }
  if (state.players.length < 2 || state.players.some((player) => !player.connected)) {
    return {
      ok: false,
      code: "not_enough_players",
      message: "All seated players must reconnect before the next round.",
    };
  }
  return {
    ok: true,
    state: dealRound(state, actorUserId, "round_started", state.roundNumber + 1, now, random),
  };
}

function dealRound(
  state: RoomState,
  actorUserId: string,
  actionType: "game_started" | "round_started",
  roundNumber: number,
  now: string,
  random: RandomSource,
): RoomState {
  const deck = createDeck(random);
  shuffleCards(deck, random);
  const hands = state.players.map((): GameCard[] => []);
  deck.forEach((card, index) => hands[index % hands.length]!.push(card));

  let nextFinishPosition = 1;
  let players: PlayerProfile[] = state.players.map((player, index): PlayerProfile => {
    const hand = removePairs(hands[index]!, random);
    if (hand.length === 0) {
      return { ...player, hand, status: "finished" as const, finishPosition: nextFinishPosition++ };
    }
    return { ...player, hand, status: "playing" as const, finishPosition: 0 };
  });
  const active = players.filter((player) => player.status === "playing");
  let phase: RoomState["phase"] = "playing";
  if (active.length <= 1) {
    if (active[0] !== undefined) {
      players = players.map((player) =>
        player.userId === active[0]?.userId
          ? { ...player, status: "shayeb" as const, finishPosition: nextFinishPosition }
          : player,
      );
    }
    players = applyRoundScores(players);
    phase = "round_end";
  }
  const firstPlayerIndex = Math.max(
    0,
    players.findIndex((player) => player.status === "playing" && player.connected),
  );
  return {
    ...state,
    players,
    phase,
    currentPlayerIndex: firstPlayerIndex,
    roundNumber,
    nextFinishPosition,
    lastAction: { type: actionType, actorUserId },
    stateVersion: state.stateVersion + 1,
    updatedAt: now,
  };
}

function createDeck(random: RandomSource): GameCard[] {
  const shayebSuit = SUITS[Math.floor(random() * SUITS.length)] ?? SUITS[0];
  const deck: GameCard[] = [];
  for (const suit of SUITS) {
    for (let rank = 1; rank <= 13; rank += 1) {
      if (rank === 13 && suit !== shayebSuit) continue;
      deck.push({ id: `${suit}_${rank}`, suit, rank });
    }
  }
  return deck;
}

function findNextConnectedPlayerIndex(
  players: readonly PlayerProfile[],
  currentIndex: number,
): number {
  for (let offset = 1; offset <= players.length; offset += 1) {
    const index = (currentIndex + offset) % players.length;
    const player = players[index];
    if (player?.status === "playing" && player.connected) return index;
  }
  return currentIndex;
}

function mutate(
  state: RoomState,
  players: readonly PlayerProfile[],
  lastAction: GameActionSummary,
  now: string,
): RoomState {
  return {
    ...state,
    players,
    lastAction,
    stateVersion: state.stateVersion + 1,
    updatedAt: now,
  };
}

function invalidPhase(): GameResult {
  return {
    ok: false,
    code: "invalid_game_phase",
    message: "That action is not allowed in the current game phase.",
  };
}
