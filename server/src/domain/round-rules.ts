import type { GameCard, PlayerProfile } from "./lobby";

export type RandomSource = () => number;

const POSITION_SCORES: Readonly<Record<number, number>> = {
  1: 100,
  2: 60,
  3: 40,
  4: 20,
  5: 10,
};
const SHAYEB_PENALTY = -50;

export function removePairs(
  hand: readonly GameCard[],
  random: RandomSource = Math.random,
): GameCard[] {
  const byRank = new Map<number, GameCard[]>();
  for (const card of hand) {
    const cards = byRank.get(card.rank) ?? [];
    cards.push(card);
    byRank.set(card.rank, cards);
  }
  const remaining = [...byRank.values()].flatMap((cards) =>
    cards.length % 2 === 1 ? [cards[cards.length - 1]!] : [],
  );
  shuffleCards(remaining, random);
  return remaining;
}

export function shuffleCards<T>(values: T[], random: RandomSource): void {
  for (let index = values.length - 1; index > 0; index -= 1) {
    const other = Math.floor(random() * (index + 1));
    [values[index], values[other]] = [values[other]!, values[index]!];
  }
}

export function applyRoundScores(
  players: readonly PlayerProfile[],
): PlayerProfile[] {
  return players.map((player) => ({
    ...player,
    score: player.score +
      (player.status === "shayeb"
        ? SHAYEB_PENALTY
        : POSITION_SCORES[player.finishPosition] ?? 0),
  }));
}
