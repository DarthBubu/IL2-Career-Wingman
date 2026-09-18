# Career Wingman TTS Provider Architecture

Status: proposed integration design, verified against provider documentation on 2026-09-18.

## Decision

Use a provider-neutral speech worker with three playback tiers:

1. **Tier 0: pre-generated local clips** for break calls, warnings, acknowledgements and other urgent tactical speech.
2. **Tier 1: online streaming TTS** for short dynamic radio lines. Gemini Flash TTS is the recommended first adapter.
3. **Tier 2: local fallback TTS** when the network, quota or provider is unavailable.

Cloud speech must never be required for a time-critical warning. The scheduler may replace a delayed cloud line with a cached equivalent or omit a low-priority line.

## Why Gemini Flash TTS is the first candidate

The Gemini Developer API currently provides:

- Gemini 3.1 Flash TTS Preview, described by Google as low-latency and controllable.
- Streaming audio output for TTS models beginning with version 3.1.
- Natural-language control of accent, pace, style and tone.
- Single-speaker output and two-speaker generation.
- A free developer tier for Gemini 3.1 Flash TTS.
- Paid pricing of USD 1 per million input text tokens and USD 20 per million output audio tokens.
- Audio metering at 25 tokens per second.

At paid rates, 3.1 Flash output therefore costs approximately USD 0.03 per generated audio minute:
25 tokens/second × 60 seconds × USD 20/1,000,000.

Gemini 2.5 Flash Preview TTS is listed at USD 0.50 per million input text tokens and USD 10 per million output audio tokens, or approximately USD 0.015 per audio minute, but the 3.1 API is preferable for initial low-latency experiments because Google explicitly documents streamed TTS chunks for 3.1.

The free tier has two important conditions: actual quotas are project/model dependent and not guaranteed, and Google states that free-tier content may be used to improve its products. Paid-tier content is listed as not used for that purpose.

## Provider comparison

| Provider | Current free allowance | Paid reference | Low-latency characteristics | Role |
|---|---:|---:|---|---|
| Gemini 3.1 Flash TTS Preview | Developer API free tier; quota varies | ~USD 0.03/audio minute plus negligible text input | Streaming audio documented; style/accent/pacing prompts | Recommended prototype primary |
| Gemini 2.5 Flash Preview TTS | Developer API free tier | ~USD 0.015/audio minute | Described as low-latency; 3.1 has the clearer streaming path | Cost-oriented alternate |
| Google Cloud Standard/WaveNet | 4M characters/month | USD 4/1M characters | Conventional TTS; less expressive than Gemini | Stable inexpensive fallback |
| Azure Neural TTS F0 | 0.5M characters/month | Region-dependent | Real-time synthesis via SDK or REST | Strong second adapter |
| Amazon Polly | New-account limits: Standard 5M, Neural 1M characters/month for first 12 months | USD 4/1M Standard; USD 16/1M Neural | Designed for application synthesis; cache/replay allowed | Reliable fallback |
| ElevenLabs Flash/Turbo | 20k characters shown for free/API plan | USD 0.05/1k characters | Provider states approximately 75 ms model latency | Optional premium-quality adapter |

Free plans and preview models may change; the application must discover configuration at startup and never assume a permanent quota.

## Runtime topology

```text
Validated radio line
    -> SpeechRequest
    -> cache lookup
    -> provider router
       -> Gemini streaming adapter
       -> secondary cloud adapter
       -> local fallback
    -> PCM jitter buffer
    -> radio DSP
    -> priority mixer
    -> output device
```

The speech worker exposes a local API to the Go core:

```json
{
  "request_id": "mission-event-line",
  "speaker_id": "red-2",
  "text": "Red Two, bandits high, two o'clock.",
  "urgency": "tactical",
  "voice_profile": "raf-young-calm",
  "deadline_ms": 900,
  "interruptible": true
}
```

The provider returns PCM chunks plus status events:

- accepted
- first_audio
- completed
- throttled
- timed_out
- failed

## Gemini adapter

Use the Gemini Interactions API with:

- model configured rather than compiled into the application;
- audio response format;
- one named voice per pilot profile;
- `stream: true`;
- short prompts containing only performance instructions and the validated line;
- a bounded deadline and cancellation token.

Do not ask Gemini TTS to create the dialogue. The conversation engine must finalize and validate the exact transcript first. TTS performs speech rendering only.

Audio arrives as base64 PCM chunks. Decode each chunk, enqueue it in a short jitter buffer, then apply the common radio filter. Playback may begin after enough audio is buffered to avoid underruns rather than waiting for the complete WAV.

Gemini multi-speaker generation is limited to two configured speakers and is unsuitable for the live eight-aircraft queue. Generate each radio transmission independently so scheduling, interruption, voice identity and channel occupancy remain under Career Wingman's control.

## Voice identity

Store logical profiles independently of providers:

```yaml
speaker_id: red-2
traits:
  service: RAF
  age_band: young
  delivery: restrained
providers:
  gemini:
    voice: Kore
    instruction: concise RAF radio delivery, clipped pace
  azure:
    voice: configured-voice-id
  polly:
    voice: configured-voice-id
```

A provider switch must not change the pilot's database identity. Exact vocal similarity across providers cannot be guaranteed.

Do not clone real persons without appropriate permission. Prefer provider-supplied voices and fictional pilot identities.

## Latency policy

Measure real Malaysian network performance rather than relying on marketing latency:

- DNS/TLS connection time
- request-to-first-audio
- buffer-to-playback
- total generation time
- 429/error rate
- underrun count

Recommended acceptance gates:

- urgent calls: local/cached only, playback start target below 300 ms;
- tactical cloud calls: first playback target below 900 ms at p95;
- narrative cloud calls: below 2 seconds at p95;
- after the deadline: fall back, shorten, or drop according to priority.

Keep HTTP connections warm and reuse the provider client. Do not send a new TLS handshake for every transmission.

## Caching and cost control

Cache by a hash of:

- provider and model version
- voice and style instruction
- normalized text
- speaking-rate configuration
- DSP version

Maintain:

- permanent packs for standard doctrine calls;
- mission cache for likely acknowledgements and briefing names;
- runtime LRU cache for generated lines.

At mission load, synthesize predictable non-urgent lines while the player is briefing. Do not pre-generate speculative large conversations because this consumes quota and can produce unused audio.

Set configurable daily/monthly request and audio-duration budgets. If the budget is reached, automatically use the secondary or local provider.

## Failure and privacy controls

- API keys belong in Windows Credential Manager or an encrypted per-user secret store, never in the repository, logs or browser JavaScript.
- The local UI sends requests to the local speech worker; it does not possess the cloud key.
- Redact file paths and personal identifiers from provider requests.
- Store provider name, model, latency and cost estimate, but not keys.
- Use exponential backoff with jitter for 429/5xx responses, bounded by the radio-line deadline.
- Add a circuit breaker so a failing provider is not called repeatedly during combat.
- Provide an offline-only switch.
- Inform users that free-tier Gemini data may be used by Google to improve products.

## Test plan

Build a TTS benchmark harness before connecting it to live missions:

1. Generate a fixed corpus of 100 WWII-style radio lines of varied length.
2. Test from the user's actual Malaysian connection at several times of day.
3. Record first-audio and completion latency, errors and audible consistency.
4. Test loss of internet, invalid key, quota exhaustion and provider 5xx/429.
5. Verify cached urgent calls remain available in every failure mode.
6. Conduct a 60-minute synthetic mission with eight speaker profiles.
7. Compare Gemini, Azure and one local fallback through the same radio DSP.

## Recommended delivery sequence

- **TTS-0:** provider interface, cache, WAV/PCM pipeline and local fallback.
- **TTS-1:** Gemini 3.1 streaming adapter and benchmark harness.
- **TTS-2:** voice-profile mapping, prewarming and provider health/circuit breaker.
- **TTS-3:** Azure or Polly secondary adapter.
- **TTS-4:** optional ElevenLabs adapter.
- **TTS-5:** controlled live-mission integration after latency gates pass.

## Sources

- Gemini TTS: https://ai.google.dev/gemini-api/docs/speech-generation
- Gemini pricing: https://ai.google.dev/gemini-api/docs/pricing
- Gemini rate limits: https://ai.google.dev/gemini-api/docs/rate-limits
- Google Cloud TTS pricing: https://cloud.google.com/text-to-speech/pricing
- Azure Speech pricing: https://azure.microsoft.com/en-us/pricing/details/speech/
- Azure TTS overview: https://learn.microsoft.com/en-us/azure/ai-services/speech-service/text-to-speech
- Amazon Polly pricing: https://aws.amazon.com/polly/pricing/
- ElevenLabs API pricing: https://elevenlabs.io/pricing/api
