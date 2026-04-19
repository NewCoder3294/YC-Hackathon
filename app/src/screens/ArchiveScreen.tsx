import React, { useMemo, useState } from 'react';
import { Platform, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import Animated, { FadeIn, FadeOut, Layout } from 'react-native-reanimated';
import Svg, { Path, Rect } from 'react-native-svg';
import { IPadFrame } from '../frame/IPadFrame';
import { FONT_MONO, tokens } from '../theme/tokens';
import { ArchivedSession, MatchNote, useAgent } from '../agent/AgentContext';

type Tab = 'SESSIONS' | 'NOTES';

export function ArchiveScreen() {
  const { sessions, notes, deleteSession, deleteNote, updateNote } = useAgent();
  const [tab, setTab] = useState<Tab>('SESSIONS');
  const [openSessionId, setOpenSessionId] = useState<string | null>(null);
  const [openNoteId, setOpenNoteId] = useState<string | null>(null);

  const openSession = useMemo(
    () => sessions.find((s) => s.id === openSessionId) ?? null,
    [sessions, openSessionId],
  );
  const openNote = useMemo(() => notes.find((n) => n.id === openNoteId) ?? null, [notes, openNoteId]);

  return (
    <IPadFrame hidePattern>
      <View style={{ flex: 1, flexDirection: 'row' }}>
        {/* LEFT pane — tabs + list */}
        <View style={{ flex: 0.42, borderRightWidth: 1, borderRightColor: tokens.border }}>
          <View
            style={{
              paddingVertical: 18,
              paddingHorizontal: 20,
              minHeight: 128,
              borderBottomWidth: 1,
              borderBottomColor: tokens.borderSoft,
              backgroundColor: tokens.bgRaised,
              justifyContent: 'center',
            }}
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.textSubtle, fontWeight: '700' }}>
              ARCHIVE
            </Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 22, fontWeight: '700', color: tokens.text, marginTop: 6, letterSpacing: -0.3 }}>
              Past sessions & notes
            </Text>
            <View style={{ flexDirection: 'row', gap: 6, marginTop: 14 }}>
              <TabBtn label={`SESSIONS · ${sessions.length}`} active={tab === 'SESSIONS'} onPress={() => setTab('SESSIONS')} />
              <TabBtn label={`NOTES · ${notes.length}`}       active={tab === 'NOTES'}    onPress={() => setTab('NOTES')} />
            </View>
          </View>

          <ScrollView contentContainerStyle={{ padding: 14, gap: 8 }} showsVerticalScrollIndicator={false}>
            {tab === 'SESSIONS' && (
              sessions.length === 0 ? (
                <EmptyState label="No sessions yet." sub="Start the agent to record your first one." />
              ) : (
                sessions.map((s) => (
                  <Animated.View
                    key={s.id}
                    entering={FadeIn.duration(220)}
                    exiting={FadeOut.duration(160)}
                    layout={Layout.springify().damping(16)}
                  >
                    <SessionRow
                      session={s}
                      active={s.id === openSessionId}
                      onOpen={() => setOpenSessionId(s.id)}
                      onDelete={() => {
                        if (Platform.OS === 'web' && !window.confirm('Delete this session and its notes?')) return;
                        deleteSession(s.id);
                        if (openSessionId === s.id) setOpenSessionId(null);
                      }}
                    />
                  </Animated.View>
                ))
              )
            )}
            {tab === 'NOTES' && (
              notes.length === 0 ? (
                <EmptyState label="No notes yet." sub="Gemini writes a summary note after each session." />
              ) : (
                notes.map((n) => (
                  <Animated.View
                    key={n.id}
                    entering={FadeIn.duration(220)}
                    exiting={FadeOut.duration(160)}
                    layout={Layout.springify().damping(16)}
                  >
                    <NoteRow
                      note={n}
                      active={n.id === openNoteId}
                      onOpen={() => setOpenNoteId(n.id)}
                      onDelete={() => {
                        if (Platform.OS === 'web' && !window.confirm('Delete this note?')) return;
                        deleteNote(n.id);
                        if (openNoteId === n.id) setOpenNoteId(null);
                      }}
                    />
                  </Animated.View>
                ))
              )
            )}
          </ScrollView>
        </View>

        {/* RIGHT pane — detail view */}
        <View style={{ flex: 0.58 }}>
          {tab === 'SESSIONS' && openSession ? (
            <SessionDetail session={openSession} />
          ) : tab === 'NOTES' && openNote ? (
            <NoteDetail note={openNote} onSave={(p) => updateNote(openNote.id, p)} />
          ) : (
            <DetailPlaceholder tab={tab} />
          )}
        </View>
      </View>
    </IPadFrame>
  );
}

function TabBtn({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={{
        paddingVertical: 6,
        paddingHorizontal: 11,
        borderRadius: 4,
        backgroundColor: active ? tokens.bgHover : 'transparent',
        borderWidth: 1,
        borderColor: active ? tokens.border : tokens.borderSoft,
      }}
    >
      <Text
        style={{
          fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 1.6,
          color: active ? tokens.text : tokens.textSubtle,
        }}
      >
        {label}
      </Text>
    </Pressable>
  );
}

function SessionRow({
  session, active, onOpen, onDelete,
}: { session: ArchivedSession; active: boolean; onOpen: () => void; onDelete: () => void }) {
  const duration = Math.max(1, Math.floor((session.endedAt - session.startedAt) / 60000));
  return (
    <Pressable
      onPress={onOpen}
      style={({ hovered }: any) => ({
        padding: 12,
        borderRadius: 6,
        backgroundColor: active ? tokens.bgSubtle : hovered ? tokens.bgHover : tokens.bgRaised,
        borderWidth: 1,
        borderColor: active ? tokens.border : tokens.borderSoft,
      })}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.4, color: tokens.verified, fontWeight: '700' }}>
        ● SESSION
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 13, fontWeight: '600', color: tokens.text, marginTop: 4 }}>
        {session.match}
      </Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 6 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.2 }}>
          {fmtDate(session.startedAt)} · {duration}min · {session.points.length} points
        </Text>
        <View style={{ flex: 1 }} />
        <Pressable
          onPress={(e: any) => {
            e?.stopPropagation?.();
            onDelete();
          }}
          hitSlop={6}
        >
          <Svg width={12} height={12} viewBox="0 0 24 24" fill="none">
            <Path d="M6 6l12 12M18 6l-12 12" stroke={tokens.textSubtle} strokeWidth={1.5} strokeLinecap="round" />
          </Svg>
        </Pressable>
      </View>
    </Pressable>
  );
}

function NoteRow({
  note, active, onOpen, onDelete,
}: { note: MatchNote; active: boolean; onOpen: () => void; onDelete: () => void }) {
  const geminiAuto = note.source === 'gemini-auto';
  return (
    <Pressable
      onPress={onOpen}
      style={({ hovered }: any) => ({
        padding: 12,
        borderRadius: 6,
        backgroundColor: active ? tokens.bgSubtle : hovered ? tokens.bgHover : tokens.bgRaised,
        borderWidth: 1,
        borderColor: active ? tokens.border : tokens.borderSoft,
      })}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: '700',
            color: geminiAuto ? tokens.esoteric : tokens.verified,
          }}
        >
          ● {geminiAuto ? 'GEMINI · AUTO' : 'USER NOTE'}
        </Text>
      </View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '600', color: tokens.text, marginTop: 4 }}>
        {note.title}
      </Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 6 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.2 }}>
          {note.match} · {fmtDate(note.updatedAt)}
        </Text>
        <View style={{ flex: 1 }} />
        <Pressable
          onPress={(e: any) => {
            e?.stopPropagation?.();
            onDelete();
          }}
          hitSlop={6}
        >
          <Svg width={12} height={12} viewBox="0 0 24 24" fill="none">
            <Path d="M6 6l12 12M18 6l-12 12" stroke={tokens.textSubtle} strokeWidth={1.5} strokeLinecap="round" />
          </Svg>
        </Pressable>
      </View>
    </Pressable>
  );
}

function SessionDetail({ session }: { session: ArchivedSession }) {
  const duration = Math.max(1, Math.floor((session.endedAt - session.startedAt) / 60000));
  return (
    <View style={{ flex: 1 }}>
      <View
        style={{
          paddingVertical: 18,
          paddingHorizontal: 22,
          minHeight: 128,
          borderBottomWidth: 1,
          borderBottomColor: tokens.borderSoft,
          backgroundColor: tokens.bgRaised,
          justifyContent: 'center',
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.verified, fontWeight: '700' }}>
          ● ARCHIVED SESSION
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 20, fontWeight: '700', color: tokens.text, marginTop: 6, letterSpacing: -0.2 }}>
          {session.match}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginTop: 6, letterSpacing: 0.3 }}>
          {fmtDate(session.startedAt)} · {duration}min · {session.points.length} surfaces
        </Text>
      </View>
      <ScrollView contentContainerStyle={{ padding: 18, gap: 10 }} showsVerticalScrollIndicator={false}>
        {session.points.map((p) => (
          <View
            key={p.id}
            style={{
              paddingVertical: 10, paddingHorizontal: 12,
              backgroundColor: tokens.bgRaised,
              borderWidth: 1, borderColor: tokens.borderSoft, borderRadius: 5,
              borderLeftWidth: 3, borderLeftColor: tokens.live,
            }}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.6, color: tokens.live, fontWeight: '700' }}>
                ● {p.category?.toUpperCase() ?? 'NOTE'}
              </Text>
              {p.source && (
                <Text style={{ fontFamily: FONT_MONO, fontSize: 8, color: tokens.textSubtle, letterSpacing: 1.2 }}>
                  · {p.source}
                </Text>
              )}
            </View>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.text, lineHeight: 17 }}>
              {p.text}
            </Text>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

function NoteDetail({
  note, onSave,
}: { note: MatchNote; onSave: (patch: { title?: string; body?: string }) => void }) {
  const [title, setTitle] = useState(note.title);
  const [body, setBody] = useState(note.body);
  const [editing, setEditing] = useState(false);
  React.useEffect(() => {
    setTitle(note.title);
    setBody(note.body);
    setEditing(false);
  }, [note.id, note.title, note.body]);

  return (
    <View style={{ flex: 1 }}>
      <View
        style={{
          paddingVertical: 18,
          paddingHorizontal: 22,
          minHeight: 128,
          borderBottomWidth: 1,
          borderBottomColor: tokens.borderSoft,
          backgroundColor: tokens.bgRaised,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 14,
        }}
      >
        <View style={{ flex: 1 }}>
          <Text
            style={{
              fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, fontWeight: '700',
              color: note.source === 'gemini-auto' ? tokens.esoteric : tokens.verified,
            }}
          >
            ● {note.source === 'gemini-auto' ? 'GEMINI · AUTO SUMMARY' : 'USER NOTE'}
          </Text>
          {editing ? (
            <TextInput
              value={title}
              onChangeText={setTitle}
              style={
                {
                  fontFamily: FONT_MONO, fontSize: 20, fontWeight: '700', color: tokens.text,
                  marginTop: 6, letterSpacing: -0.2,
                  outlineStyle: 'none',
                } as any
              }
            />
          ) : (
            <Text style={{ fontFamily: FONT_MONO, fontSize: 20, fontWeight: '700', color: tokens.text, marginTop: 6, letterSpacing: -0.2 }}>
              {note.title}
            </Text>
          )}
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginTop: 4 }}>
            {note.match} · updated {fmtDate(note.updatedAt)}
          </Text>
        </View>
        <Pressable
          onPress={() => {
            if (editing) onSave({ title, body });
            setEditing(!editing);
          }}
          style={{
            paddingVertical: 8, paddingHorizontal: 12, borderRadius: 5,
            backgroundColor: editing ? tokens.live : tokens.bgSubtle,
            borderWidth: 1, borderColor: editing ? tokens.live : tokens.border,
          }}
        >
          <Text
            style={{
              fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 1.6,
              color: editing ? '#fff' : tokens.text,
            }}
          >
            {editing ? 'SAVE' : 'EDIT'}
          </Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={{ padding: 22 }} showsVerticalScrollIndicator={false}>
        {editing ? (
          <TextInput
            value={body}
            onChangeText={setBody}
            multiline
            style={
              {
                fontFamily: FONT_MONO, fontSize: 13, color: tokens.text, lineHeight: 19,
                minHeight: 400,
                outlineStyle: 'none',
                textAlignVertical: 'top',
              } as any
            }
          />
        ) : (
          <Text style={{ fontFamily: FONT_MONO, fontSize: 13, color: tokens.text, lineHeight: 19 }}>
            {note.body}
          </Text>
        )}
      </ScrollView>
    </View>
  );
}

function DetailPlaceholder({ tab }: { tab: Tab }) {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 40 }}>
      <Svg width={56} height={56} viewBox="0 0 24 24" fill="none">
        <Rect x={3} y={3} width={18} height={18} rx={3} stroke={tokens.textSubtle} strokeWidth={1.5} strokeDasharray="2 2" />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginTop: 14, letterSpacing: 1.4 }}>
        SELECT A {tab === 'SESSIONS' ? 'SESSION' : 'NOTE'} TO VIEW
      </Text>
    </View>
  );
}

function EmptyState({ label, sub }: { label: string; sub: string }) {
  return (
    <View style={{ padding: 18, alignItems: 'flex-start' }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 1.6, color: tokens.textMuted }}>
        {label}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, marginTop: 4, lineHeight: 14 }}>
        {sub}
      </Text>
    </View>
  );
}

function fmtDate(ts: number): string {
  const d = new Date(ts);
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) +
    ' · ' +
    d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}
