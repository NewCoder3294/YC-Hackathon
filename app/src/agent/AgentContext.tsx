import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';

export type AgentPoint = {
  id: string;
  text: string;
  source?: string;
  category?: 'stat' | 'streak' | 'tactic' | 'story' | 'alert';
  at: number;
};

export type ArchivedSession = {
  id: string;
  match: string;
  startedAt: number;
  endedAt: number;
  points: AgentPoint[];
};

export type MatchNote = {
  id: string;
  sessionId: string;     // points to the session this note summarizes
  match: string;
  createdAt: number;
  updatedAt: number;
  title: string;
  body: string;
  source: 'gemini-auto' | 'user';
};

type AgentState = {
  active: boolean;
  points: AgentPoint[];
  pipVisible: boolean;
  saving: boolean;
  sessions: ArchivedSession[];
  notes: MatchNote[];
  start: () => void;
  stop: () => void;
  toggle: () => void;
  hidePiP: () => void;
  showPiP: () => void;
  deleteSession: (id: string) => void;
  updateNote: (id: string, patch: Partial<Pick<MatchNote, 'title' | 'body'>>) => void;
  deleteNote: (id: string) => void;
  addUserNote: (sessionId: string, match: string, title: string, body: string) => void;
};

const Ctx = createContext<AgentState>({
  active: false, points: [], pipVisible: true, saving: false, sessions: [], notes: [],
  start: () => {}, stop: () => {}, toggle: () => {},
  hidePiP: () => {}, showPiP: () => {}, deleteSession: () => {},
  updateNote: () => {}, deleteNote: () => {}, addUserNote: () => {},
});

const DEMO_POINTS: Omit<AgentPoint, 'id' | 'at'>[] = [
  { text: 'Messi arriving into the box — watch the right channel.',                                        category: 'tactic',  source: 'inferred' },
  { text: 'Messi\'s WC knockout penalty conversion: 98% since 2014.',                                      category: 'stat',    source: 'Sportradar' },
  { text: 'Streak alert: Mbappé has scored in both of his WC Final appearances (2018 + 2022).',           category: 'streak',  source: 'Sportradar' },
  { text: 'Story reminder: Peter Drury\'s "Messi ascends to football heaven" clip is pre-queued.',        category: 'story',   source: 'inferred' },
  { text: 'France set-piece conversion this tournament: 38% — top-3 at the WC.',                          category: 'stat',    source: 'StatsBomb' },
  { text: 'Tchouaméni is pressing Messi\'s half-space drops — first sign of Deschamps\' tactical shift.',  category: 'tactic',  source: 'inferred' },
  { text: 'Giroud passed Henry in R16. One more goal here = solo France all-time record.',                 category: 'streak',  source: 'Sportradar' },
  { text: 'Di María has 2.1 xA this tournament — top 5 globally among wingers.',                          category: 'stat',    source: 'StatsBomb' },
  { text: 'Stay on Emi Martínez: 1 shootout win already (NL 2021 final vs Suárez).',                      category: 'alert',   source: 'Sportradar' },
  { text: 'Teams leading 2-0 in WC Finals have won 19 of 22 since 1970. Two went to extra time.',         category: 'stat',    source: 'Sportradar' },
];

const CURRENT_MATCH = 'ARG vs FRA · 2022 WC Final';
let counter = 0;

export function AgentProvider({ children }: { children: React.ReactNode }) {
  const [active, setActive]     = useState(false);
  const [points, setPoints]     = useState<AgentPoint[]>([]);
  const [pipVisible, setPipV]   = useState(true);
  const [saving, setSaving]     = useState(false);
  const [sessions, setSessions] = useState<ArchivedSession[]>([]);
  const [notes, setNotes]       = useState<MatchNote[]>([]);
  const timerRef  = useRef<ReturnType<typeof setInterval> | null>(null);
  const idxRef    = useRef(0);
  const startedRef = useRef<number>(0);

  const clearTimer = () => {
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = null;
  };

  const start = useCallback(() => {
    if (timerRef.current) return;
    setActive(true);
    setPipV(true);
    setPoints([]);
    idxRef.current = 0;
    startedRef.current = Date.now();
    const push = () => {
      const src = DEMO_POINTS[idxRef.current % DEMO_POINTS.length];
      idxRef.current += 1;
      counter += 1;
      setPoints((prev) => [{ id: `p-${counter}`, at: Date.now(), ...src }, ...prev].slice(0, 50));
    };
    push();
    timerRef.current = setInterval(push, 4500);
  }, []);

  // Stop drives the "saving to archive" animation before it actually commits.
  const stop = useCallback(() => {
    clearTimer();
    setActive(false);
    setSaving(true);
    const startedAt = startedRef.current;
    const endedAt = Date.now();
    setPoints((curr) => {
      setTimeout(() => {
        const sessionId = `s-${Date.now()}`;
        setSessions((prev) => [
          { id: sessionId, match: CURRENT_MATCH, startedAt, endedAt, points: curr },
          ...prev,
        ]);
        // Auto-generated Gemini-style summary note per match session.
        const note = synthesizeNote(sessionId, CURRENT_MATCH, startedAt, endedAt, curr);
        setNotes((prev) => [note, ...prev]);
        setSaving(false);
        setPoints([]);
      }, 1800);
      return curr;
    });
  }, []);

  const toggle = useCallback(() => {
    if (active) stop(); else start();
  }, [active, start, stop]);

  const hidePiP = useCallback(() => setPipV(false), []);
  const showPiP = useCallback(() => setPipV(true), []);
  const deleteSession = useCallback(
    (id: string) =>
      setSessions((prev) => {
        // also drop any notes tied to it
        setNotes((n) => n.filter((note) => note.sessionId !== id));
        return prev.filter((s) => s.id !== id);
      }),
    [],
  );
  const updateNote = useCallback(
    (id: string, patch: Partial<Pick<MatchNote, 'title' | 'body'>>) =>
      setNotes((prev) =>
        prev.map((n) => (n.id === id ? { ...n, ...patch, updatedAt: Date.now() } : n)),
      ),
    [],
  );
  const deleteNote = useCallback(
    (id: string) => setNotes((prev) => prev.filter((n) => n.id !== id)),
    [],
  );
  const addUserNote = useCallback((sessionId: string, match: string, title: string, body: string) => {
    const now = Date.now();
    setNotes((prev) => [
      { id: `n-${now}`, sessionId, match, createdAt: now, updatedAt: now, title, body, source: 'user' },
      ...prev,
    ]);
  }, []);

  useEffect(() => () => clearTimer(), []);

  return (
    <Ctx.Provider
      value={{
        active, points, pipVisible, saving, sessions, notes,
        start, stop, toggle, hidePiP, showPiP,
        deleteSession, updateNote, deleteNote, addUserNote,
      }}
    >
      {children}
    </Ctx.Provider>
  );
}

// Fake "Gemini-cleaned" auto-summary. Later: call actual Gemini API with the
// point list and replace this synth.
function synthesizeNote(
  sessionId: string,
  match: string,
  startedAt: number,
  endedAt: number,
  points: AgentPoint[],
): MatchNote {
  const byCat = points.reduce<Record<string, AgentPoint[]>>((acc, p) => {
    const k = p.category ?? 'note';
    (acc[k] ||= []).push(p);
    return acc;
  }, {});
  const duration = Math.max(1, Math.floor((endedAt - startedAt) / 60000));
  const lines: string[] = [];
  lines.push(`Session summary — ${duration} min, ${points.length} surfaces.`);
  lines.push('');
  const labels: Record<string, string> = {
    stat: 'Stats surfaced', streak: 'Streaks flagged', tactic: 'Tactical reads',
    story: 'Storyline reminders', alert: 'Alerts', note: 'Notes',
  };
  for (const [cat, list] of Object.entries(byCat)) {
    lines.push(`${labels[cat] ?? cat.toUpperCase()} (${list.length}):`);
    list.slice(0, 3).forEach((p) => lines.push(`  · ${p.text}`));
    if (list.length > 3) lines.push(`  · …and ${list.length - 3} more`);
    lines.push('');
  }
  const now = Date.now();
  return {
    id: `n-${now}`,
    sessionId,
    match,
    createdAt: now,
    updatedAt: now,
    title: `${match} — post-match notes`,
    body: lines.join('\n').trimEnd(),
    source: 'gemini-auto',
  };
}

export const useAgent = () => useContext(Ctx);
