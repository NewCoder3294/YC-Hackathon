import { create } from 'zustand';

// ---- Event shapes (DATA_CONTRACTS.md §3) ----
export type StatCardEvent         = { type: 'stat_card'; player_id: string; stat_text: string; source: string; latency_ms: number; confidence_high: boolean };
export type PrecedentEvent        = { type: 'precedent'; pattern_id: string; stat_text: string; category: string };
export type CounterNarrativeEvent = { type: 'counter_narrative'; text: string; for_team: 'home' | 'away'; tone: 'calming' | 'dramatic' };
export type RunningScoreEvent     = { type: 'running_score'; score: { home: number; away: number }; minute: number; momentum?: string };
export type MomentumTagEvent      = { type: 'momentum_tag'; text: string; team: 'home' | 'away' };
export type StreakAlertEvent      = { type: 'streak_alert'; player_id: string; streak_text: string; at_risk: boolean };
export type TranscriptEvent       = { type: 'transcript'; text: string; confidence: number };
export type StoryTickEvent        = { type: 'story_tick'; story_id: string };
export type VoiceCommandEvent     = { type: 'voice_command'; raw: string; classified_as: 'widget' | 'query' | 'unclear' };
export type WidgetBuiltEvent      = { type: 'widget_built'; widget: WidgetSpec };
export type AnswerCardEvent       = { type: 'answer_card'; question: string; answer: string; source: string; confidence_high: boolean; latency_ms: number };
export type NoDataEvent           = { type: 'no_data'; question: string };
export type OptInTtsEvent         = { type: 'opt_in_tts'; enabled: boolean };
export type ModeChangedEvent      = { type: 'mode_changed'; mode: 'stats_first' | 'story_first' | 'tactical' | 'custom' };

export type WidgetSpec = {
  id: string;
  kind: 'timeline' | 'bar_chart' | 'comparison_table' | 'heat_map' | 'shot_map';
  title: string;
  data: unknown;
  pinned: boolean;
  source: string;
};

export type BusEvent =
  | StatCardEvent | PrecedentEvent | CounterNarrativeEvent | RunningScoreEvent
  | MomentumTagEvent | StreakAlertEvent | TranscriptEvent | StoryTickEvent
  | VoiceCommandEvent | WidgetBuiltEvent | AnswerCardEvent | NoDataEvent
  | OptInTtsEvent | ModeChangedEvent;

type EventOfType<T extends BusEvent['type']> = Extract<BusEvent, { type: T }>;

type BusState = {
  events: BusEvent[];
  emit: (event: BusEvent) => void;
  latest: <T extends BusEvent['type']>(type: T) => EventOfType<T> | undefined;
  clear: () => void;
};

const MAX_EVENTS = 200;

export const useEventBus = create<BusState>((set, get) => ({
  events: [],
  emit: (event) => set((s) => ({ events: [...s.events, event].slice(-MAX_EVENTS) })),
  latest: (type) => {
    const events = get().events;
    for (let i = events.length - 1; i >= 0; i--) {
      if (events[i].type === type) return events[i] as EventOfType<typeof type>;
    }
    return undefined;
  },
  clear: () => set({ events: [] }),
}));
