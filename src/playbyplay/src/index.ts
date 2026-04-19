import { select } from "@inquirer/prompts";
import { ExitPromptError } from "@inquirer/core";
import chalk from "chalk";
import { writeFileSync, mkdirSync, readFileSync, existsSync } from "fs";
import {
  getLiveGames,
  getPlays,
  filterNewPlays,
  enrichPlaysWithAthletes,
  compactGame,
  lastCompactPlayId,
  type Game,
  type Play,
  type CompactGame,
} from "./api.js";
import { LEAGUES, type League } from "./sports.js";

async function pickLeague(): Promise<League> {
  return select({
    message: chalk.bold("Select a league:"),
    choices: LEAGUES.map((l) => ({ name: l.displayName, value: l })),
    pageSize: 20,
  });
}

function formatGameLabel(g: Game): string {
  const score =
    g.status === "Scheduled"
      ? chalk.gray(g.period)
      : chalk.yellow(`${g.awayScore}-${g.homeScore}`) + " " + chalk.gray(g.period);
  return `${chalk.bold(g.shortName)}  ${score}`;
}

async function pickGame(games: Game[]): Promise<Game> {
  return select({
    message: chalk.bold("Select a game:"),
    choices: games.map((g) => ({ name: formatGameLabel(g), value: g })),
    pageSize: 15,
  });
}

function formatPlay(p: Play, game: Game): string[] {
  const period = p.period?.displayValue || `${p.period?.type ?? ""} ${p.period?.number ?? ""}`.trim();
  const score = chalk.yellow(`${game.awayTeam} ${p.awayScore ?? 0} - ${game.homeTeam} ${p.homeScore ?? 0}`);
  const typeText = p.type?.text ?? "Play";
  const typeColor = p.scoringPlay ? chalk.bold.red : chalk.bold.green;
  const participants = (p.participants ?? [])
    .map((x: any) => {
      const name = x.athlete?.displayName ?? "Unknown";
      return x.type ? `${x.type}: ${name}` : name;
    })
    .join(", ");

  const lines = [`\n${chalk.cyan(period)}  ${score}`, `  ${typeColor(typeText)}`];
  if (p.text) lines.push(`  ${chalk.gray(p.text)}`);
  if (participants) lines.push(`  ${chalk.gray(participants)}`);
  return lines;
}

async function fetchAndSavePlayByPlay(league: League, game: Game): Promise<void> {
  console.log(chalk.gray(`\nFetching plays for ${game.shortName}...\n`));
  console.time(chalk.cyan("Play-by-play workflow"));

  console.time(chalk.cyan("  Fetch plays"));
  const allPlays = await getPlays(league, game.id);
  console.timeEnd(chalk.cyan("  Fetch plays"));

  const outDir = `output/${league.key}`;
  mkdirSync(outDir, { recursive: true });
  const filename = `${outDir}/${game.shortName.replace(/\s+/g, "_")}_${new Date().toISOString().slice(0, 10)}.json`;

  let existing: CompactGame | null = null;
  if (existsSync(filename)) {
    try {
      existing = JSON.parse(readFileSync(filename, "utf-8")) as CompactGame;
    } catch {
      console.warn(chalk.yellow("Could not read existing file, starting fresh."));
      existing = null;
    }
  }

  const lastId = lastCompactPlayId(existing);
  const newPlays: Play[] = filterNewPlays(allPlays, lastId);

  if (existing && newPlays.length === 0) {
    console.log(chalk.gray("No new plays since last update."));
    console.timeEnd(chalk.cyan("Play-by-play workflow"));
    return;
  }

  console.time(chalk.cyan("  Enrich athletes"));
  const enrichedAllPlays = await enrichPlaysWithAthletes(allPlays);
  console.timeEnd(chalk.cyan("  Enrich athletes"));

  const compact = compactGame(league, game, enrichedAllPlays);
  writeFileSync(filename, JSON.stringify(compact, null, 2));

  const addedCount = existing ? newPlays.length : enrichedAllPlays.length;
  console.log(chalk.green(`✓ ${existing ? "Added" : "Saved"} ${addedCount} play(s) to ${filename}`));

  if (newPlays.length > 0) {
    const enrichedNew = enrichedAllPlays.slice(enrichedAllPlays.length - newPlays.length);
    console.log(chalk.cyan(`\nNew plays:`));
    enrichedNew.forEach((p) => formatPlay(p, game).forEach((line) => console.log(line)));
  }
  console.timeEnd(chalk.cyan("Play-by-play workflow"));
}

async function main(): Promise<void> {
  console.log(chalk.bold.blue("\n🏟  ESPN Play-by-Play JSON Exporter\n"));
  console.time(chalk.cyan("Total execution time"));

  const league = await pickLeague();
  console.log(chalk.gray(`\nFetching today's ${league.displayName} games...\n`));

  let games: Game[];
  try {
    console.time(chalk.cyan("Fetch games"));
    games = await getLiveGames(league);
    console.timeEnd(chalk.cyan("Fetch games"));
  } catch (err) {
    console.error(chalk.red("Failed to fetch games:"), err);
    process.exit(1);
    return;
  }

  if (games.length === 0) {
    console.log(chalk.yellow(`No ${league.displayName} games scheduled today.`));
    console.timeEnd(chalk.cyan("Total execution time"));
    process.exit(0);
    return;
  }

  console.log(chalk.gray(`Found ${games.length} game(s).\n`));

  const game = await pickGame(games);
  await fetchAndSavePlayByPlay(league, game);
  console.timeEnd(chalk.cyan("Total execution time"));
}

main().catch((err) => {
  if (err instanceof ExitPromptError) {
    console.log(chalk.yellow("\nExited."));
    process.exit(0);
  }
  console.error(chalk.red("Error:"), err);
  process.exit(1);
});
