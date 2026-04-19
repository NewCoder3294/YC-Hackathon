# Audio Fixtures

4 WAV clips from the Peter Drury broadcast of Argentina vs France, 2022 WC Final. Used by `scripts/cactus-smoke.ts` to validate the Gemma 4 prompts and function toolbox without the RN runtime.

## Required files

| Filename | Event | Approx. timestamp in broadcast |
|----------|-------|-------------------------------|
| `messi-pen-23.wav` | Messi's 23rd-minute penalty goal | ~23:00 match clock |
| `dimaria-36.wav` | Di María's 36th-minute goal | ~36:00 match clock |
| `mbappe-pen-80.wav` | Mbappé's 80th-minute penalty | ~80:00 match clock |
| `mbappe-81.wav` | Mbappé's 81st-minute open-play goal | ~81:00 match clock |

Target length: 3–5 seconds each, 16kHz mono 16-bit PCM (standard WAV).

## Producing the fixtures

1. Install `yt-dlp` and `ffmpeg`.
2. Pick a YouTube upload of the Peter Drury broadcast (e.g., a match highlight reel or the full commentary clip — confirm it's Drury before clipping).
3. Download the full audio track:

   ```bash
   yt-dlp -x --audio-format wav --audio-quality 0 -o full.%(ext)s "<youtube url>"
   ```

4. For each fixture, trim with `ffmpeg`:

   ```bash
   ffmpeg -i full.wav -ss 00:00:00 -t 5 -ac 1 -ar 16000 messi-pen-23.wav
   # replace -ss with the timestamp in the source video where the call starts,
   # -t with the clip length in seconds.
   ```

5. Confirm each clip contains the play-call plus the first ~2 seconds of reaction. Don't include the replay reflection — we want pipeline-true "live" audio.

## Running the harness

Requires the Cactus CLI on `PATH` with `google/functiongemma-270m-it` already downloaded (see root README setup steps).

```bash
cd app
npm run smoke
```

Expected output per clip: a classifier JSON with `stat_opportunity: true` and a plausible `event_type`, followed by a generate JSON with a grounded `stat_text`. If a clip shows `trust_escape: true`, inspect the transcript — that's the prompt-tuning signal.

## Licensing

These clips are used as a test input for a hackathon demo under fair-use excerpt rules. They are NOT bundled into the shipped app — only into the `app/assets/audio-fixtures/` directory used by the smoke harness, which is excluded from the iOS/Android build outputs.
