import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { useEventBus, BusEvent, TranscriptEvent } from '../cactus/state/eventBus';
import { useModelLoader } from '../cactus/state/modelLoader';

export type AgentPoint = {
  id: string;
  text: string;
  source?: string;
  category?: 'stat' | 'streak' | 'tactic' | 'story' | 'alert';
  at: number;
};

export type TranscriptLine = {
  id: string;
  text: string;
  confidence: number;
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
  transcripts: TranscriptLine[];
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
  active: false, points: [], transcripts: [], pipVisible: true, saving: false, sessions: [], notes: [],
  start: () => {}, stop: () => {}, toggle: () => {},
  hidePiP: () => {}, showPiP: () => {}, deleteSession: () => {},
  updateNote: () => {}, deleteNote: () => {}, addUserNote: () => {},
});

const CURRENT_MATCH = 'ARG vs FRA · 2022 WC Final';
let counter = 0;

export function AgentProvider({ children }: { children: React.ReactNode }) {
  const [active, setActive]           = useState(false);
  const [points, setPoints]           = useState<AgentPoint[]>([]);
  const [transcripts, setTranscripts] = useState<TranscriptLine[]>([]);
  const [pipVisible, setPipV]         = useState(true);
  const [saving, setSaving]           = useState(false);
  const [sessions, setSessions]       = useState<ArchivedSession[]>([]);
  const [notes, setNotes]             = useState<MatchNote[]>([]);
  const startedRef = useRef<number>(0);

  const start = useCallback(() => {
    const modelStatus = useModelLoader.getState().status;
    if (modelStatus !== 'ready') {
      console.warn('[agent] start() called while model status =', modelStatus, '— ignoring');
      return;
    }
    setActive(true);
    setPipV(true);
    setPoints([]);
    startedRef.current = Date.now();
  }, []);

  useEffect(() => {
    if (!active) return;
    let prevEvents: BusEvent[] = useEventBus.getState().events;
    const unsub = useEventBus.subscribe((s) => {
      const nextEvents = s.events;
      if (nextEvents === prevEvents) return;
      const added = nextEvents.slice(prevEvents.length);
      prevEvents = nextEvents;
      for (const e of added) {
        if (e.type === 'transcript') {
          const text = e.text?.trim();
          const confidence = e.confidence ?? 0;
          if (!text) continue;
          counter += 1;
          const id = `t-${counter}`;
          setTranscripts((prev) => [{ id, text, confidence, at: Date.now() }, ...prev].slice(0, 5));
          continue;
        }
        const mapped = mapBusEventToPoint(e);
        if (!mapped) continue;
        counter += 1;
        const id = `p-${counter}`;
        const at = Date.now();
        setPoints((p) => [{ id, at, ...mapped }, ...p].slice(0, 50));
      }
    });
    return unsub;
  }, [active]);

  // Stop drives the "saving to archive" animation before it actually commits.
  const stop = useCallback(() => {
    setActive(false);
    setTranscripts([]);
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

  return (
    <Ctx.Provider
      value={{
        active, points, transcripts, pipVisible, saving, sessions, notes,
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

function mapBusEventToPoint(e: BusEvent): Omit<AgentPoint, 'id' | 'at'> | null {
  switch (e.type) {
    case 'stat_card':         return { text: e.stat_text,    source: e.source,  category: 'stat' };
    case 'precedent':         return { text: e.stat_text,    source: 'inferred', category: 'stat' };
    case 'counter_narrative': return { text: e.text,         source: 'inferred', category: 'tactic' };
    case 'streak_alert':      return { text: e.streak_text,  source: 'Sportradar', category: 'streak' };
    case 'answer_card':       return { text: e.answer,       source: e.source,  category: 'stat' };
    case 'no_data':           return { text: "I don't have verified data on that.", source: 'inferred', category: 'alert' };
    default:                  return null;
  }
}
