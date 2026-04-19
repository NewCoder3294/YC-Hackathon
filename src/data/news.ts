import fetch from "node-fetch";
import { LEAGUES } from "../playbyplay/src/sports";

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
  "Accept-Language": "en-US,en;q=0.9",
};

export interface NewsItem {
  id: string;
  headline: string;
  description: string;
  published: string;
  imageUrl?: string;
  articleUrl?: string;
  leagueKey: string;
  leagueLabel: string;
  source: "espn" | "google_news";
}

// ─── ESPN ────────────────────────────────────────────────────────────────────

function espnNewsUrl(sport: string, league: string, limit: number): string {
  return `https://site.api.espn.com/apis/site/v2/sports/${sport}/${league}/news?limit=${limit}`;
}

export async function fetchLeagueNews(leagueKey: string, limit = 20): Promise<NewsItem[]> {
  const league = LEAGUES.find((l) => l.key === leagueKey);
  if (!league) return [];

  const url = espnNewsUrl(league.sport, league.league, limit);
  try {
    const res = await fetch(url, { headers: HEADERS });
    if (!res.ok) return [];
    const data = (await res.json()) as { articles?: ESPNArticle[] };
    return (data.articles ?? []).map((a) => espnArticleToNewsItem(a, league.key, league.displayName.split(" — ")[0]));
  } catch {
    return [];
  }
}

export async function fetchAllSportsNews(limit = 10): Promise<NewsItem[]> {
  const mainLeagues = ["nfl", "nba", "mlb", "nhl", "epl", "mls"];
  const results = await Promise.all(mainLeagues.map((key) => fetchLeagueNews(key, limit)));
  return results
    .flat()
    .sort((a, b) => new Date(b.published).getTime() - new Date(a.published).getTime());
}

interface ESPNArticle {
  id?: string | number;
  headline?: string;
  description?: string;
  published?: string;
  images?: { url?: string }[];
  links?: { web?: { href?: string } };
}

function espnArticleToNewsItem(a: ESPNArticle, leagueKey: string, leagueLabel: string): NewsItem {
  return {
    id: `espn-${leagueKey}-${a.id ?? Math.random()}`,
    headline: a.headline ?? "",
    description: a.description ?? "",
    published: a.published ?? new Date().toISOString(),
    imageUrl: a.images?.[0]?.url,
    articleUrl: a.links?.web?.href,
    leagueKey,
    leagueLabel,
    source: "espn",
  };
}

// ─── Google News RSS ──────────────────────────────────────────────────────────

export async function fetchPlayerNews(playerName: string, teamName = "", limit = 5): Promise<NewsItem[]> {
  const query = teamName ? `${playerName} ${teamName}` : playerName;
  const url = `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=en-US&gl=US&ceid=US:en`;
  try {
    const res = await fetch(url, { headers: HEADERS });
    if (!res.ok) return [];
    const xml = await res.text();
    return parseGoogleNewsRSS(xml, limit, "google_news");
  } catch {
    return [];
  }
}

function parseGoogleNewsRSS(xml: string, limit: number, source: "google_news"): NewsItem[] {
  const items: NewsItem[] = [];
  // Match full <item> blocks
  const itemBlocks = [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)];
  for (const block of itemBlocks) {
    const content = block[1];
    const headline = extractTag(content, "title")?.replace(/\s*-\s*[^-]+$/, "").trim() ?? "";
    const description = stripHtml(extractTag(content, "description") ?? "");
    const published = extractTag(content, "pubDate") ?? new Date().toISOString();
    const link = extractTag(content, "link") ?? "";
    if (!headline || headline === "Google News") continue;
    items.push({
      id: `gnews-${Buffer.from(link).toString("base64").slice(0, 16)}`,
      headline,
      description,
      published,
      articleUrl: link,
      leagueKey: "player",
      leagueLabel: "Player News",
      source,
    });
    if (items.length >= limit) break;
  }
  return items;
}

function extractTag(xml: string, tag: string): string | undefined {
  const m = xml.match(new RegExp(`<${tag}[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/${tag}>`, "i"));
  return m?.[1]?.trim();
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, "").trim();
}
