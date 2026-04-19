#!/usr/bin/env python3
"""
fetch_game.py — BroadcastBrain overnight game cache builder.

WHAT THIS SCRIPT DOES:
  Run it the night before a game with a team name. It pulls everything the
  spotting board needs — next game details, both rosters, player stats,
  news headlines, and injury reports — then writes it all to
  assets/game_cache.json so the app works in airplane mode during the demo.

HOW IT GETS THE DATA (no paid APIs, no API keys):
  ┌─────────────────────────────────────────────────────┐
  │ Sport       │ API used                               │
  ├─────────────┼────────────────────────────────────────┤
  │ Soccer      │ ESPN unofficial (site.api.espn.com)    │
  │ Basketball  │ ESPN unofficial (site.api.espn.com)    │
  │ Baseball    │ MLB official   (statsapi.mlb.com)      │
  │ Hockey      │ NHL official   (api-web.nhle.com)      │
  │ News/injury │ Google News RSS (news.google.com/rss)  │
  └─────────────┴────────────────────────────────────────┘

USAGE:
  python src/data/fetch_game.py "Manchester City"
  python src/data/fetch_game.py "Los Angeles Lakers"
  python src/data/fetch_game.py "New York Yankees"
  python src/data/fetch_game.py "Toronto Maple Leafs"

OUTPUT:
  assets/game_cache.json
"""

import sys
import json
import re
import time
import traceback
from datetime import datetime, timezone
from urllib.parse import quote_plus

import requests
from bs4 import BeautifulSoup

# ─────────────────────────────────────────────────────────────────────────────
# HTTP SESSION
# A single requests.Session reuses the TCP connection across all calls,
# which is faster and looks more like a real browser to the servers.
# ─────────────────────────────────────────────────────────────────────────────

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
})


def get_json(url: str, timeout: int = 12) -> dict | list | None:
    """
    Fetch a URL and parse the response as JSON.
    Returns None if the request fails or the response isn't valid JSON.
    We sleep 0.5s between calls to avoid hammering the servers.
    """
    try:
        time.sleep(0.5)
        resp = SESSION.get(url, timeout=timeout)
        resp.raise_for_status()
        return resp.json()
    except Exception as exc:
        print(f"  [http] failed: {url[-80:]} → {exc}", file=sys.stderr)
        return None


def get_xml(url: str, timeout: int = 12) -> BeautifulSoup | None:
    """
    Fetch a URL and parse the response as XML (used for RSS feeds).
    Returns a BeautifulSoup object or None on failure.
    """
    try:
        time.sleep(0.5)
        resp = SESSION.get(url, timeout=timeout)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml-xml")
    except Exception as exc:
        print(f"  [http] RSS failed: {url[-80:]} → {exc}", file=sys.stderr)
        return None


# ─────────────────────────────────────────────────────────────────────────────
# SPORT DETECTION
#
# We need to know what sport the team plays before we can call the right API.
# Strategy:
#   1. Check a hardcoded lookup table of well-known teams (instant, reliable).
#   2. If not found there, search across all ESPN league endpoints until we
#      find a team name that matches closely enough.
# ─────────────────────────────────────────────────────────────────────────────

# Maps a team name fragment (lowercase) → (sport_family, espn_league_slug, display_name)
# sport_family is one of: "soccer" | "nba" | "mlb" | "nhl"
KNOWN_TEAMS: dict[str, tuple[str, str, str]] = {
    # ── Soccer – Premier League ──────────────────────────────────────────────
    "manchester city":      ("soccer", "eng.1", "Premier League"),
    "manchester united":    ("soccer", "eng.1", "Premier League"),
    "liverpool":            ("soccer", "eng.1", "Premier League"),
    "arsenal":              ("soccer", "eng.1", "Premier League"),
    "chelsea":              ("soccer", "eng.1", "Premier League"),
    "tottenham":            ("soccer", "eng.1", "Premier League"),
    "spurs":                ("soccer", "eng.1", "Premier League"),
    "newcastle":            ("soccer", "eng.1", "Premier League"),
    "aston villa":          ("soccer", "eng.1", "Premier League"),
    "west ham":             ("soccer", "eng.1", "Premier League"),
    "brighton":             ("soccer", "eng.1", "Premier League"),
    "everton":              ("soccer", "eng.1", "Premier League"),
    "fulham":               ("soccer", "eng.1", "Premier League"),
    "brentford":            ("soccer", "eng.1", "Premier League"),
    "nottingham forest":    ("soccer", "eng.1", "Premier League"),
    "wolves":               ("soccer", "eng.1", "Premier League"),
    "wolverhampton":        ("soccer", "eng.1", "Premier League"),
    "crystal palace":       ("soccer", "eng.1", "Premier League"),
    "leicester":            ("soccer", "eng.1", "Premier League"),
    "ipswich":              ("soccer", "eng.1", "Premier League"),
    "southampton":          ("soccer", "eng.1", "Premier League"),
    # ── Soccer – La Liga ─────────────────────────────────────────────────────
    "real madrid":          ("soccer", "esp.1", "La Liga"),
    "barcelona":            ("soccer", "esp.1", "La Liga"),
    "atletico madrid":      ("soccer", "esp.1", "La Liga"),
    "athletic bilbao":      ("soccer", "esp.1", "La Liga"),
    "real sociedad":        ("soccer", "esp.1", "La Liga"),
    "villarreal":           ("soccer", "esp.1", "La Liga"),
    "sevilla":              ("soccer", "esp.1", "La Liga"),
    "betis":                ("soccer", "esp.1", "La Liga"),
    # ── Soccer – Bundesliga ──────────────────────────────────────────────────
    "bayern munich":        ("soccer", "ger.1", "Bundesliga"),
    "borussia dortmund":    ("soccer", "ger.1", "Bundesliga"),
    "bayer leverkusen":     ("soccer", "ger.1", "Bundesliga"),
    "rb leipzig":           ("soccer", "ger.1", "Bundesliga"),
    "eintracht frankfurt":  ("soccer", "ger.1", "Bundesliga"),
    # ── Soccer – Serie A ─────────────────────────────────────────────────────
    "juventus":             ("soccer", "ita.1", "Serie A"),
    "inter milan":          ("soccer", "ita.1", "Serie A"),
    "ac milan":             ("soccer", "ita.1", "Serie A"),
    "napoli":               ("soccer", "ita.1", "Serie A"),
    "roma":                 ("soccer", "ita.1", "Serie A"),
    "lazio":                ("soccer", "ita.1", "Serie A"),
    "atalanta":             ("soccer", "ita.1", "Serie A"),
    "fiorentina":           ("soccer", "ita.1", "Serie A"),
    # ── Soccer – Ligue 1 ─────────────────────────────────────────────────────
    "paris saint-germain":  ("soccer", "fra.1", "Ligue 1"),
    "psg":                  ("soccer", "fra.1", "Ligue 1"),
    "monaco":               ("soccer", "fra.1", "Ligue 1"),
    "marseille":            ("soccer", "fra.1", "Ligue 1"),
    "lyon":                 ("soccer", "fra.1", "Ligue 1"),
    "nice":                 ("soccer", "fra.1", "Ligue 1"),
    "lille":                ("soccer", "fra.1", "Ligue 1"),
    # ── Soccer – MLS ─────────────────────────────────────────────────────────
    "inter miami":          ("soccer", "usa.1", "MLS"),
    "la galaxy":            ("soccer", "usa.1", "MLS"),
    "lafc":                 ("soccer", "usa.1", "MLS"),
    "seattle sounders":     ("soccer", "usa.1", "MLS"),
    "portland timbers":     ("soccer", "usa.1", "MLS"),
    "new york city":        ("soccer", "usa.1", "MLS"),
    "new york red bulls":   ("soccer", "usa.1", "MLS"),
    "atlanta united":       ("soccer", "usa.1", "MLS"),
    # ── NBA — ESPN sport string is "basketball", league is "nba" ─────────────
    "los angeles lakers":   ("basketball", "nba", "NBA"),
    "lakers":               ("basketball", "nba", "NBA"),
    "golden state warriors":("basketball", "nba", "NBA"),
    "warriors":             ("basketball", "nba", "NBA"),
    "boston celtics":       ("basketball", "nba", "NBA"),
    "celtics":              ("basketball", "nba", "NBA"),
    "miami heat":           ("basketball", "nba", "NBA"),
    "chicago bulls":        ("basketball", "nba", "NBA"),
    "brooklyn nets":        ("basketball", "nba", "NBA"),
    "new york knicks":      ("basketball", "nba", "NBA"),
    "knicks":               ("basketball", "nba", "NBA"),
    "dallas mavericks":     ("basketball", "nba", "NBA"),
    "mavs":                 ("basketball", "nba", "NBA"),
    "milwaukee bucks":      ("basketball", "nba", "NBA"),
    "denver nuggets":       ("basketball", "nba", "NBA"),
    "phoenix suns":         ("basketball", "nba", "NBA"),
    "philadelphia 76ers":   ("basketball", "nba", "NBA"),
    "cleveland cavaliers":  ("basketball", "nba", "NBA"),
    "oklahoma city thunder":("basketball", "nba", "NBA"),
    "houston rockets":      ("basketball", "nba", "NBA"),
    "memphis grizzlies":    ("basketball", "nba", "NBA"),
    "sacramento kings":     ("basketball", "nba", "NBA"),
    "minnesota timberwolves":("basketball","nba","NBA"),
    "indiana pacers":       ("basketball", "nba", "NBA"),
    "new orleans pelicans": ("basketball", "nba", "NBA"),
    "toronto raptors":      ("basketball", "nba", "NBA"),
    "atlanta hawks":        ("basketball", "nba", "NBA"),
    "orlando magic":        ("basketball", "nba", "NBA"),
    "washington wizards":   ("basketball", "nba", "NBA"),
    "detroit pistons":      ("basketball", "nba", "NBA"),
    "charlotte hornets":    ("basketball", "nba", "NBA"),
    "portland trail blazers":("basketball","nba","NBA"),
    "san antonio spurs":    ("basketball", "nba", "NBA"),
    "utah jazz":            ("basketball", "nba", "NBA"),
    # ── MLB — uses official MLB API, not ESPN ─────────────────────────────────
    "new york yankees":     ("baseball", "mlb", "MLB"),
    "yankees":              ("baseball", "mlb", "MLB"),
    "los angeles dodgers":  ("baseball", "mlb", "MLB"),
    "dodgers":              ("baseball", "mlb", "MLB"),
    "boston red sox":       ("baseball", "mlb", "MLB"),
    "red sox":              ("baseball", "mlb", "MLB"),
    "chicago cubs":         ("baseball", "mlb", "MLB"),
    "san francisco giants": ("baseball", "mlb", "MLB"),
    "new york mets":        ("baseball", "mlb", "MLB"),
    "mets":                 ("baseball", "mlb", "MLB"),
    "houston astros":       ("baseball", "mlb", "MLB"),
    "astros":               ("baseball", "mlb", "MLB"),
    "atlanta braves":       ("baseball", "mlb", "MLB"),
    "braves":               ("baseball", "mlb", "MLB"),
    "philadelphia phillies":("baseball", "mlb", "MLB"),
    "phillies":             ("baseball", "mlb", "MLB"),
    "st. louis cardinals":  ("baseball", "mlb", "MLB"),
    "cardinals":            ("baseball", "mlb", "MLB"),
    "seattle mariners":     ("baseball", "mlb", "MLB"),
    "mariners":             ("baseball", "mlb", "MLB"),
    "chicago white sox":    ("baseball", "mlb", "MLB"),
    "minnesota twins":      ("baseball", "mlb", "MLB"),
    "cleveland guardians":  ("baseball", "mlb", "MLB"),
    "miami marlins":        ("baseball", "mlb", "MLB"),
    "tampa bay rays":       ("baseball", "mlb", "MLB"),
    "toronto blue jays":    ("baseball", "mlb", "MLB"),
    "blue jays":            ("baseball", "mlb", "MLB"),
    "baltimore orioles":    ("baseball", "mlb", "MLB"),
    "orioles":              ("baseball", "mlb", "MLB"),
    "texas rangers":        ("baseball", "mlb", "MLB"),
    "kansas city royals":   ("baseball", "mlb", "MLB"),
    "royals":               ("baseball", "mlb", "MLB"),
    "oakland athletics":    ("baseball", "mlb", "MLB"),
    "athletics":            ("baseball", "mlb", "MLB"),
    "colorado rockies":     ("baseball", "mlb", "MLB"),
    "rockies":              ("baseball", "mlb", "MLB"),
    "san diego padres":     ("baseball", "mlb", "MLB"),
    "padres":               ("baseball", "mlb", "MLB"),
    "cincinnati reds":      ("baseball", "mlb", "MLB"),
    "pittsburgh pirates":   ("baseball", "mlb", "MLB"),
    "detroit tigers":       ("baseball", "mlb", "MLB"),
    "tigers":               ("baseball", "mlb", "MLB"),
    "arizona diamondbacks": ("baseball", "mlb", "MLB"),
    "milwaukee brewers":    ("baseball", "mlb", "MLB"),
    "brewers":              ("baseball", "mlb", "MLB"),
    "washington nationals": ("baseball", "mlb", "MLB"),
    "los angeles angels":   ("baseball", "mlb", "MLB"),
    "angels":               ("baseball", "mlb", "MLB"),
    # ── NHL — uses official NHL API, not ESPN ─────────────────────────────────
    "toronto maple leafs":  ("hockey", "nhl", "NHL"),
    "leafs":                ("hockey", "nhl", "NHL"),
    "montreal canadiens":   ("hockey", "nhl", "NHL"),
    "canadiens":            ("hockey", "nhl", "NHL"),
    "boston bruins":        ("hockey", "nhl", "NHL"),
    "bruins":               ("hockey", "nhl", "NHL"),
    "new york rangers":     ("hockey", "nhl", "NHL"),
    "edmonton oilers":      ("hockey", "nhl", "NHL"),
    "oilers":               ("hockey", "nhl", "NHL"),
    "colorado avalanche":   ("hockey", "nhl", "NHL"),
    "avalanche":            ("hockey", "nhl", "NHL"),
    "tampa bay lightning":  ("hockey", "nhl", "NHL"),
    "lightning":            ("hockey", "nhl", "NHL"),
    "vegas golden knights": ("hockey", "nhl", "NHL"),
    "golden knights":       ("hockey", "nhl", "NHL"),
    "carolina hurricanes":  ("hockey", "nhl", "NHL"),
    "hurricanes":           ("hockey", "nhl", "NHL"),
    "florida panthers":     ("hockey", "nhl", "NHL"),
    "panthers":             ("hockey", "nhl", "NHL"),
    "dallas stars":         ("hockey", "nhl", "NHL"),
    "stars":                ("hockey", "nhl", "NHL"),
    "new york islanders":   ("hockey", "nhl", "NHL"),
    "islanders":            ("hockey", "nhl", "NHL"),
    "new jersey devils":    ("hockey", "nhl", "NHL"),
    "devils":               ("hockey", "nhl", "NHL"),
    "pittsburgh penguins":  ("hockey", "nhl", "NHL"),
    "penguins":             ("hockey", "nhl", "NHL"),
    "detroit red wings":    ("hockey", "nhl", "NHL"),
    "red wings":            ("hockey", "nhl", "NHL"),
    "nashville predators":  ("hockey", "nhl", "NHL"),
    "predators":            ("hockey", "nhl", "NHL"),
    "minnesota wild":       ("hockey", "nhl", "NHL"),
    "wild":                 ("hockey", "nhl", "NHL"),
    "winnipeg jets":        ("hockey", "nhl", "NHL"),
    "jets":                 ("hockey", "nhl", "NHL"),
    "st. louis blues":      ("hockey", "nhl", "NHL"),
    "blues":                ("hockey", "nhl", "NHL"),
    "seattle kraken":       ("hockey", "nhl", "NHL"),
    "kraken":               ("hockey", "nhl", "NHL"),
    "chicago blackhawks":   ("hockey", "nhl", "NHL"),
    "blackhawks":           ("hockey", "nhl", "NHL"),
    "ottawa senators":      ("hockey", "nhl", "NHL"),
    "senators":             ("hockey", "nhl", "NHL"),
    "calgary flames":       ("hockey", "nhl", "NHL"),
    "flames":               ("hockey", "nhl", "NHL"),
    "vancouver canucks":    ("hockey", "nhl", "NHL"),
    "canucks":              ("hockey", "nhl", "NHL"),
    "buffalo sabres":       ("hockey", "nhl", "NHL"),
    "sabres":               ("hockey", "nhl", "NHL"),
    "arizona coyotes":      ("hockey", "nhl", "NHL"),
    "san jose sharks":      ("hockey", "nhl", "NHL"),
    "sharks":               ("hockey", "nhl", "NHL"),
    "philadelphia flyers":  ("hockey", "nhl", "NHL"),
    "flyers":               ("hockey", "nhl", "NHL"),
    "anaheim ducks":        ("hockey", "nhl", "NHL"),
    "ducks":                ("hockey", "nhl", "NHL"),
    "columbus blue jackets":("hockey", "nhl", "NHL"),
    "washington capitals":  ("hockey", "nhl", "NHL"),
    "capitals":             ("hockey", "nhl", "NHL"),
}

# ESPN league slugs to search through when team isn't in KNOWN_TEAMS
ESPN_LEAGUES = [
    ("soccer", "eng.1"),   # Premier League
    ("soccer", "esp.1"),   # La Liga
    ("soccer", "ger.1"),   # Bundesliga
    ("soccer", "ita.1"),   # Serie A
    ("soccer", "fra.1"),   # Ligue 1
    ("soccer", "usa.1"),   # MLS
    ("basketball", "nba"), # NBA
]

# Brand colors used for team pane headers in the UI
TEAM_COLORS: dict[str, str] = {
    "manchester city": "#6CABDD", "manchester united": "#DA291C",
    "liverpool": "#C8102E", "arsenal": "#EF0107", "chelsea": "#034694",
    "tottenham": "#132257", "newcastle": "#241F20", "aston villa": "#95BFE5",
    "real madrid": "#FEBE10", "barcelona": "#A50044", "atletico madrid": "#CB3524",
    "juventus": "#000000", "inter milan": "#010E80", "ac milan": "#FB090B",
    "napoli": "#087AC6", "paris saint-germain": "#004170",
    "bayern munich": "#DC052D", "borussia dortmund": "#FDE100",
    "los angeles lakers": "#552583", "golden state warriors": "#1D428A",
    "boston celtics": "#007A33", "chicago bulls": "#CE1141",
    "miami heat": "#98002E", "brooklyn nets": "#000000",
    "new york yankees": "#003087", "los angeles dodgers": "#005A9C",
    "boston red sox": "#BD3039", "chicago cubs": "#0E3386",
    "houston astros": "#002D62", "atlanta braves": "#CE1141",
    "toronto maple leafs": "#003E7E", "montreal canadiens": "#AF1E2D",
    "boston bruins": "#FFB81C", "edmonton oilers": "#FF4C00",
    "colorado avalanche": "#6F263D", "tampa bay lightning": "#002868",
    "default": "#1A1A2E",
}


def detect_sport(team_name: str) -> tuple[str, str, str]:
    """
    Returns (sport_family, espn_league_slug, competition_display_name).

    Checks the KNOWN_TEAMS lookup first. If not found, searches every ESPN
    league endpoint until it finds a close team name match.
    """
    lower = team_name.lower().strip()

    # Step 1: direct lookup — covers 95% of cases instantly
    for key, value in KNOWN_TEAMS.items():
        if key in lower or lower in key:
            print(f"  [detect] matched known team: '{key}' → {value[2]}", file=sys.stderr)
            return value

    # Step 2: search ESPN leagues — each endpoint lists all teams in that league
    print("  [detect] not in known list, searching ESPN leagues...", file=sys.stderr)
    for sport, league in ESPN_LEAGUES:
        url = f"https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/teams"
        data = get_json(url)
        if not data:
            continue
        teams = (data.get("sports", [{}])[0]
                     .get("leagues", [{}])[0]
                     .get("teams", []))
        for entry in teams:
            t = entry.get("team", {})
            name = t.get("displayName", "").lower()
            nickname = t.get("nickname", "").lower()
            if lower in name or lower in nickname or name in lower:
                display = f"{league.upper()} ({sport.title()})"
                print(f"  [detect] ESPN match: {t['displayName']} in {league}", file=sys.stderr)
                return sport, league, display

    # Fallback — treat as soccer Premier League and let the search fail gracefully
    print("  [detect] could not detect sport, defaulting to PL soccer", file=sys.stderr)
    return "soccer", "eng.1", "Premier League"


# ─────────────────────────────────────────────────────────────────────────────
# ESPN FUNCTIONS  (soccer + NBA)
#
# ESPN runs an unofficial JSON API at site.api.espn.com.
# No API key required — it's the same data that powers espn.com.
# ─────────────────────────────────────────────────────────────────────────────

ESPN_BASE = "https://site.api.espn.com/apis/site/v2/sports"
ESPN_CORE = "https://sports.core.api.espn.com/v2/sports"


def espn_find_team_id(team_name: str, sport: str, league: str) -> str | None:
    """
    Search the ESPN team list for a given league and return the team's numeric ID.
    We need this ID to call all the other ESPN endpoints (schedule, roster, etc.).
    """
    url = f"{ESPN_BASE}/{sport}/{league}/teams"
    data = get_json(url)
    if not data:
        return None

    teams = (data.get("sports", [{}])[0]
                 .get("leagues", [{}])[0]
                 .get("teams", []))

    lower = team_name.lower()
    best_id = None
    best_score = 0

    for entry in teams:
        t = entry.get("team", {})
        name = t.get("displayName", "").lower()
        nickname = t.get("nickname", "").lower()
        short = t.get("shortDisplayName", "").lower()
        slug = t.get("slug", "").lower()

        score = 0
        if lower == name:
            score = 100
        elif lower in name or name in lower:
            score = 80
        elif lower in nickname or nickname in lower:
            score = 60
        elif lower in slug:
            score = 50
        elif any(w in name for w in lower.split() if len(w) > 3):
            score = 30

        if score > best_score:
            best_score = score
            best_id = t.get("id")

    print(f"  [espn] team ID = {best_id} (score={best_score})", file=sys.stderr)
    return best_id


def espn_next_game(team_id: str, sport: str, league: str) -> dict:
    """
    Fetch the team's schedule from ESPN and return the next upcoming game.

    ESPN marks each event with a 'state': 'pre' (upcoming), 'in' (live),
    or 'post' (finished). We scan for the first 'pre' event.

    Returns a dict with: event_id, home_team, away_team, home_id, away_id,
    venue, date_iso, competition.
    """
    url = f"{ESPN_BASE}/{sport}/{league}/teams/{team_id}/schedule"
    data = get_json(url)
    if not data:
        return {}

    for event in data.get("events", []):
        comps = event.get("competitions", [])
        if not comps:
            continue
        comp = comps[0]
        state = comp.get("status", {}).get("type", {}).get("state", "")
        if state != "pre":
            continue

        competitors = comp.get("competitors", [])
        home = next((c for c in competitors if c.get("homeAway") == "home"), {})
        away = next((c for c in competitors if c.get("homeAway") == "away"), {})

        return {
            "event_id":    event.get("id", ""),
            "home_team":   home.get("team", {}).get("displayName", ""),
            "away_team":   away.get("team", {}).get("displayName", ""),
            "home_id":     home.get("team", {}).get("id", ""),
            "away_id":     away.get("team", {}).get("id", ""),
            "venue":       comp.get("venue", {}).get("fullName", "TBD"),
            "date_iso":    event.get("date", ""),
            "competition": data.get("season", {}).get("displayName", ""),
        }

    return {}


def espn_roster(team_id: str, sport: str, league: str) -> list[dict]:
    """
    Fetch a team's full roster from ESPN.

    ESPN returns players grouped by position (e.g. Forwards, Midfielders).
    Each player has an id, displayName, position abbreviation, and age.
    We flatten all groups into one list.
    """
    url = f"{ESPN_BASE}/{sport}/{league}/teams/{team_id}/roster"
    data = get_json(url)
    if not data:
        return []

    players = []
    for item in data.get("athletes", []):
        # Each item is either a player directly or a position-group containing players
        if "items" in item:
            for player in item["items"]:
                players.append(_parse_espn_athlete(player))
        else:
            players.append(_parse_espn_athlete(item))

    print(f"  [espn] roster: {len(players)} players", file=sys.stderr)
    return players


def _parse_espn_athlete(athlete: dict) -> dict:
    """Extract the fields we care about from an ESPN athlete object."""
    return {
        "id":       athlete.get("id", ""),
        "name":     athlete.get("displayName", athlete.get("fullName", "")),
        "number":   _parse_int(athlete.get("jersey", "")),
        "position": athlete.get("position", {}).get("abbreviation", ""),
        "age":      athlete.get("age"),
        "headshot": athlete.get("headshot", {}).get("href", ""),
    }


def espn_player_stats(player_id: str, sport: str, league: str) -> dict:
    """
    Fetch season stats for a player from ESPN's core statistics API.

    The core API (sports.core.api.espn.com) has more detailed stats than the
    main site API. Stats come back in named categories (e.g. 'Scoring',
    'General') each with a list of stat name/value pairs.
    We flatten everything into one dict: {"Goals": "22", "Assists": "8", ...}
    """
    url = f"{ESPN_CORE}/{sport}/leagues/{league}/athletes/{player_id}/statistics/0"
    data = get_json(url)
    if not data:
        return {}

    stats = {}
    categories = data.get("splits", {}).get("categories", [])
    for cat in categories:
        for stat in cat.get("stats", []):
            name = stat.get("displayName", "")
            value = stat.get("displayValue", "—")
            if name and value not in ("", "0", "0.0", None):
                stats[name] = value

    return stats


def espn_team_news(team_id: str, sport: str, league: str) -> list[str]:
    """
    Fetch the latest news headlines for a team from ESPN.
    Returns a list of headline strings.
    """
    url = f"{ESPN_BASE}/{sport}/{league}/news?team={team_id}&limit=10"
    data = get_json(url)
    if not data:
        return []

    headlines = []
    for article in data.get("articles", []):
        headline = article.get("headline", "").strip()
        if headline:
            headlines.append(headline)

    return headlines[:6]


# ─────────────────────────────────────────────────────────────────────────────
# MLB FUNCTIONS  (official MLB Stats API — statsapi.mlb.com)
#
# This is MLB's own public API. No key required. It's the same data that
# powers MLB.com. Endpoints follow /api/v1/... conventions.
# ─────────────────────────────────────────────────────────────────────────────

MLB_BASE = "https://statsapi.mlb.com/api/v1"


def mlb_find_team_id(team_name: str) -> str | None:
    """Find the MLB team ID by fetching the full team list and fuzzy-matching."""
    data = get_json(f"{MLB_BASE}/teams?sportId=1")
    if not data:
        return None

    lower = team_name.lower()
    for team in data.get("teams", []):
        name = team.get("name", "").lower()
        short = team.get("teamName", "").lower()
        if lower in name or name in lower or lower in short:
            tid = str(team["id"])
            print(f"  [mlb] team ID = {tid} ({team['name']})", file=sys.stderr)
            return tid

    return None


def mlb_next_game(team_id: str) -> dict:
    """
    Fetch the next scheduled MLB game.
    The schedule endpoint returns games by date; we look for gamePk (game ID),
    both teams, venue, and official date.
    """
    url = f"{MLB_BASE}/schedule/games/?sportId=1&teamId={team_id}"
    data = get_json(url)
    if not data:
        return {}

    dates = data.get("dates", [])
    if not dates:
        return {}

    game = dates[0]["games"][0]
    return {
        "event_id":    str(game.get("gamePk", "")),
        "home_team":   game["teams"]["home"]["team"]["name"],
        "away_team":   game["teams"]["away"]["team"]["name"],
        "home_id":     str(game["teams"]["home"]["team"]["id"]),
        "away_id":     str(game["teams"]["away"]["team"]["id"]),
        "venue":       game.get("venue", {}).get("name", "TBD"),
        "date_iso":    game.get("gameDate", ""),
        "competition": "MLB",
    }


def mlb_roster(team_id: str) -> list[dict]:
    """
    Fetch the active MLB roster.
    Returns each player's person ID (needed for stats), full name,
    jersey number, and position abbreviation.
    """
    url = f"{MLB_BASE}/teams/{team_id}/roster?season=2026&rosterType=active"
    data = get_json(url)
    if not data:
        return []

    players = []
    for entry in data.get("roster", []):
        players.append({
            "id":       str(entry["person"]["id"]),
            "name":     entry["person"]["fullName"],
            "number":   _parse_int(entry.get("jerseyNumber", "")),
            "position": entry.get("position", {}).get("abbreviation", ""),
            "age":      None,  # not in roster endpoint; available via /people/{id}
        })

    print(f"  [mlb] roster: {len(players)} players", file=sys.stderr)
    return players


def mlb_player_stats(player_id: str) -> dict:
    """
    Fetch 2026 season batting or pitching stats for an MLB player.
    We try hitting first, then pitching — returns whichever has data.
    """
    stats = {}
    for group in ("hitting", "pitching"):
        url = f"{MLB_BASE}/people/{player_id}/stats?stats=season&season=2026&group={group}"
        data = get_json(url)
        if not data:
            continue
        splits = (data.get("stats") or [{}])[0].get("splits", [])
        if splits:
            stat_block = splits[0].get("stat", {})
            # Keep only non-zero values
            for k, v in stat_block.items():
                if v not in (None, "", 0, "0", ".000", "0.0"):
                    stats[k] = str(v)
            if stats:
                break

    return stats


# ─────────────────────────────────────────────────────────────────────────────
# NHL FUNCTIONS  (official NHL API — api-web.nhle.com)
#
# The NHL's own public API. No key required. Much cleaner than scraping.
# ─────────────────────────────────────────────────────────────────────────────

NHL_BASE = "https://api-web.nhle.com/v1"

# Maps team city/name fragments to their 3-letter NHL abbreviation (needed for NHL API URLs)
NHL_ABBREVS: dict[str, str] = {
    "toronto": "TOR", "maple leafs": "TOR", "leafs": "TOR",
    "montreal": "MTL", "canadiens": "MTL",
    "boston": "BOS", "bruins": "BOS",
    "new york rangers": "NYR", "rangers": "NYR",
    "new york islanders": "NYI", "islanders": "NYI",
    "new jersey": "NJD", "devils": "NJD",
    "philadelphia": "PHI", "flyers": "PHI",
    "pittsburgh": "PIT", "penguins": "PIT",
    "buffalo": "BUF", "sabres": "BUF",
    "detroit": "DET", "red wings": "DET",
    "ottawa": "OTT", "senators": "OTT",
    "carolina": "CAR", "hurricanes": "CAR",
    "washington": "WSH", "capitals": "WSH",
    "columbus": "CBJ", "blue jackets": "CBJ",
    "florida": "FLA", "panthers": "FLA",
    "tampa bay": "TBL", "lightning": "TBL",
    "nashville": "NSH", "predators": "NSH",
    "chicago": "CHI", "blackhawks": "CHI",
    "st. louis": "STL", "blues": "STL",
    "minnesota": "MIN", "wild": "MIN",
    "winnipeg": "WPG", "jets": "WPG",
    "dallas": "DAL", "stars": "DAL",
    "colorado": "COL", "avalanche": "COL",
    "edmonton": "EDM", "oilers": "EDM",
    "calgary": "CGY", "flames": "CGY",
    "vancouver": "VAN", "canucks": "VAN",
    "seattle": "SEA", "kraken": "SEA",
    "vegas": "VGK", "golden knights": "VGK",
    "arizona": "UTA", "utah": "UTA",
    "san jose": "SJS", "sharks": "SJS",
    "anaheim": "ANA", "ducks": "ANA",
    "los angeles": "LAK", "kings": "LAK",
}


def nhl_abbrev(team_name: str) -> str | None:
    """Look up the 3-letter NHL abbreviation for a team name."""
    lower = team_name.lower()
    for key, abbrev in NHL_ABBREVS.items():
        if key in lower:
            return abbrev
    return None


def nhl_next_game(abbrev: str) -> dict:
    """
    Fetch the next scheduled NHL game for a team abbreviation.
    The club-schedule-season endpoint returns all games for the current season.
    We scan for the first game with state 'FUT' (future) or 'PRE' (pre-game).
    """
    url = f"{NHL_BASE}/club-schedule-season/{abbrev}/now"
    data = get_json(url)
    if not data:
        return {}

    for game in data.get("games", []):
        if game.get("gameState") in ("FUT", "PRE"):
            home = game.get("homeTeam", {})
            away = game.get("awayTeam", {})
            return {
                "event_id":    str(game.get("id", "")),
                "home_team":   home.get("placeName", {}).get("default", "") + " " + home.get("commonName", {}).get("default", ""),
                "away_team":   away.get("placeName", {}).get("default", "") + " " + away.get("commonName", {}).get("default", ""),
                "home_id":     home.get("abbrev", ""),
                "away_id":     away.get("abbrev", ""),
                "venue":       game.get("venue", {}).get("default", "TBD"),
                "date_iso":    game.get("gameDate", ""),
                "competition": "NHL",
            }

    return {}


def nhl_roster(abbrev: str) -> list[dict]:
    """
    Fetch the current NHL roster for a team.
    Returns forwards, defensemen, and goalies combined into one list.
    """
    url = f"{NHL_BASE}/roster/{abbrev}/current"
    data = get_json(url)
    if not data:
        return []

    players = []
    for group in ("forwards", "defensemen", "goalies"):
        for p in data.get(group, []):
            players.append({
                "id":       str(p.get("id", "")),
                "name":     p.get("firstName", {}).get("default", "") + " " + p.get("lastName", {}).get("default", ""),
                "number":   p.get("sweaterNumber"),
                "position": p.get("positionCode", ""),
                "age":      _calc_age(p.get("birthDate", "")),
                "headshot": p.get("headshot", ""),
            })

    print(f"  [nhl] roster: {len(players)} players", file=sys.stderr)
    return players


def nhl_player_stats(player_id: str) -> dict:
    """
    Fetch NHL player stats from the player landing page.
    Returns the most recent season's totals: goals, assists, points, etc.
    """
    url = f"{NHL_BASE}/player/{player_id}/landing"
    data = get_json(url)
    if not data:
        return {}

    season_totals = data.get("seasonTotals", [])
    if not season_totals:
        return {}

    latest = season_totals[-1]
    stats = {}
    for key in ("goals", "assists", "points", "plusMinus", "pim",
                "shots", "gamesPlayed", "savePctg", "goalsAgainstAvg",
                "shutouts", "wins"):
        val = latest.get(key)
        if val is not None and val != 0:
            stats[key] = str(val)

    return stats


# ─────────────────────────────────────────────────────────────────────────────
# GOOGLE NEWS RSS  (news + injuries, all sports)
#
# Google News provides an RSS feed with no API key required.
# URL format: news.google.com/rss/search?q={query}&hl=en-US&gl=US&ceid=US:en
# Each <item> has a <title> and <pubDate>.
# We use this for news that the sports APIs don't provide.
# ─────────────────────────────────────────────────────────────────────────────

GOOGLE_NEWS_RSS = "https://news.google.com/rss/search"


def google_news(query: str, max_results: int = 5) -> list[str]:
    """
    Search Google News RSS and return a list of headline strings.
    Appends the current year to focus results on recent news.
    """
    url = f"{GOOGLE_NEWS_RSS}?q={quote_plus(query)}&hl=en-US&gl=US&ceid=US:en"
    soup = get_xml(url)
    if not soup:
        return []

    headlines = []
    for item in soup.find_all("item")[:max_results]:
        title_tag = item.find("title")
        if title_tag:
            # Google News titles often end with " - Source Name"; strip that
            title = re.sub(r"\s*-\s*[^-]+$", "", title_tag.text.strip())
            headlines.append(title)

    return headlines


def fetch_news_for_team(team_name: str) -> list[str]:
    """Get the latest news for a team (used for team storylines)."""
    return google_news(f"{team_name} news 2026", max_results=6)


def fetch_news_for_player(player_name: str, team_name: str) -> list[str]:
    """Get the latest news mentions for a specific player."""
    return google_news(f"{player_name} {team_name} 2026", max_results=3)


def fetch_injury_report(team_name: str) -> list[str]:
    """
    Search Google News for injury and availability news.
    Returns raw headlines — the caller uses these to set player 'status' fields.
    """
    return google_news(f"{team_name} injury suspended doubtful out 2026", max_results=8)


# ─────────────────────────────────────────────────────────────────────────────
# STORYLINE GENERATOR
#
# Storylines are the one-line broadcaster-ready notes on each player card.
# We generate them from whatever data we have: news headlines, stats, status.
# ─────────────────────────────────────────────────────────────────────────────

def make_storyline(name: str, position: str, stats: dict,
                   news: list[str], status: str) -> str:
    """
    Build a single broadcaster-ready sentence for a player.
    Priority: injury news > recent headline > top stat > generic fallback.
    """
    if status in ("injured", "doubtful", "suspended"):
        return f"{name} is listed as {status} — his availability is the key team news heading in."

    if news:
        headline = re.sub(r"\s*-\s*[^-]+$", "", news[0]).strip()
        if len(headline) > 10:
            return headline

    if stats:
        top_key, top_val = next(iter(stats.items()))
        return f"{name} brings {top_val} {top_key} into this matchup — one of the key figures to watch."

    return f"{name} is a key {position} piece in this lineup — watch how they influence the game."


def make_matchup_note(name: str, opponent: str, vs_stats: dict) -> str:
    """One sentence on how this player matches up against today's opponent."""
    if vs_stats:
        items = [f"{v} {k}" for k, v in list(vs_stats.items())[:2]]
        return f"{name} has recorded {' and '.join(items)} against {opponent} historically."
    return f"{name} faces {opponent} — a key individual battle to monitor throughout."


def infer_status(player_name: str, injury_headlines: list[str]) -> str:
    """
    Check injury headlines for mentions of this player.
    Returns 'injured', 'doubtful', 'suspended', or 'fit'.
    """
    name_parts = [p.lower() for p in player_name.split() if len(p) > 2]
    for headline in injury_headlines:
        hl = headline.lower()
        if not any(part in hl for part in name_parts):
            continue
        if "suspend" in hl:
            return "suspended"
        if "doubtful" in hl:
            return "doubtful"
        if any(w in hl for w in ("out", "ruled out", "injured", "sidelined", "misses")):
            return "injured"
    return "fit"


# ─────────────────────────────────────────────────────────────────────────────
# UTILITY HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _parse_int(s) -> int | None:
    m = re.search(r"\d+", str(s))
    return int(m.group()) if m else None


def _calc_age(birth_date: str) -> int | None:
    """Calculate age from a YYYY-MM-DD string."""
    if not birth_date:
        return None
    try:
        bd = datetime.strptime(birth_date[:10], "%Y-%m-%d")
        today = datetime.now()
        return today.year - bd.year - ((today.month, today.day) < (bd.month, bd.day))
    except Exception:
        return None


def _team_color(team_name: str) -> str:
    lower = team_name.lower()
    for key, color in TEAM_COLORS.items():
        if key in lower:
            return color
    return TEAM_COLORS["default"]


def _make_id(*parts: str) -> str:
    raw = "-".join(p.lower().strip() for p in parts if p)
    return re.sub(r"[^a-z0-9]+", "-", raw).strip("-") or "unknown"


def _top_stats(stats: dict, limit: int = 3) -> list[str]:
    """Format top stats as display strings for the player card."""
    lines = []
    for k, v in stats.items():
        if v and str(v) not in ("—", "", "0", "0.0", "None"):
            lines.append(f"{v} {k}")
        if len(lines) >= limit:
            break
    return lines


# ─────────────────────────────────────────────────────────────────────────────
# MAIN ORCHESTRATOR
# ─────────────────────────────────────────────────────────────────────────────

def build_game_cache(team_name: str) -> dict:
    """
    Main function. Coordinates all API calls and scraping, then assembles
    the final game_cache.json structure.
    """
    print(f"\n{'='*50}", file=sys.stderr)
    print(f"BroadcastBrain Cache Builder — {team_name}", file=sys.stderr)
    print(f"{'='*50}\n", file=sys.stderr)

    # ── 1. DETECT SPORT ──────────────────────────────────────────────────────
    # Figure out what sport/league this team plays in so we call the right API.
    print("[1/5] Detecting sport...", file=sys.stderr)
    sport, league, competition_display = detect_sport(team_name)
    print(f"      → {competition_display}\n", file=sys.stderr)

    # ── 2. FIND NEXT GAME ────────────────────────────────────────────────────
    # Call the appropriate API to find the next scheduled game.
    # We also store our_team_id separately so the roster call always works,
    # even if no upcoming game is found (e.g. end of season).
    print("[2/5] Finding next game...", file=sys.stderr)
    game_info: dict = {}
    our_team_id: str = ""   # used for roster + news regardless of game lookup

    if sport in ("soccer", "basketball"):
        # ESPN handles both soccer and basketball; sport string matches ESPN's URL
        our_team_id = espn_find_team_id(team_name, sport, league) or ""
        if our_team_id:
            game_info = espn_next_game(our_team_id, sport, league)

    elif sport == "baseball":
        # MLB has its own official API (statsapi.mlb.com)
        our_team_id = mlb_find_team_id(team_name) or ""
        if our_team_id:
            game_info = mlb_next_game(our_team_id)

    elif sport == "hockey":
        # NHL has its own official API (api-web.nhle.com), uses 3-letter abbreviations
        our_team_id = nhl_abbrev(team_name) or ""
        if our_team_id:
            game_info = nhl_next_game(our_team_id)

    # Fallback: no upcoming game in API (e.g. end of season or between fixtures).
    # Try Google News RSS headlines to extract opponent and date.
    if not game_info:
        print("      → No upcoming game in API, trying Google News...", file=sys.stderr)
        news_hints = google_news(f"{team_name} next match fixture 2026", max_results=8)
        opponent_hint = ""

        # Build a list of known team names to look for in headlines
        all_known_names = list(KNOWN_TEAMS.keys())

        for headline in news_hints:
            hl_lower = headline.lower()
            # Skip if our team isn't even mentioned
            team_words = team_name.lower().split()
            if not any(w in hl_lower for w in team_words if len(w) > 3):
                continue
            # Scan for any known team name that appears in this headline
            found = ""
            for known in all_known_names:
                if known in hl_lower and known not in team_name.lower():
                    # Prefer longer matches (more specific team names)
                    if len(known) > len(found):
                        found = known
            if found:
                # Title-case the name for display
                opponent_hint = found.title()
                print(f"      → Extracted opponent from news: '{opponent_hint}'", file=sys.stderr)
                break

        # Also try a "X v Y" pattern directly in headlines
        if not opponent_hint:
            for headline in news_hints:
                m = re.search(
                    r"([A-Z][a-zA-Z\s&]{2,25}?)\s+v(?:s\.?)?\s+([A-Z][a-zA-Z\s&]{2,25})",
                    headline,
                )
                if m:
                    g1, g2 = m.group(1).strip(), m.group(2).strip()
                    team_first = team_name.split()[0].lower()
                    if team_first in g1.lower():
                        opponent_hint = g2
                    elif team_first in g2.lower():
                        opponent_hint = g1
                    if opponent_hint:
                        print(f"      → Extracted opponent via vs-pattern: '{opponent_hint}'", file=sys.stderr)
                        break
        game_info = {
            "event_id":    "tbd",
            "home_team":   team_name,
            "away_team":   opponent_hint or "TBD",
            "home_id":     our_team_id,
            "away_id":     "",
            "venue":       "TBD",
            "date_iso":    datetime.now(timezone.utc).isoformat(),
            "competition": competition_display,
        }

    home_team = game_info.get("home_team", team_name)
    away_team = game_info.get("away_team", "TBD")
    print(f"      → {home_team} vs {away_team} at {game_info.get('venue','TBD')}\n", file=sys.stderr)

    # ── 3. FETCH BOTH ROSTERS ────────────────────────────────────────────────
    # Get every player on both squads with their IDs, positions, and numbers.
    # We use our_team_id (set in step 2) so the roster call always works even
    # when no upcoming game was found in the schedule API.
    print("[3/5] Fetching rosters...", file=sys.stderr)
    home_players_raw: list[dict] = []
    away_players_raw: list[dict] = []

    # Determine opponent name — whoever isn't us
    is_home = team_name.lower() in home_team.lower() or home_team.lower() in team_name.lower()
    opp_name = away_team if is_home else home_team

    # Opponent's API ID (from game_info if available, otherwise look it up)
    opp_api_id = game_info.get("away_id" if is_home else "home_id", "")

    if sport in ("soccer", "basketball"):
        if our_team_id:
            home_players_raw = espn_roster(our_team_id, sport, league)
        if not opp_api_id and opp_name != "TBD":
            opp_api_id = espn_find_team_id(opp_name, sport, league) or ""
        if opp_api_id:
            away_players_raw = espn_roster(opp_api_id, sport, league)

    elif sport == "baseball":
        if our_team_id:
            home_players_raw = mlb_roster(our_team_id)
        if opp_name != "TBD":
            opp_mlb_id = opp_api_id or mlb_find_team_id(opp_name) or ""
            if opp_mlb_id:
                away_players_raw = mlb_roster(opp_mlb_id)

    elif sport == "hockey":
        if our_team_id:
            home_players_raw = nhl_roster(our_team_id)
        if opp_name != "TBD":
            opp_abbrev = opp_api_id or nhl_abbrev(opp_name) or ""
            if opp_abbrev:
                away_players_raw = nhl_roster(opp_abbrev)

    print(f"      → Home: {len(home_players_raw)} | Away: {len(away_players_raw)}\n", file=sys.stderr)

    # ── 4. FETCH NEWS & INJURIES ─────────────────────────────────────────────
    # Google News RSS — no API key needed.
    # We use these headlines for:
    #   a) player 'status' (injured/doubtful/suspended/fit)
    #   b) player news_headlines array on the card
    #   c) global storylines at the match level
    print("[4/5] Fetching news & injuries via Google News RSS...", file=sys.stderr)
    home_injury_report = fetch_injury_report(home_team)
    away_injury_report = fetch_injury_report(away_team) if away_team != "TBD" else []
    all_injuries = home_injury_report + away_injury_report

    home_team_news = fetch_news_for_team(home_team)
    away_team_news = fetch_news_for_team(away_team) if away_team != "TBD" else []
    global_storylines = home_team_news[:3] + away_team_news[:2]

    # ESPN team news (available for soccer and basketball)
    if sport in ("soccer", "basketball") and our_team_id:
        espn_headlines = espn_team_news(our_team_id, sport, league)
        global_storylines = (espn_headlines[:3] + global_storylines)[:8]

    print(f"      → {len(global_storylines)} storylines, {len(all_injuries)} injury items\n", file=sys.stderr)

    # ── 5. BUILD PLAYER RECORDS ──────────────────────────────────────────────
    # For each player: fetch their stats, check injury status, generate
    # broadcaster storylines and matchup notes.
    print("[5/5] Building player records...", file=sys.stderr)

    home_id_str = _make_id(home_team)
    away_id_str = _make_id(away_team)

    def build_player_list(players_raw: list[dict], team_id_str: str,
                          team_display: str, opponent_display: str) -> list[dict]:
        built = []
        for i, p in enumerate(players_raw[:20]):  # cap at 20 per team
            name     = p.get("name", f"Player {i+1}").strip()
            position = p.get("position", "")
            age      = p.get("age") or 0
            number   = p.get("number") or (i + 1)
            player_id = p.get("id", _make_id(team_id_str, name))

            # Fetch stats — only for first 10 players to stay fast
            stats: dict = {}
            if i < 10 and player_id:
                if sport in ("soccer", "basketball"):
                    stats = espn_player_stats(player_id, sport, league)
                elif sport == "baseball":
                    stats = mlb_player_stats(player_id)
                elif sport == "hockey":
                    stats = nhl_player_stats(player_id)

            # Fetch individual news — only for first 6 players
            player_news: list[str] = []
            if i < 6:
                player_news = fetch_news_for_player(name, team_display)

            status = infer_status(name, all_injuries)

            built.append({
                "id":           _make_id(team_id_str, name),
                "team_id":      team_id_str,
                "shirt_number": number,
                "name":         name,
                "position":     position or "—",
                "age":          age,
                "stats": {
                    "season":      stats,
                    "form_last_5": {},   # would need match-by-match data; not in these APIs
                    "vs_opponent": {},   # would need historical split data
                },
                "storyline":    make_storyline(name, position, stats, player_news, status),
                "matchup_note": make_matchup_note(name, opponent_display, {}),
                "top_stats":    _top_stats(stats),
                "status":       status,
                "news_headlines": player_news,
            })

        return built

    home_players = build_player_list(home_players_raw, home_id_str, home_team, away_team)
    away_players = build_player_list(away_players_raw, away_id_str, away_team, home_team)

    print(f"      → Built {len(home_players)} home + {len(away_players)} away player records\n",
          file=sys.stderr)

    # ── ASSEMBLE OUTPUT ───────────────────────────────────────────────────────
    return {
        "match": {
            "id":          _make_id(home_team, away_team),
            "home_team":   home_team,
            "away_team":   away_team,
            "competition": game_info.get("competition") or competition_display,
            "venue":       game_info.get("venue", "TBD"),
            "kickoff_iso": game_info.get("date_iso", datetime.now(timezone.utc).isoformat()),
        },
        "teams": {
            "home": {
                "id":        home_id_str,
                "name":      home_team,
                "color_hex": _team_color(home_team),
                "record":    {},
            },
            "away": {
                "id":        away_id_str,
                "name":      away_team,
                "color_hex": _team_color(away_team),
                "record":    {},
            },
        },
        "players":    home_players + away_players,
        "storylines": global_storylines,
        "source":     "espn_unofficial + mlb_official + nhl_official + google_news_rss",
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python src/data/fetch_game.py <team name>")
        print("  e.g. python src/data/fetch_game.py 'Manchester City'")
        print("  e.g. python src/data/fetch_game.py 'Los Angeles Lakers'")
        print("  e.g. python src/data/fetch_game.py 'New York Yankees'")
        print("  e.g. python src/data/fetch_game.py 'Toronto Maple Leafs'")
        sys.exit(1)

    team_name = " ".join(sys.argv[1:])

    try:
        cache = build_game_cache(team_name)
    except Exception:
        traceback.print_exc()
        sys.exit(1)

    import os
    out_dir = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..", "..", "assets")
    )
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "game_cache.json")

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)

    print(f"✓ Wrote {out_path}")
    print(f"  Match:      {cache['match']['home_team']} vs {cache['match']['away_team']}")
    print(f"  Venue:      {cache['match']['venue']}")
    print(f"  Kickoff:    {cache['match']['kickoff_iso']}")
    print(f"  Players:    {len(cache['players'])}")
    print(f"  Storylines: {len(cache['storylines'])}")


if __name__ == "__main__":
    main()
