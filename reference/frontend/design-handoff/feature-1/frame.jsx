// frame.jsx — Shared iPad landscape frame primitive for BroadcastBrain Feature 2
// Dark theme, IBM Plex Mono, iPadOS status bar with airplane-mode glyph on every frame.

const TOKENS = {
  bgBase:    '#050505',
  bgRaised:  '#0A0A0A',
  bgSubtle:  '#141414',
  bgHover:   '#171717',
  border:    '#262626',
  borderSoft:'#1A1A1A',
  text:      '#FAFAFA',
  textMuted: '#A3A3A3',
  textSubtle:'#737373',
  live:      '#EF4444',
  verified:  '#10B981',
  esoteric:  '#F59E0B',
  mono: "'IBM Plex Mono', 'JetBrains Mono', ui-monospace, monospace",
};

// iPad landscape internal canvas size (pts-ish — scaled by the artboard container)
const IPAD = { W: 1366, H: 1024 };

// ───────── iPadOS status bar ─────────
// Left: time. Right: airplane-mode glyph, battery. This is the demo's thesis.
function StatusBar({ minute = '9:41' }) {
  return (
    <div style={{
      height: 28, padding: '0 22px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      fontFamily: TOKENS.mono,
      fontSize: 13, fontWeight: 600,
      color: TOKENS.text,
      letterSpacing: 0,
      background: 'transparent',
      position: 'relative', zIndex: 2,
    }}>
      <span>{minute}</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        {/* airplane-mode glyph — SF-ish */}
        <svg width="16" height="16" viewBox="0 0 24 24" fill={TOKENS.text} aria-label="Airplane mode">
          <path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 1 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>
        </svg>
        {/* battery */}
        <div style={{ display:'flex', alignItems:'center', gap: 2 }}>
          <span style={{ fontSize: 11, color: TOKENS.textMuted, marginRight: 2 }}>86%</span>
          <div style={{
            width: 24, height: 11, borderRadius: 3,
            border: `1px solid ${TOKENS.text}`, opacity: 0.9,
            padding: 1, boxSizing: 'border-box',
          }}>
            <div style={{ width: '80%', height: '100%', background: TOKENS.text, borderRadius: 1 }} />
          </div>
          <div style={{ width: 2, height: 5, background: TOKENS.text, borderRadius: 1, marginLeft: 1, opacity: 0.9 }} />
        </div>
      </div>
    </div>
  );
}

// ───────── Full iPad frame (landscape) ─────────
function IPadFrame({ children, bg = TOKENS.bgBase }) {
  return (
    <div style={{
      width: IPAD.W, height: IPAD.H,
      background: '#000',
      position: 'relative',
      overflow: 'hidden',
      borderRadius: 0,
      fontFamily: TOKENS.mono,
      color: TOKENS.text,
    }}>
      <div style={{
        position:'absolute', inset: 0,
        background: `radial-gradient(120% 80% at 50% -10%, #0c0c0c 0%, ${bg} 60%)`,
      }}/>
      <StatusBar />
      <div style={{ position:'relative', zIndex: 1, height: IPAD.H - 28 }}>
        {children}
      </div>
    </div>
  );
}

// ───────── Split layout primitive ─────────
function SplitLayout({ left, right }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '60% 40%', height: '100%' }}>
      <div style={{
        borderRight: `1px solid ${TOKENS.border}`,
        overflow: 'hidden',
        background: TOKENS.bgBase,
      }}>{left}</div>
      <div style={{
        overflow: 'hidden',
        background: TOKENS.bgBase,
      }}>{right}</div>
    </div>
  );
}

// ───────── App chrome (top-of-pane bars) ─────────
function LeftPaneHeader() {
  return (
    <div style={{
      display:'flex', alignItems:'center', justifyContent:'space-between',
      padding: '14px 20px',
      borderBottom: `1px solid ${TOKENS.borderSoft}`,
      background: TOKENS.bgRaised,
    }}>
      <div style={{ display:'flex', alignItems:'center', gap: 12 }}>
        {/* logo mark */}
        <svg viewBox="0 0 64 64" width="24" height="24">
          <rect width="64" height="64" rx="12" fill="#0A0A0A"/>
          <rect x="0.5" y="0.5" width="63" height="63" rx="11.5" stroke="#262626"/>
          <g transform="translate(16 16)">
            <rect x="0" y="0" width="3" height="32" fill="#FAFAFA"/>
            <rect x="7" y="4" width="3" height="10" fill="#FAFAFA"/>
            <rect x="14" y="2" width="3" height="14" fill="#FAFAFA"/>
            <rect x="21" y="6" width="3" height="6" fill="#EF4444"/>
            <rect x="28" y="3" width="3" height="12" fill="#FAFAFA"/>
            <rect x="7" y="18" width="3" height="10" fill="#FAFAFA"/>
            <rect x="14" y="16" width="3" height="14" fill="#FAFAFA"/>
            <rect x="21" y="20" width="3" height="6" fill="#FAFAFA"/>
            <rect x="28" y="17" width="3" height="12" fill="#FAFAFA"/>
          </g>
        </svg>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.2em', color: TOKENS.text }}>BROADCASTBRAIN</span>
        <span style={{ fontSize: 11, color: TOKENS.textSubtle, letterSpacing: '0.12em' }}>· SPOTTING BOARD</span>
      </div>
      <div style={{ display:'flex', gap: 10, fontSize: 10, letterSpacing: '0.15em', color: TOKENS.textSubtle }}>
        <span>FILTER</span>
        <span>·</span>
        <span>EDIT</span>
        <span>·</span>
        <span>EXPORT PDF</span>
      </div>
    </div>
  );
}

// ───────── Placeholder spotting-board (left pane) ─────────
function SpottingBoardPlaceholder({ highlight = null }) {
  const argentina = [
    { n:'10', pos:'FW', name:'LIONEL MESSI', note:'6 goals · last dance' },
    { n:'22', pos:'FW', name:'LAUTARO MARTÍNEZ', note:'0 goals · 85 mins' },
    { n:'11', pos:'MF', name:'ÁNGEL DI MARÍA', note:'back from injury' },
    { n:'20', pos:'MF', name:'ALEXIS MAC ALLISTER', note:'1 goal · 3 chances' },
    { n:'7',  pos:'MF', name:'RODRIGO DE PAUL', note:'team-high 44 recoveries' },
    { n:'5',  pos:'MF', name:'LEANDRO PAREDES', note:'set-piece delivery' },
    { n:'13', pos:'DF', name:'CRISTIAN ROMERO', note:'1 card · last match' },
    { n:'25', pos:'DF', name:'LISANDRO MARTÍNEZ', note:'92% duels won' },
    { n:'19', pos:'DF', name:'NICOLÁS OTAMENDI', note:'captain in back line' },
    { n:'3',  pos:'DF', name:'NICOLÁS TAGLIAFICO', note:'—' },
    { n:'23', pos:'GK', name:'EMILIANO MARTÍNEZ', note:'4 clean sheets · 1 shootout' },
  ];
  const france = [
    { n:'10', pos:'FW', name:'KYLIAN MBAPPÉ', note:'5 goals · Golden Boot race' },
    { n:'9',  pos:'FW', name:'OLIVIER GIROUD', note:'4 goals · WC record holder' },
    { n:'7',  pos:'FW', name:'ANTOINE GRIEZMANN', note:'0 G · team-high 5 assists' },
    { n:'14', pos:'MF', name:'ADRIEN RABIOT', note:'1 goal · out? flu watch' },
    { n:'8',  pos:'MF', name:'AURÉLIEN TCHOUAMÉNI', note:'88% pass accuracy' },
    { n:'13', pos:'MF', name:'YOUSSOUF FOFANA', note:'—' },
    { n:'5',  pos:'DF', name:'JULES KOUNDÉ', note:'0 goals conceded · 3 matches' },
    { n:'4',  pos:'DF', name:'RAPHAËL VARANE', note:'experience in finals' },
    { n:'18', pos:'DF', name:'DAYOT UPAMECANO', note:'—' },
    { n:'22', pos:'DF', name:'THEO HERNÁNDEZ', note:'subbing for Lucas' },
    { n:'1',  pos:'GK', name:'HUGO LLORIS', note:'captain · 145 caps' },
  ];
  return (
    <div style={{ height: '100%', display:'flex', flexDirection:'column' }}>
      <LeftPaneHeader />
      {/* squad header */}
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', borderBottom:`1px solid ${TOKENS.borderSoft}` }}>
        <TeamHeader accent={TOKENS.text} name="ARGENTINA" sub="ARG · 4-3-3" />
        <TeamHeader accent={TOKENS.textSubtle} name="FRANCE" sub="FRA · 4-2-3-1" borderLeft />
      </div>
      {/* roster grid */}
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', flex:1, overflow:'hidden' }}>
        <RosterCol players={argentina} highlight={highlight === 'MESSI' ? 0 : null}/>
        <RosterCol players={france} borderLeft highlight={highlight === 'MBAPPE' ? 0 : null}/>
      </div>
    </div>
  );
}

function TeamHeader({ accent, name, sub, borderLeft }) {
  return (
    <div style={{
      padding:'14px 20px',
      borderLeft: borderLeft ? `1px solid ${TOKENS.borderSoft}` : 'none',
      display:'flex', alignItems:'center', gap: 12,
      background: TOKENS.bgRaised,
    }}>
      <div style={{ width: 4, height: 22, background: accent, borderRadius: 2 }} />
      <div>
        <div style={{ fontSize: 13, fontWeight: 700, letterSpacing:'0.14em', color: TOKENS.text }}>{name}</div>
        <div style={{ fontSize: 10, letterSpacing:'0.12em', color: TOKENS.textSubtle, marginTop: 2 }}>{sub}</div>
      </div>
      <div style={{ marginLeft:'auto', display:'flex', alignItems:'center', gap: 6 }}>
        <SportradarBadge small />
      </div>
    </div>
  );
}

function RosterCol({ players, borderLeft, highlight }) {
  return (
    <div style={{
      padding: '10px 12px', overflow:'hidden',
      borderLeft: borderLeft ? `1px solid ${TOKENS.borderSoft}` : 'none',
      display:'grid', gridTemplateColumns:'1fr', gridAutoRows:'minmax(0, 1fr)', gap: 6,
    }}>
      {players.map((p, i) => (
        <PlayerRow key={i} {...p} active={highlight === i}/>
      ))}
    </div>
  );
}

function PlayerRow({ n, pos, name, note, active }) {
  return (
    <div style={{
      display:'grid',
      gridTemplateColumns:'44px 38px 1fr auto',
      alignItems:'center',
      gap: 10,
      padding: '10px 10px',
      background: active ? TOKENS.bgSubtle : TOKENS.bgRaised,
      border: `1px solid ${active ? TOKENS.border : TOKENS.borderSoft}`,
      borderRadius: 6,
      position:'relative',
    }}>
      {active && <div style={{ position:'absolute', left:-1, top:-1, bottom:-1, width:3, background: TOKENS.live, borderRadius:'2px 0 0 2px' }}/>}
      <div style={{
        width: 34, height: 34, borderRadius: 4,
        background: TOKENS.bgSubtle, border:`1px solid ${TOKENS.borderSoft}`,
        display:'flex', alignItems:'center', justifyContent:'center',
        fontSize: 13, fontWeight: 700, color: TOKENS.text, letterSpacing: 0,
      }}>{n}</div>
      <div style={{ fontSize: 9, letterSpacing:'0.15em', color: TOKENS.textSubtle }}>{pos}</div>
      <div>
        <div style={{ fontSize: 12, fontWeight: 600, color: TOKENS.text, letterSpacing:'0.02em' }}>{name}</div>
        <div style={{ fontSize: 10, color: TOKENS.textMuted, marginTop: 2 }}>{note}</div>
      </div>
      <div style={{ display:'flex', alignItems:'center' }}>
        <svg viewBox="0 0 24 24" width="11" height="11">
          <circle cx="12" cy="12" r="10" fill="#10B981" fillOpacity="0.1"/>
          <circle cx="12" cy="12" r="9.5" stroke="#10B981" strokeWidth="1"/>
          <path d="M7.5 12.5l3 3 6-6.5" stroke="#10B981" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
        </svg>
      </div>
    </div>
  );
}

// ───────── Badges / chips ─────────
function SportradarBadge({ small }) {
  const s = small ? 10 : 11;
  return (
    <div style={{ display:'flex', alignItems:'center', gap: 6, color: TOKENS.verified }}>
      <svg viewBox="0 0 24 24" width={small ? 12 : 14} height={small ? 12 : 14}>
        <circle cx="12" cy="12" r="10" fill="#10B981" fillOpacity="0.1"/>
        <circle cx="12" cy="12" r="9.5" stroke="#10B981" strokeWidth="1"/>
        <path d="M7.5 12.5l3 3 6-6.5" stroke="#10B981" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      </svg>
      <span style={{ fontSize: s, letterSpacing:'0.08em', color: TOKENS.verified }}>Sportradar</span>
    </div>
  );
}

function LivePill({ minute, phase = 'LIVE', color = TOKENS.live, dotAnim = true }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap: 8,
      padding: '6px 12px', borderRadius: 999,
      background: TOKENS.bgSubtle,
      border:`1px solid ${TOKENS.border}`,
    }}>
      <span style={{
        width: 8, height: 8, borderRadius: '50%', background: color,
        animation: dotAnim ? 'bb-pulse 1s ease-in-out infinite' : 'none',
      }}/>
      <span style={{ fontSize: 11, fontWeight: 700, letterSpacing:'0.18em', color: TOKENS.text }}>{phase}</span>
      {minute && <>
        <span style={{ color: TOKENS.textSubtle }}>·</span>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing:'0.1em', color: TOKENS.text }}>{minute}</span>
      </>}
    </div>
  );
}

function LatencyTag({ ms = '842ms' }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap: 6,
      padding: '4px 8px',
      fontSize: 10, letterSpacing:'0.08em',
      color: TOKENS.textSubtle,
      border: `1px solid ${TOKENS.borderSoft}`,
      borderRadius: 4,
      background: 'transparent',
    }}>
      <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke={TOKENS.textSubtle} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="13" r="8"/>
        <path d="M12 9v4l2.5 2"/>
        <path d="M9 2h6"/>
        <path d="M12 2v3"/>
      </svg>
      <span>{ms}</span>
    </div>
  );
}

Object.assign(window, {
  TOKENS, IPAD,
  IPadFrame, StatusBar, SplitLayout,
  SpottingBoardPlaceholder,
  SportradarBadge, LivePill, LatencyTag,
});
