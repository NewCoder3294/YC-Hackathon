// right-pane.jsx — Live pane components for BroadcastBrain Feature 2 (iPad)
// Rebuilt around the 3-card stack + voice-commanded widget pattern.
// Color language (locked, no confidence tiers):
//   RED   #EF4444 = hot / trending / streak active / record in reach
//   WHITE         = neutral stats
//   GREEN #10B981 = career high / record watermark / achievement unlocked
//   AMBER #F59E0B = AI nudge ("you haven't mentioned X in a while")

// ───── Live pane shell ─────
// A thin match-context strip at top, body in middle, voice button anchored to bottom bezel.
function LivePaneShell({
  clock = "23'",
  score = { arg: 1, fra: 0 },
  phase = 'LIVE',
  phaseColor,
  rightSlot,
  children,
  listeningDot = true,
  latency = '842ms',
}) {
  return (
    <div style={{
      height: '100%',
      display: 'grid',
      gridTemplateRows: 'auto 1fr auto',
      background: TOKENS.bgBase,
    }}>
      {/* top bar */}
      <div style={{
        padding: '14px 20px',
        borderBottom: `1px solid ${TOKENS.borderSoft}`,
        background: TOKENS.bgRaised,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <span style={{
              fontSize: 22, fontWeight: 700, color: TOKENS.text,
              letterSpacing: '-0.01em', fontVariantNumeric: 'tabular-nums',
            }}>{score.arg}</span>
            <span style={{ fontSize: 10, letterSpacing: '0.2em', color: TOKENS.textSubtle }}>ARG</span>
            <span style={{ fontSize: 14, color: TOKENS.textSubtle, margin: '0 4px' }}>·</span>
            <span style={{
              fontSize: 22, fontWeight: 700, color: TOKENS.text,
              letterSpacing: '-0.01em', fontVariantNumeric: 'tabular-nums',
            }}>{score.fra}</span>
            <span style={{ fontSize: 10, letterSpacing: '0.2em', color: TOKENS.textSubtle }}>FRA</span>
          </div>
          <div style={{
            padding: '4px 8px', fontSize: 10, letterSpacing: '0.14em',
            background: TOKENS.bgSubtle, color: TOKENS.textMuted, borderRadius: 3,
            border: `1px solid ${TOKENS.borderSoft}`,
          }}>{clock}</div>
          {phase && (
            <span style={{
              fontSize: 10, letterSpacing: '0.18em', fontWeight: 700,
              color: phaseColor || TOKENS.textMuted,
            }}>{phase}</span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {listeningDot && <ListeningDot/>}
          {rightSlot}
        </div>
      </div>

      {/* body */}
      <div style={{
        padding: '18px 20px',
        overflow: 'hidden',
        display: 'flex', flexDirection: 'column', gap: 14,
      }}>
        {children}
      </div>

      {/* bottom bezel: voice query button + latency */}
      <BottomBezel latency={latency}/>
    </div>
  );
}

// ───── Always-on listening indicator (corner) ─────
function ListeningDot() {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      fontSize: 9, letterSpacing: '0.14em', color: TOKENS.textSubtle,
    }}>
      <svg width="10" height="10" viewBox="0 0 10 10">
        <circle cx="5" cy="5" r="2" fill={TOKENS.verified}>
          <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" repeatCount="indefinite"/>
        </circle>
        <circle cx="5" cy="5" r="4" fill="none" stroke={TOKENS.verified} strokeOpacity="0.3">
          <animate attributeName="r" values="2;4.5" dur="2s" repeatCount="indefinite"/>
          <animate attributeName="opacity" values="0.6;0" dur="2s" repeatCount="indefinite"/>
        </circle>
      </svg>
      <span>LISTENING</span>
    </div>
  );
}

// ───── Bottom bezel — voice query button, press-and-hold ─────
function BottomBezel({ latency, label = 'HOLD TO ASK', state = 'idle' }) {
  const active = state === 'listening';
  return (
    <div style={{
      borderTop: `1px solid ${TOKENS.borderSoft}`,
      background: TOKENS.bgRaised,
      padding: '14px 20px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
    }}>
      <div style={{
        flex: 1,
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '12px 16px',
        background: active ? 'rgba(239,68,68,0.08)' : TOKENS.bgSubtle,
        border: `1px solid ${active ? TOKENS.live : TOKENS.border}`,
        borderRadius: 10,
      }}>
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke={active ? TOKENS.live : TOKENS.text} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
          <rect x="9" y="2" width="6" height="12" rx="3"/>
          <path d="M5 10v1a7 7 0 0 0 14 0v-1"/>
          <path d="M12 18v4"/>
          <path d="M8 22h8"/>
        </svg>
        <span style={{
          fontSize: 11, fontWeight: 700, letterSpacing: '0.18em',
          color: active ? TOKENS.live : TOKENS.text,
        }}>{active ? 'LISTENING…' : label}</span>
        {active && <Waveform color={TOKENS.live}/>}
      </div>
      <LatencyTag ms={latency}/>
    </div>
  );
}

function Waveform({ color = TOKENS.text }) {
  return (
    <svg width="46" height="16" viewBox="0 0 46 16" style={{ marginLeft: 6 }}>
      {[0,1,2,3,4,5,6,7].map(i => (
        <rect key={i} x={i*6} y="2" width="3" height="12" rx="1.5" fill={color} opacity="0.7">
          <animate attributeName="y" values="6;2;6" dur={`${0.6+i*0.08}s`} repeatCount="indefinite"/>
          <animate attributeName="height" values="4;12;4" dur={`${0.6+i*0.08}s`} repeatCount="indefinite"/>
        </rect>
      ))}
    </svg>
  );
}

// ───── 3-CARD STACK ─────
// The signature Feature 2 pattern: STAT (white edge) → PRECEDENT (green) → COUNTER (amber)
// Vertical rhythm, color-coded left edges, hero stat is the biggest thing.

const CARD_KIND = {
  stat:       { edge: TOKENS.text,     label: 'STAT',       iconColor: TOKENS.live },
  precedent:  { edge: TOKENS.verified, label: 'PRECEDENT',  iconColor: TOKENS.verified },
  counter:    { edge: TOKENS.esoteric, label: 'COUNTER-NARRATIVE', iconColor: TOKENS.esoteric },
};

function CardStack({ children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {children}
    </div>
  );
}

function StackCard({ kind = 'stat', children, entering = false }) {
  const k = CARD_KIND[kind];
  return (
    <div style={{
      position: 'relative',
      background: TOKENS.bgRaised,
      border: `1px solid ${TOKENS.border}`,
      borderRadius: 8,
      padding: '14px 16px 12px 20px',
      overflow: 'hidden',
      transform: entering ? 'translateX(10px)' : 'none',
      opacity: entering ? 0 : 1,
      animation: entering ? 'bb-enter 360ms cubic-bezier(.2,.8,.2,1) both' : 'none',
    }}>
      <div style={{
        position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: k.edge,
      }}/>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        marginBottom: 8,
      }}>
        <span style={{
          fontSize: 9, fontWeight: 700, letterSpacing: '0.22em',
          color: k.edge === TOKENS.text ? TOKENS.textSubtle : k.edge,
        }}>{k.label}</span>
      </div>
      {children}
    </div>
  );
}

// Scorer STAT card — hero numeral + player + context lines
function ScorerStatCard({ player, playerSub, minute, type, scoreChange, heroNumeral, heroCaption, context = [], latency = '842ms', entering }) {
  return (
    <div style={{
      position: 'relative',
      background: TOKENS.bgRaised,
      border: `1px solid ${TOKENS.border}`,
      borderRadius: 8,
      padding: '14px 18px 14px 22px',
      overflow: 'hidden',
      animation: entering ? 'bb-enter 360ms cubic-bezier(.2,.8,.2,1) both' : 'none',
    }}>
      <div style={{ position:'absolute', left:0, top:0, bottom:0, width:3, background: TOKENS.text }}/>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <div style={{ display:'flex', alignItems:'center', gap: 8 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: TOKENS.live }}/>
          <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.22em', color: TOKENS.textSubtle }}>STAT</span>
          <span style={{ fontSize: 10, color: TOKENS.textMuted, letterSpacing: '0.14em' }}>· {minute} · {type} · {scoreChange}</span>
        </div>
        <LatencyTag ms={latency}/>
      </div>
      <div style={{ marginTop: 10 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.18em', color: TOKENS.textMuted }}>{player}</div>
        <div style={{ fontSize: 9, letterSpacing: '0.14em', color: TOKENS.textSubtle, marginTop: 2 }}>{playerSub}</div>
      </div>
      <div style={{ marginTop: 6, display: 'flex', alignItems: 'baseline', gap: 14 }}>
        <div style={{
          fontSize: 88, fontWeight: 700, color: TOKENS.text,
          letterSpacing: '-0.04em', lineHeight: 0.9, fontVariantNumeric: 'tabular-nums',
        }}>{heroNumeral}</div>
        <div style={{ fontSize: 13, color: TOKENS.text, lineHeight: 1.3, maxWidth: 220 }}>{heroCaption}</div>
      </div>
      <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 4 }}>
        {context.map((c, i) => (
          <div key={i} style={{ fontSize: 11, color: TOKENS.textMuted, letterSpacing: '0.01em', lineHeight: 1.4 }}>
            <span style={{ color: TOKENS.textSubtle, marginRight: 6 }}>—</span>{c}
          </div>
        ))}
      </div>
      <div style={{ marginTop: 12 }}><SportradarBadge small/></div>
    </div>
  );
}

// PRECEDENT card — broader historical pattern
function PrecedentCard({ headline, support, iconColor = TOKENS.verified }) {
  return (
    <div style={{
      position:'relative',
      background: TOKENS.bgRaised,
      border: `1px solid ${TOKENS.border}`,
      borderRadius: 8,
      padding: '12px 14px 12px 20px',
      overflow: 'hidden',
    }}>
      <div style={{ position:'absolute', left:0, top:0, bottom:0, width:3, background: TOKENS.verified }}/>
      <div style={{ display:'flex', alignItems:'center', gap: 8, marginBottom: 6 }}>
        <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke={iconColor} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/>
        </svg>
        <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.22em', color: TOKENS.verified }}>PRECEDENT</span>
      </div>
      <div style={{ fontSize: 14, color: TOKENS.text, lineHeight: 1.35, fontWeight: 500 }}>{headline}</div>
      {support && <div style={{ marginTop: 6, fontSize: 10, color: TOKENS.textSubtle, letterSpacing: '0.04em' }}>{support}</div>}
      <div style={{ marginTop: 10 }}><SportradarBadge small/></div>
    </div>
  );
}

// COUNTER-NARRATIVE card — drama for the losing side
function CounterNarrativeCard({ forSide = 'FRA', headline, support }) {
  return (
    <div style={{
      position:'relative',
      background: TOKENS.bgRaised,
      border: `1px solid ${TOKENS.border}`,
      borderRadius: 8,
      padding: '12px 14px 12px 20px',
      overflow: 'hidden',
    }}>
      <div style={{ position:'absolute', left:0, top:0, bottom:0, width:3, background: TOKENS.esoteric }}/>
      <div style={{ display:'flex', alignItems:'center', gap: 8, marginBottom: 6 }}>
        <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke={TOKENS.esoteric} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 2l3 7h7l-5.5 4.5 2 7L12 16l-6.5 4.5 2-7L2 9h7z"/>
        </svg>
        <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.22em', color: TOKENS.esoteric }}>COUNTER-NARRATIVE · FOR {forSide}</span>
      </div>
      <div style={{ fontSize: 13, color: TOKENS.text, lineHeight: 1.35 }}>{headline}</div>
      {support && <div style={{ marginTop: 6, fontSize: 10, color: TOKENS.textSubtle, letterSpacing: '0.04em' }}>{support}</div>}
      <div style={{ marginTop: 10 }}><SportradarBadge small/></div>
    </div>
  );
}

// ───── Running-score panel (compact, sits under the stack) ─────
function RunningScorePanel({ events = [], momentum }) {
  return (
    <div style={{
      background: TOKENS.bgRaised, border: `1px solid ${TOKENS.border}`,
      borderRadius: 8, padding: '10px 14px',
    }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom: 8 }}>
        <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.22em', color: TOKENS.textSubtle }}>RUNNING SCORE</span>
        {momentum && (
          <span style={{
            fontSize: 9, fontWeight: 700, letterSpacing: '0.18em',
            color: momentum.color, padding: '3px 7px',
            background: `${momentum.color}15`, borderRadius: 3,
            border: `1px solid ${momentum.color}40`,
          }}>{momentum.label}</span>
        )}
      </div>
      {events.length === 0 ? (
        <EmptyGridlines/>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
          {events.map((e, i) => (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '44px 20px 1fr auto', alignItems: 'center', gap: 8,
              fontSize: 11, color: TOKENS.textMuted,
            }}>
              <span style={{ fontVariantNumeric: 'tabular-nums', letterSpacing: '0.05em', color: TOKENS.textSubtle }}>{e.minute}</span>
              <span style={{
                width: 10, height: 10, borderRadius: 2, background: e.color || TOKENS.text,
                display: 'inline-block',
              }}/>
              <span style={{ color: TOKENS.text, letterSpacing: '0.02em' }}>{e.label}</span>
              <span style={{ fontSize: 10, color: TOKENS.textSubtle, fontVariantNumeric: 'tabular-nums' }}>{e.score}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function EmptyGridlines() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {[0,1,2,3].map(i => (
        <div key={i} style={{
          height: 1, background: `repeating-linear-gradient(to right, ${TOKENS.borderSoft} 0 6px, transparent 6px 12px)`,
        }}/>
      ))}
      <div style={{ fontSize: 9, letterSpacing: '0.18em', color: TOKENS.textSubtle, marginTop: 4 }}>KICK-OFF IN 12:00</div>
    </div>
  );
}

// ───── Story reminder queue (with AI nudges) ─────
function StoryQueue({ items = [], title = 'STORY QUEUE' }) {
  return (
    <div style={{
      background: TOKENS.bgRaised, border: `1px solid ${TOKENS.border}`,
      borderRadius: 8, padding: '10px 14px',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.22em', color: TOKENS.textSubtle }}>{title}</span>
        <span style={{ fontSize: 9, letterSpacing: '0.14em', color: TOKENS.textSubtle }}>{items.filter(i=>i.state==='done').length}/{items.length}</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
        {items.map((it, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '16px 1fr auto', alignItems: 'center', gap: 8,
            fontSize: 11, color: it.state === 'done' ? TOKENS.textSubtle : TOKENS.text,
            textDecoration: it.state === 'done' ? 'line-through' : 'none',
          }}>
            <span>
              {it.state === 'done' ? (
                <svg viewBox="0 0 14 14" width="12" height="12"><rect width="14" height="14" rx="2" fill="none" stroke={TOKENS.verified} strokeWidth="1"/><path d="M3.5 7.5l2.5 2.5 5-5" stroke={TOKENS.verified} strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              ) : (
                <svg viewBox="0 0 14 14" width="12" height="12"><rect width="14" height="14" rx="2" fill="none" stroke={TOKENS.border} strokeWidth="1"/></svg>
              )}
            </span>
            <span style={{ lineHeight: 1.35 }}>{it.text}</span>
            {it.nudge && (
              <span style={{
                fontSize: 8, letterSpacing: '0.18em', fontWeight: 700,
                color: TOKENS.esoteric, padding: '2px 6px', borderRadius: 3,
                background: 'rgba(245,158,11,0.1)', border: `1px solid rgba(245,158,11,0.4)`,
              }}>AI NUDGE</span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ───── Voice-commanded widget — Frame 3 horizontal timeline ─────
function TranscriptOverlay({ text }) {
  return (
    <div style={{
      padding: '10px 14px',
      border: `1px solid ${TOKENS.live}`,
      background: 'rgba(239,68,68,0.06)',
      borderRadius: 8,
      display: 'flex', alignItems: 'center', gap: 10,
    }}>
      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke={TOKENS.live} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
        <rect x="9" y="2" width="6" height="12" rx="3"/>
        <path d="M5 10v1a7 7 0 0 0 14 0v-1"/>
      </svg>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 8, letterSpacing: '0.2em', color: TOKENS.live, marginBottom: 2 }}>YOU ASKED · 0.8s ago</div>
        <div style={{ fontSize: 12, color: TOKENS.text, lineHeight: 1.3, fontStyle: 'italic' }}>"{text}"</div>
      </div>
    </div>
  );
}

function VoiceWidget({ title, rows = [], pinned = false }) {
  return (
    <div style={{
      position: 'relative',
      background: TOKENS.bgRaised,
      border: `1px solid ${TOKENS.border}`,
      borderRadius: 10,
      padding: '12px 14px 14px',
      animation: 'bb-enter 360ms cubic-bezier(.2,.8,.2,1) both',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke={TOKENS.live} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
            <rect x="9" y="2" width="6" height="12" rx="3"/>
            <path d="M5 10v1a7 7 0 0 0 14 0v-1"/>
          </svg>
          <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: '0.22em', color: TOKENS.live }}>VOICE · WIDGET</span>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <WidgetBtn active={pinned} icon="pin" label="PIN"/>
          <WidgetBtn icon="x" label="✕"/>
        </div>
      </div>
      <div style={{
        fontSize: 12, fontWeight: 600, color: TOKENS.text, marginBottom: 10, letterSpacing: '0.01em',
      }}>{title}</div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {rows.map((r, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '54px 84px 60px 1fr', alignItems: 'center', gap: 8,
            fontSize: 11, color: TOKENS.textMuted, padding: '6px 0',
            borderTop: i === 0 ? 'none' : `1px solid ${TOKENS.borderSoft}`,
          }}>
            <span style={{ fontVariantNumeric: 'tabular-nums', color: TOKENS.textSubtle, letterSpacing: '0.05em' }}>{r.year}</span>
            <span style={{ color: TOKENS.text, letterSpacing: '0.02em' }}>{r.opponent}</span>
            <span style={{
              fontVariantNumeric: 'tabular-nums', fontWeight: 600, letterSpacing: '0.05em',
              color: r.result?.startsWith('W') ? TOKENS.verified : r.result?.startsWith('L') ? TOKENS.live : TOKENS.textMuted,
            }}>{r.result}</span>
            <span style={{ fontSize: 10, color: r.flag ? TOKENS.esoteric : TOKENS.textMuted, letterSpacing: '0.02em' }}>
              {r.flag && <span style={{ marginRight: 6 }}>⚠</span>}{r.note}
            </span>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <SportradarBadge small/>
        <span style={{ fontSize: 9, letterSpacing: '0.14em', color: TOKENS.textSubtle }}>tap row → expand</span>
      </div>
    </div>
  );
}

function WidgetBtn({ icon, label, active }) {
  return (
    <button style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 8px', borderRadius: 3,
      fontSize: 8, letterSpacing: '0.18em', fontWeight: 700,
      background: active ? 'rgba(16,185,129,0.1)' : TOKENS.bgSubtle,
      color: active ? TOKENS.verified : TOKENS.textMuted,
      border: `1px solid ${active ? TOKENS.verified : TOKENS.border}`,
      fontFamily: TOKENS.mono, cursor: 'pointer',
    }}>{icon === 'pin' && '📌'}{label}</button>
  );
}

// ───── Latency + utility bits ─────
// LatencyTag already exists in frame.jsx via window.

Object.assign(window, {
  LivePaneShell, ListeningDot, BottomBezel, Waveform,
  CardStack, StackCard,
  ScorerStatCard, PrecedentCard, CounterNarrativeCard,
  RunningScorePanel, StoryQueue,
  TranscriptOverlay, VoiceWidget,
});
