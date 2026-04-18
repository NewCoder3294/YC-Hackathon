// f1-components.jsx — BroadcastBrain Feature 1 (Overnight Auto-Build + Commentator Modes)
// Shared cell skeleton, three modes (Stats / Story / Tactical) that differ by data + emphasis.
// Reuses TOKENS from frame.jsx.

// ─── Pane headers (left pane for Feature 1) ───
function BoardHeader({ mode = 'STORY-FIRST', showModeChip = true, savedStyle = false }) {
  return (
    <div style={{
      display:'flex', alignItems:'center', justifyContent:'space-between',
      padding:'14px 20px',
      borderBottom:`1px solid ${TOKENS.borderSoft}`,
      background: TOKENS.bgRaised,
    }}>
      <div style={{ display:'flex', alignItems:'center', gap: 12 }}>
        <svg viewBox="0 0 64 64" width="24" height="24">
          <rect width="64" height="64" rx="12" fill="#0A0A0A"/>
          <rect x="0.5" y="0.5" width="63" height="63" rx="11.5" stroke="#262626"/>
          <g transform="translate(16 16)">
            <rect x="0" y="0" width="3" height="32" fill="#FAFAFA"/>
            <rect x="7" y="4" width="3" height="10" fill="#FAFAFA"/>
            <rect x="14" y="2" width="3" height="14" fill="#FAFAFA"/>
            <rect x="21" y="6" width="3" height="6" fill="#EF4444"/>
            <rect x="28" y="3" width="3" height="12" fill="#FAFAFA"/>
          </g>
        </svg>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.2em', color: TOKENS.text }}>BROADCASTBRAIN</span>
        <span style={{ fontSize: 11, color: TOKENS.textSubtle, letterSpacing: '0.12em' }}>· SPOTTING BOARD</span>
        {showModeChip && <ModeChip mode={mode} saved={savedStyle}/>}
      </div>
      <div style={{ display:'flex', gap: 10, fontSize: 10, letterSpacing:'0.15em', color: TOKENS.textSubtle, alignItems:'center' }}>
        {savedStyle && <SavedStyleBadge/>}
        <span>DENSITY</span>
        <DensitySlider value="STANDARD"/>
        <span>·</span>
        <span>EXPORT PDF</span>
      </div>
    </div>
  );
}

function ModeChip({ mode, saved }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap: 8,
      padding:'5px 10px', borderRadius: 4,
      background: TOKENS.bgSubtle, border:`1px solid ${TOKENS.border}`,
    }}>
      <svg width="10" height="10" viewBox="0 0 10 10"><circle cx="5" cy="5" r="2.5" fill={TOKENS.verified}/></svg>
      <span style={{ fontSize: 9, fontWeight: 700, letterSpacing:'0.18em', color: TOKENS.text }}>MODE · {mode}</span>
      <span style={{ fontSize: 9, color: TOKENS.textSubtle, letterSpacing:'0.14em' }}>▾</span>
    </div>
  );
}

function SavedStyleBadge() {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap: 5,
      padding:'3px 8px', borderRadius: 3,
      background: 'rgba(16,185,129,0.08)', border:`1px solid rgba(16,185,129,0.4)`,
      color: TOKENS.verified, fontSize: 9, fontWeight: 700, letterSpacing: '0.18em',
    }}>
      <svg viewBox="0 0 14 14" width="10" height="10" fill="none" stroke={TOKENS.verified} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
        <path d="M3 7l3 3 5-6"/>
      </svg>
      MY STYLE · SAVED
    </div>
  );
}

function DensitySlider({ value = 'STANDARD' }) {
  const options = ['COMPACT','STANDARD','FULL'];
  return (
    <div style={{
      display:'inline-flex', background: TOKENS.bgSubtle, border: `1px solid ${TOKENS.border}`,
      borderRadius: 3, padding: 2,
    }}>
      {options.map(o => (
        <span key={o} style={{
          padding: '2px 7px',
          fontSize: 9, fontWeight: 700, letterSpacing: '0.14em',
          color: o === value ? TOKENS.text : TOKENS.textSubtle,
          background: o === value ? TOKENS.bgHover : 'transparent',
          borderRadius: 2,
        }}>{o}</span>
      ))}
    </div>
  );
}

// ─── Team header with formation (Tactical mode shows formation string) ───
function TeamHeaderF1({ nation, code, formation, count, accent, showFormation }) {
  return (
    <div style={{
      padding:'10px 16px',
      display:'flex', alignItems:'center', gap: 10,
      background: TOKENS.bgRaised,
      borderBottom: `1px solid ${TOKENS.borderSoft}`,
    }}>
      <div style={{ width: 4, height: 20, background: accent, borderRadius: 2 }}/>
      <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.14em', color: TOKENS.text }}>{nation}</div>
      <span style={{ fontSize: 9, color: TOKENS.textSubtle, letterSpacing: '0.14em' }}>{code}</span>
      {showFormation && (
        <div style={{
          padding: '2px 7px', fontSize: 9, fontWeight: 700, letterSpacing: '0.18em',
          background: TOKENS.bgSubtle, border: `1px solid ${TOKENS.border}`, borderRadius: 3,
          color: TOKENS.esoteric,
        }}>{formation}</div>
      )}
      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ fontSize: 9, color: TOKENS.textSubtle, letterSpacing: '0.14em' }}>{count} PLAYERS</span>
        <SportradarBadge small/>
      </div>
    </div>
  );
}

// ─── Mini pitch for Tactical mode ───
function MiniPitch({ formation = '4-3-3', nation = 'ARG' }) {
  // Position dots roughly by formation. Pitch rendered left-to-right attack.
  const positions = {
    '4-3-3': [
      { x:  8, y: 50, r: 'GK' },
      { x: 22, y: 15 }, { x: 22, y: 38 }, { x: 22, y: 62 }, { x: 22, y: 85 },
      { x: 48, y: 30 }, { x: 48, y: 50 }, { x: 48, y: 70 },
      { x: 76, y: 20 }, { x: 82, y: 50, hl: true }, { x: 76, y: 80 },
    ],
    '4-2-3-1': [
      { x:  8, y: 50, r: 'GK' },
      { x: 22, y: 15 }, { x: 22, y: 38 }, { x: 22, y: 62 }, { x: 22, y: 85 },
      { x: 40, y: 35 }, { x: 40, y: 65 },
      { x: 60, y: 22 }, { x: 60, y: 50 }, { x: 60, y: 78 },
      { x: 86, y: 50, hl: true },
    ],
  };
  const dots = positions[formation] || positions['4-3-3'];
  const accent = nation === 'ARG' ? TOKENS.text : TOKENS.textMuted;
  return (
    <svg viewBox="0 0 140 80" width="140" height="80" style={{ display: 'block' }}>
      {/* pitch */}
      <rect x="2" y="2" width="136" height="76" rx="2" fill="#0e1c12" stroke={TOKENS.border} strokeWidth="0.5"/>
      <line x1="70" y1="2" x2="70" y2="78" stroke={TOKENS.border} strokeWidth="0.5"/>
      <circle cx="70" cy="40" r="9" fill="none" stroke={TOKENS.border} strokeWidth="0.5"/>
      <rect x="2" y="22" width="14" height="36" fill="none" stroke={TOKENS.border} strokeWidth="0.5"/>
      <rect x="124" y="22" width="14" height="36" fill="none" stroke={TOKENS.border} strokeWidth="0.5"/>
      {/* dots */}
      {dots.map((d, i) => (
        <g key={i}>
          <circle cx={d.x} cy={d.y*0.8+2} r="2.4" fill={d.hl ? TOKENS.live : accent}/>
          {d.hl && <circle cx={d.x} cy={d.y*0.8+2} r="4.5" fill="none" stroke={TOKENS.live} strokeWidth="0.5" strokeOpacity="0.5"/>}
        </g>
      ))}
    </svg>
  );
}

// ─── The shared player cell skeleton. Mode = STATS | STORY | TACTICAL ───
function PlayerCell({
  mode = 'STORY',
  n, pos, name, nation,
  // STATS-mode data
  xg, xa, prog, pressures, shotAcc, rank,
  // STORY-mode data
  age, storyHero, storyLines = [],
  // TACTICAL-mode data
  role, formationRole, pressingMap, defActions, keyPasses,
  // Shared
  heroLabel, stats = [],
  storyline, matchupNote,
  accent = TOKENS.text,
  highlight = false,
  annotation = null,
  density = 'STANDARD',
  pinnedByCommentator = false,
}) {
  const isCompact = density === 'COMPACT';
  return (
    <div style={{
      position:'relative',
      background: highlight ? TOKENS.bgSubtle : TOKENS.bgRaised,
      border: `1px solid ${highlight ? TOKENS.border : TOKENS.borderSoft}`,
      borderRadius: 6,
      padding: isCompact ? '10px 12px' : '12px 14px',
      overflow: 'hidden',
    }}>
      {highlight && <div style={{ position:'absolute', left: 0, top: 0, bottom: 0, width: 3, background: TOKENS.live }}/>}

      {/* Top row: number, pos, name, pin affordance */}
      <div style={{ display: 'grid', gridTemplateColumns: '34px 1fr auto', alignItems: 'center', gap: 10 }}>
        <div style={{
          width: 30, height: 30, borderRadius: 3,
          background: TOKENS.bgSubtle, border:`1px solid ${TOKENS.borderSoft}`,
          display:'flex', alignItems:'center', justifyContent:'center',
          fontSize: 12, fontWeight: 700, color: TOKENS.text,
        }}>{n}</div>
        <div>
          <div style={{ fontSize: 12, fontWeight: 600, color: TOKENS.text, letterSpacing: '0.02em' }}>{name}</div>
          <div style={{ fontSize: 9, color: TOKENS.textSubtle, letterSpacing: '0.14em', marginTop: 2 }}>
            {mode === 'TACTICAL' && formationRole ? formationRole : pos}
            {nation && <span style={{ marginLeft: 6 }}>· {nation}</span>}
            {mode === 'STATS' && rank && <span style={{ marginLeft: 6, color: TOKENS.verified }}>· {rank}</span>}
          </div>
        </div>
        {pinnedByCommentator && <PinBadge/>}
      </div>

      {/* Mode-specific body */}
      {mode === 'STATS' && !isCompact && (
        <StatsBody xg={xg} xa={xa} prog={prog} pressures={pressures} shotAcc={shotAcc}/>
      )}
      {mode === 'STORY' && !isCompact && (
        <StoryBody age={age} hero={storyHero} lines={storyLines}/>
      )}
      {mode === 'TACTICAL' && !isCompact && (
        <TacticalBody role={role} pressingMap={pressingMap} defActions={defActions} keyPasses={keyPasses}/>
      )}

      {/* Compact collapse */}
      {isCompact && (
        <div style={{ marginTop: 8, fontSize: 10, color: TOKENS.textMuted, letterSpacing: '0.02em' }}>
          {mode === 'STATS'   && `${xg ?? '—'} xG · ${xa ?? '—'} xA · ${prog ?? '—'} prog`}
          {mode === 'STORY'   && storyHero}
          {mode === 'TACTICAL'&& `${role ?? '—'} · ${defActions ?? '—'} def actions`}
        </div>
      )}

      {/* Sticky note annotation (if present) */}
      {annotation && <StickyAnnotation text={annotation}/>}

      {/* Footer */}
      <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <SportradarBadge small/>
        {mode === 'STORY' && highlight && <AddAnnotationBtn/>}
      </div>
    </div>
  );
}

// ─── STATS-mode body (big tabular numbers) ───
function StatsBody({ xg, xa, prog, pressures, shotAcc }) {
  const Stat = ({ label, value, accent }) => (
    <div>
      <div style={{ fontSize: 8, letterSpacing: '0.18em', color: TOKENS.textSubtle }}>{label}</div>
      <div style={{
        fontSize: 22, fontWeight: 700, color: accent || TOKENS.text,
        fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em', lineHeight: 1.1,
      }}>{value ?? '—'}</div>
    </div>
  );
  return (
    <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, rowGap: 10 }}>
      <Stat label="xG" value={xg} accent={TOKENS.verified}/>
      <Stat label="xA" value={xa}/>
      <Stat label="PROG CARRY" value={prog}/>
      <Stat label="PRESSURES" value={pressures}/>
      <Stat label="SHOT %" value={shotAcc}/>
      <Stat label="PPDA" value="—"/>
    </div>
  );
}

// ─── STORY-mode body (hero emotional stat + italic narrative lines) ───
function StoryBody({ age, hero, lines = [] }) {
  return (
    <div style={{ marginTop: 10 }}>
      <div style={{
        fontSize: 14, fontWeight: 600, color: TOKENS.text, lineHeight: 1.35, letterSpacing: '0.005em',
      }}>{hero}</div>
      {lines.length > 0 && (
        <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 4 }}>
          {lines.map((l, i) => (
            <div key={i} style={{
              fontSize: 11, color: TOKENS.textMuted, lineHeight: 1.4,
              fontStyle: 'italic', letterSpacing: '0.005em',
              paddingLeft: 10, borderLeft: `1px solid ${TOKENS.borderSoft}`,
            }}>{l}</div>
          ))}
        </div>
      )}
      {age && (
        <div style={{ marginTop: 8, fontSize: 9, color: TOKENS.textSubtle, letterSpacing: '0.14em' }}>AGE {age}</div>
      )}
    </div>
  );
}

// ─── TACTICAL body (formation role, pressing role, defensive actions) ───
function TacticalBody({ role, pressingMap, defActions, keyPasses }) {
  return (
    <div style={{ marginTop: 10 }}>
      <div style={{ fontSize: 10, color: TOKENS.textMuted, letterSpacing: '0.08em', lineHeight: 1.45 }}>{role}</div>
      <div style={{ marginTop: 10, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
        <TacticalChip label="DEF ACTIONS" value={defActions}/>
        <TacticalChip label="KEY PASSES" value={keyPasses}/>
        <TacticalChip label="PRESS ZONE" value={pressingMap}/>
      </div>
    </div>
  );
}
function TacticalChip({ label, value }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      <span style={{ fontSize: 8, letterSpacing: '0.18em', color: TOKENS.textSubtle }}>{label}</span>
      <span style={{ fontSize: 12, fontWeight: 700, color: TOKENS.esoteric, marginTop: 2 }}>{value ?? '—'}</span>
    </div>
  );
}

// ─── Affordances ───
function PinBadge() {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap: 4,
      padding: '3px 6px', borderRadius: 3,
      background: 'rgba(16,185,129,0.08)', border:`1px solid rgba(16,185,129,0.3)`,
      color: TOKENS.verified, fontSize: 8, fontWeight: 700, letterSpacing: '0.16em',
    }}>📌 PINNED</div>
  );
}

function AddAnnotationBtn() {
  return (
    <button style={{
      display:'inline-flex', alignItems:'center', gap: 4,
      padding: '3px 7px', borderRadius: 3,
      background: TOKENS.bgSubtle, border:`1px dashed ${TOKENS.border}`,
      color: TOKENS.textMuted, fontSize: 8, fontWeight: 700, letterSpacing: '0.16em',
      fontFamily: TOKENS.mono, cursor: 'pointer',
    }}>+ ANNOTATE</button>
  );
}

function StickyAnnotation({ text }) {
  return (
    <div style={{
      marginTop: 10,
      position: 'relative',
      background: '#f4e27a',
      color: '#3d2d0a',
      padding: '10px 12px',
      fontFamily: '"Comic Sans MS", "Marker Felt", cursive',
      fontSize: 12, lineHeight: 1.3,
      boxShadow: '0 2px 6px rgba(0,0,0,0.35)',
      transform: 'rotate(-1.2deg)',
      borderRadius: 2,
    }}>
      <div style={{
        position:'absolute', top: -4, left: 10, width: 22, height: 8,
        background: 'rgba(0,0,0,0.18)', borderRadius: 1,
      }}/>
      <div style={{ fontSize: 8, letterSpacing: '0.22em', fontWeight: 700, color: 'rgba(61,45,10,0.65)', marginBottom: 4, fontFamily: TOKENS.mono }}>MY NOTE</div>
      {text}
    </div>
  );
}

// ─── MODE PICKER CARD (Frame 1) ───
function ModePickerCard() {
  const modes = [
    { id: 'STATS',    label: 'STATS-FIRST',  sub: 'xG · xA · progressive carries. Numbers lead.',      hint: "I'm the data guy — Bob Heussler, Brooklyn Nets" },
    { id: 'STORY',    label: 'STORY-FIRST',  sub: 'Arcs, family, milestones. Narrative leads.',          hint: "Pat McCarthy — 'stories woven organically'", recommended: true },
    { id: 'TACTICAL', label: 'TACTICAL',     sub: 'Formations, pressing, roles. Function leads.',        hint: 'For Euro/World Cup football commentators' },
  ];
  return (
    <div style={{
      width: 480,
      background: TOKENS.bgRaised,
      border: `1px solid ${TOKENS.border}`,
      borderRadius: 10,
      padding: '20px 22px 18px',
      boxShadow: '0 18px 50px rgba(0,0,0,0.6)',
    }}>
      <div style={{ display:'flex', alignItems:'center', gap: 10 }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={TOKENS.verified} strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 7l3 3 5-6"/>
          <path d="M3 13l3 3 5-6"/>
          <path d="M3 19l3 3 5-6"/>
          <path d="M14 8h7"/><path d="M14 14h7"/><path d="M14 20h7"/>
        </svg>
        <div>
          <div style={{ fontSize: 10, letterSpacing: '0.22em', color: TOKENS.verified, fontWeight: 700 }}>READY · PRE-INDEXED OVERNIGHT</div>
          <div style={{ fontSize: 18, fontWeight: 700, color: TOKENS.text, marginTop: 4, letterSpacing: '-0.01em' }}>Pick your commentator style.</div>
          <div style={{ fontSize: 11, color: TOKENS.textMuted, marginTop: 6, lineHeight: 1.5 }}>
            0 minutes of your prep. <span style={{ color: TOKENS.text, fontWeight: 600 }}>46 players</span> ·
            <span style={{ color: TOKENS.text, fontWeight: 600 }}> 184 storylines</span> ·
            <span style={{ color: TOKENS.text, fontWeight: 600 }}> 23 precedent patterns</span> pre-indexed.
          </div>
        </div>
      </div>

      <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {modes.map(m => <ModeOption key={m.id} mode={m}/>)}
      </div>

      <div style={{ marginTop: 14, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 10, color: TOKENS.textSubtle, letterSpacing: '0.14em' }}>MODE IS A PREFERENCE — NOT A CAGE.</span>
        <span style={{ fontSize: 10, color: TOKENS.textMuted, letterSpacing: '0.14em', textDecoration: 'underline', cursor: 'pointer' }}>SKIP · CUSTOMIZE FROM SCRATCH</span>
      </div>
    </div>
  );
}

function ModeOption({ mode }) {
  return (
    <div style={{
      position: 'relative',
      display: 'grid', gridTemplateColumns: '110px 1fr auto', alignItems: 'center', gap: 14,
      padding: '10px 12px',
      background: TOKENS.bgSubtle,
      border: `1px solid ${mode.recommended ? TOKENS.border : TOKENS.borderSoft}`,
      borderRadius: 6,
    }}>
      {/* tiny preview thumbnail */}
      <ModeThumbnail mode={mode.id}/>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.14em', color: TOKENS.text }}>{mode.label}</span>
          {mode.recommended && (
            <span style={{
              fontSize: 8, fontWeight: 700, letterSpacing: '0.18em', padding: '2px 6px',
              background: 'rgba(16,185,129,0.1)', color: TOKENS.verified, borderRadius: 3,
              border: `1px solid rgba(16,185,129,0.4)`,
            }}>RECOMMENDED FOR YOU</span>
          )}
        </div>
        <div style={{ fontSize: 10, color: TOKENS.textMuted, marginTop: 3, lineHeight: 1.4 }}>{mode.sub}</div>
        <div style={{ fontSize: 9, color: TOKENS.textSubtle, marginTop: 5, fontStyle: 'italic', letterSpacing: '0.02em' }}>{mode.hint}</div>
      </div>
      <svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke={TOKENS.textMuted} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 3l5 5-5 5"/>
      </svg>
    </div>
  );
}

// ─── Mode thumbnail previews (mini snippets of each cell look) ───
function ModeThumbnail({ mode }) {
  if (mode === 'STATS') {
    return (
      <div style={{
        height: 64, background: TOKENS.bgRaised, border: `1px solid ${TOKENS.borderSoft}`,
        borderRadius: 4, padding: '6px 8px',
      }}>
        <div style={{ fontSize: 7, letterSpacing: '0.14em', color: TOKENS.textSubtle }}>MESSI · xG</div>
        <div style={{ fontSize: 18, fontWeight: 700, color: TOKENS.verified, fontVariantNumeric: 'tabular-nums', lineHeight: 1 }}>5.2</div>
        <div style={{ display: 'flex', gap: 6, marginTop: 4 }}>
          <div><div style={{ fontSize: 6, color: TOKENS.textSubtle }}>xA</div><div style={{ fontSize: 10, fontWeight: 700, color: TOKENS.text }}>3.1</div></div>
          <div><div style={{ fontSize: 6, color: TOKENS.textSubtle }}>PROG</div><div style={{ fontSize: 10, fontWeight: 700, color: TOKENS.text }}>47</div></div>
        </div>
      </div>
    );
  }
  if (mode === 'STORY') {
    return (
      <div style={{
        height: 64, background: TOKENS.bgRaised, border: `1px solid ${TOKENS.borderSoft}`,
        borderRadius: 4, padding: '6px 8px',
      }}>
        <div style={{ fontSize: 7, letterSpacing: '0.14em', color: TOKENS.textSubtle }}>MESSI · #10</div>
        <div style={{ fontSize: 9, fontWeight: 600, color: TOKENS.text, marginTop: 2, lineHeight: 1.3 }}>5th & final<br/>World Cup</div>
        <div style={{ fontSize: 7, fontStyle: 'italic', color: TOKENS.textMuted, marginTop: 3, paddingLeft: 4, borderLeft: `1px solid ${TOKENS.borderSoft}` }}>last dance · 35</div>
      </div>
    );
  }
  // TACTICAL
  return (
    <div style={{
      height: 64, background: TOKENS.bgRaised, border: `1px solid ${TOKENS.borderSoft}`,
      borderRadius: 4, padding: '4px 6px',
    }}>
      <div style={{ fontSize: 7, letterSpacing: '0.14em', color: TOKENS.textSubtle }}>MESSI · NO.10 FREE</div>
      <svg viewBox="0 0 80 32" width="92" height="36" style={{ marginTop: 2 }}>
        <rect x="1" y="1" width="78" height="30" rx="1" fill="#0e1c12" stroke={TOKENS.border} strokeWidth="0.4"/>
        <circle cx="10" cy="16" r="1.3" fill={TOKENS.textMuted}/>
        {[8,16,24].map(y => <circle key={y} cx="22" cy={y*0.9+4} r="1.3" fill={TOKENS.textMuted}/>)}
        <circle cx="40" cy="12" r="1.3" fill={TOKENS.textMuted}/>
        <circle cx="40" cy="22" r="1.3" fill={TOKENS.textMuted}/>
        <circle cx="58" cy="10" r="1.8" fill={TOKENS.live}/>
        <circle cx="60" cy="16" r="1.3" fill={TOKENS.textMuted}/>
        <circle cx="58" cy="24" r="1.3" fill={TOKENS.textMuted}/>
      </svg>
      <div style={{ fontSize: 7, color: TOKENS.esoteric, letterSpacing: '0.1em', marginTop: 1 }}>3-3-2-2 FLEX</div>
    </div>
  );
}

// ─── Left pane empty state (Frame 1) ───
function BoardEmptyState() {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center', gap: 20,
      padding: 40, textAlign: 'center',
    }}>
      <svg width="64" height="64" viewBox="0 0 64 64" fill="none" stroke={TOKENS.textSubtle} strokeWidth="1.5">
        <rect x="8" y="8" width="48" height="48" rx="4" strokeDasharray="3 3"/>
        <path d="M24 32h16M32 24v16" strokeLinecap="round"/>
      </svg>
      <div>
        <div style={{ fontSize: 10, letterSpacing: '0.22em', color: TOKENS.textSubtle, fontWeight: 700 }}>ARG vs FRA · WC FINAL</div>
        <div style={{ fontSize: 20, fontWeight: 700, color: TOKENS.text, marginTop: 6, letterSpacing: '-0.01em' }}>Tap to build your board.</div>
        <div style={{ fontSize: 11, color: TOKENS.textMuted, marginTop: 8, lineHeight: 1.5, maxWidth: 360 }}>
          Overnight build complete: roster, stats, history, storylines, precedent patterns — all local, airplane-mode safe.
        </div>
      </div>
      <button style={{
        padding: '12px 22px',
        background: TOKENS.live, color: '#fff', border: 'none', borderRadius: 6,
        fontFamily: TOKENS.mono, fontSize: 11, fontWeight: 700, letterSpacing: '0.18em',
        cursor: 'pointer',
      }}>BUILD BOARD →</button>
      <div style={{ marginTop: 10, display: 'flex', gap: 16, fontSize: 9, color: TOKENS.textSubtle, letterSpacing: '0.16em' }}>
        <span>46 PLAYERS</span><span>·</span><span>184 STORYLINES</span><span>·</span><span>23 PRECEDENTS</span>
      </div>
    </div>
  );
}

// ─── Callout (for Frame 3 affordance annotations) ───
function Callout({ n, text, top, left, right, bottom, arrow = 'left' }) {
  return (
    <div style={{
      position: 'absolute', top, left, right, bottom, zIndex: 4,
      display: 'flex', alignItems: 'flex-start', gap: 8,
      maxWidth: 220,
    }}>
      <div style={{
        width: 22, height: 22, borderRadius: '50%',
        background: TOKENS.esoteric, color: '#1a1100',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 11, fontWeight: 700, flexShrink: 0,
        boxShadow: '0 4px 12px rgba(245,158,11,0.5)',
      }}>{n}</div>
      <div style={{
        background: '#fffbea',
        border: '1px solid rgba(245,158,11,0.4)',
        color: '#1a1614',
        padding: '8px 10px',
        borderRadius: 4,
        fontFamily: TOKENS.mono,
        fontSize: 10, lineHeight: 1.4, letterSpacing: '0.01em',
        boxShadow: '0 6px 16px rgba(0,0,0,0.3)',
      }}>{text}</div>
    </div>
  );
}

Object.assign(window, {
  BoardHeader, ModeChip, SavedStyleBadge, DensitySlider,
  TeamHeaderF1, MiniPitch,
  PlayerCell, StatsBody, StoryBody, TacticalBody,
  PinBadge, AddAnnotationBtn, StickyAnnotation,
  ModePickerCard, ModeOption, ModeThumbnail,
  BoardEmptyState, Callout,
});
