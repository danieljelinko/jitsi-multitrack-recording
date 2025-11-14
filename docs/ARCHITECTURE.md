# Architecture - Jitsi Multitrack Recording

This document explains how the multitrack recording system works and how the components interact.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser (Participant)                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Jitsi Meet Web Interface                     │  │
│  │         (Audio/Video + WebRTC)                            │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/WebSocket
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Network                           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Jitsi Web (nginx)                        │ │
│  │            Serves static files + proxies API               │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              │ XMPP/BOSH                         │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Prosody (XMPP Server)                    │ │
│  │            Handles signaling and authentication            │ │
│  └────────────────────────────────────────────────────────────┘ │
│            │                                    │                │
│            │                                    │                │
│            ▼                                    ▼                │
│  ┌──────────────────┐              ┌────────────────────────┐   │
│  │     Jicofo       │              │   Jitsi Videobridge    │   │
│  │ (Conference      │◄────────────►│        (JVB)           │   │
│  │  Focus)          │              │   SFU Media Router     │   │
│  └──────────────────┘              └────────────────────────┘   │
│                                                 │                │
│                                                 │ WebSocket      │
│                                                 ▼                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │         Jitsi Multitrack Recorder (MTR)                    │ │
│  │   Receives individual audio streams → Writes .mka         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│                    ./recordings/room-*.mka                       │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Jitsi Meet Web Interface
**Role:** Frontend web application

**Responsibilities:**
- Serve the Jitsi Meet web UI to browsers
- Handle user interactions (join meeting, mute/unmute, etc.)
- Establish WebRTC connections with participants
- Proxy API calls to backend services

**Technology:**
- nginx web server
- React-based web application
- WebRTC for audio/video

**Container:** `jitsi/web`
**Ports:**
- 8000 (HTTP)
- 8443 (HTTPS, if enabled)

**Configuration Files:**
- `config/web/config.js` - Jitsi Meet configuration
- `config/web/interface_config.js` - UI customization

---

### 2. Prosody (XMPP Server)
**Role:** Signaling and authentication

**Responsibilities:**
- Handle XMPP signaling between clients and servers
- Manage authentication and authorization
- Coordinate communication between components
- Manage Multi-User Chat (MUC) rooms

**Technology:**
- Lua-based XMPP server
- BOSH (HTTP binding for XMPP)

**Container:** `jitsi/prosody`
**Ports:**
- 5222 (XMPP client connections)
- 5280 (BOSH/HTTP)
- 5347 (XMPP component connections)

**Configuration:**
- `config/prosody/prosody.cfg.lua` - Main configuration

**Key Domains:**
- `meet.jitsi` - Main XMPP domain
- `auth.meet.jitsi` - Authentication domain
- `muc.meet.jitsi` - Multi-User Chat domain
- `internal-muc.meet.jitsi` - Internal component MUC
- `recorder.meet.jitsi` - Recorder authentication domain

---

### 3. Jicofo (Jitsi Conference Focus)
**Role:** Conference management and orchestration

**Responsibilities:**
- Manage conference lifecycle (create, join, leave)
- Allocate participants to Jitsi Videobridges
- Coordinate media sessions
- Handle Jingle (XMPP extension for media negotiation)

**Technology:**
- Java application
- XMPP component

**Container:** `jitsi/jicofo`

**Configuration:**
- `config/jicofo/` - Jicofo configuration files

**Key Functions:**
- Receives join requests from Prosody
- Selects appropriate JVB for each participant
- Negotiates media codecs and parameters
- Coordinates recording sessions

---

### 4. Jitsi Videobridge (JVB)
**Role:** Selective Forwarding Unit (SFU) - Media router

**Responsibilities:**
- Route audio/video streams between participants
- **Key for multitrack:** Maintains separate streams per participant
- Forward media without mixing (crucial for separate recording)
- Handle NAT traversal (STUN/TURN)
- Optimize bandwidth usage

**Technology:**
- Java application
- WebRTC media server
- Operates as SFU (not MCU - no mixing!)

**Container:** `jitsi/jvb`
**Ports:**
- 10000/UDP (RTP/RTCP media)
- 4443/TCP (TCP fallback)

**Configuration:**
- `config/jvb/sip-communicator.properties` - Main JVB config
  ```properties
  org.jitsi.videobridge.ENABLE_MULTITRACK_RECORDER=true
  org.jitsi.videobridge.MULTITRACK_RECORDER_ENDPOINT=ws://recorder:8989/record
  ```

**Why JVB is Perfect for Multitrack Recording:**
- **SFU Architecture:** Doesn't mix streams, maintains individuality
- **Per-participant streams:** Each participant's audio stays separate
- **Direct forwarding:** Can stream individual tracks to recorder
- **Scalable:** Handles multiple participants efficiently

---

### 5. Jitsi Multitrack Recorder (MTR)
**Role:** Record separate audio tracks per participant

**Responsibilities:**
- Expose WebSocket endpoint (`:8989/record`)
- Receive individual audio streams from JVB
- Write each participant's audio as separate track
- Create Matroska (MKA) container with multiple audio tracks
- Execute finalize script when recording completes

**Technology:**
- Kotlin/Java application
- WebSocket server
- Matroska container format

**Container:** `jitsi/jitsi-multitrack-recorder`
**Ports:**
- 8989 (WebSocket)

**Configuration:**
Environment variables:
- `RECORDING_DIR=/recordings`
- `ENABLE_AUTO_RECORDING=1`
- `FINALIZE_SCRIPT=/scripts/finalize-recording.sh`

**Output Format:**
- `.mka` files (Matroska Audio)
- Multiple audio tracks in one file
- One track per participant
- Filename: `room-<timestamp>.mka`

**Storage:**
- Volume mount: `./recordings:/recordings`
- Recordings persist on host filesystem

---

## Data Flow

### Meeting Join Flow

1. **User opens browser** → `http://localhost:8000/room-name`
2. **Browser loads Jitsi Meet** from web server
3. **Jitsi Meet connects to Prosody** via BOSH (HTTP)
4. **Prosody authenticates** user (guest or authenticated)
5. **User joins MUC room** on `muc.meet.jitsi`
6. **Jicofo detects new participant**, allocates to JVB
7. **WebRTC negotiation** happens via XMPP signaling
8. **Media streams** start flowing through JVB
9. **JVB forwards streams** to other participants (SFU)

### Recording Flow

#### Automatic Recording (ENABLE_AUTO_RECORDING=1)

1. **First participant joins** meeting
2. **Jicofo triggers recording** request to JVB
3. **JVB establishes WebSocket** connection to MTR:
   ```
   ws://recorder:8989/record?room=room-name&timestamp=...
   ```
4. **MTR creates recording file**: `room-<timestamp>.mka`
5. **JVB streams audio** per-participant to MTR:
   ```
   Stream 1: Participant A audio
   Stream 2: Participant B audio
   Stream 3: Participant C audio
   ```
6. **MTR writes each stream** as separate track in MKA file
7. **Participants leave** meeting
8. **Last participant leaves** → JVB signals end
9. **MTR finalizes recording**, closes file
10. **MTR executes finalize script**: `./scripts/finalize-recording.sh`

#### Manual Recording (ENABLE_AUTO_RECORDING=0)

Same flow, but triggered by moderator clicking "Record" button in UI.

### Audio Stream Path

```
Participant Microphone
       │
       ▼
  Browser WebRTC
       │
       ▼ RTP packets (UDP/TCP)
Jitsi Videobridge (JVB)
       │
       ├──────────────────┐
       │                  │
       ▼                  ▼
Other Participants   Multitrack Recorder
  (forwarded)         (via WebSocket)
                           │
                           ▼
                 Write to .mka file
                 (Track N for Participant N)
```

**Key Points:**
- **No mixing** happens at JVB (SFU mode)
- Each participant's audio **stays separate**
- Recorder receives **individual streams**
- Recorder writes **one track per participant**
- Result: **Per-speaker audio isolation**

## Why This Architecture Enables Multitrack Recording

### Traditional MCU (Mixer) Approach
```
Participant 1 ──┐
Participant 2 ──┼──► MCU (Mixer) ──► Single mixed stream
Participant 3 ──┘
```
❌ **Problem:** Audio is mixed, can't separate speakers later

### Jitsi SFU (Selective Forwarding) Approach
```
Participant 1 ──┬──► JVB ──┬──► Participant 1 (own audio)
                │           ├──► Participant 2 (P1's audio)
                │           ├──► Participant 3 (P1's audio)
                │           └──► Recorder (P1's audio = Track 1)
                │
Participant 2 ──┼──► JVB ──┬──► Participant 1 (P2's audio)
                │           ├──► Participant 2 (own audio)
                │           ├──► Participant 3 (P2's audio)
                │           └──► Recorder (P2's audio = Track 2)
                │
Participant 3 ──┘── ... (same pattern)
```
✅ **Solution:** Streams stay separate, recorder gets individual tracks

## File Formats

### Matroska Audio (MKA)

**What is it?**
- Container format (like MP4, AVI)
- Can hold multiple audio/video tracks
- Open standard, well-supported
- Efficient for streaming

**Structure:**
```
room-2025-01-15-10-30-00.mka
│
├── Track 0: Audio (Participant 1)
│   ├── Codec: Opus
│   ├── Sample Rate: 48000 Hz
│   ├── Channels: 1 (mono)
│   └── Bitrate: ~32 kbps
│
├── Track 1: Audio (Participant 2)
│   └── ... (same properties)
│
├── Track 2: Audio (Participant 3)
│   └── ... (same properties)
│
└── Metadata
    ├── Duration
    ├── Creation time
    └── Track count
```

**Why MKA?**
- ✅ Supports multiple audio tracks
- ✅ No limit on track count
- ✅ Efficient encoding (Opus codec)
- ✅ Standards-compliant
- ✅ Easy to process with FFmpeg

### Extracting Tracks

Uses FFmpeg to demux (separate) tracks:

```bash
# Extract track 0
ffmpeg -i room.mka -map 0:a:0 track_0.wav

# Extract track 1
ffmpeg -i room.mka -map 0:a:1 track_1.wav

# And so on...
```

Our script automates this:
```bash
./scripts/extract-tracks.sh recordings/room.mka wav
```

## Networking

### Port Usage Summary

| Port | Protocol | Service | Purpose | External? |
|------|----------|---------|---------|-----------|
| 8000 | TCP | web | HTTP web interface | Yes |
| 8443 | TCP | web | HTTPS (if enabled) | Yes (prod) |
| 10000 | UDP | jvb | RTP/RTCP media | Yes |
| 4443 | TCP | jvb | TCP fallback | Optional |
| 5222 | TCP | prosody | XMPP clients | No (internal) |
| 5280 | TCP | prosody | BOSH | No (internal) |
| 5347 | TCP | prosody | Components | No (internal) |
| 8989 | TCP | recorder | WebSocket | No (internal) |

### Docker Network

All services communicate via Docker bridge network: `meet.jitsi`

**Internal DNS:**
- `web` → resolves to web container
- `prosody` → resolves to prosody container
- `jicofo` → resolves to jicofo container
- `jvb` → resolves to jvb container
- `recorder` → resolves to recorder container

**Example:**
JVB connects to recorder using:
```
ws://recorder:8989/record
```
Docker DNS resolves `recorder` to the recorder container's IP.

## Performance Considerations

### Resource Usage (Approximate)

**Idle System (No Meetings):**
- CPU: < 5%
- RAM: ~1.5 GB
- Disk I/O: Minimal

**Active Meeting (5 Participants, 10 Minutes):**
- CPU: 30-50%
- RAM: 3-4 GB
- Disk I/O: ~50 MB recording
- Network: ~500 Kbps per participant

**Bottlenecks:**

1. **CPU:** JVB media processing (encoding/decoding)
   - Solution: More CPU cores or reduce video quality

2. **RAM:** Multiple participants = more streams in memory
   - Solution: More RAM or limit participants

3. **Disk I/O:** Recording writes continuously
   - Solution: SSD recommended, or reduce audio bitrate

4. **Network:** UDP 10000 must not be blocked
   - Solution: Firewall rules, STUN/TURN properly configured

### Scaling Limits

**Current Setup:**
- 1 concurrent meeting
- Up to 10 participants
- 8GB RAM, 4 CPU cores

**To Scale Up:**
- Add more JVB instances (cascade/shard)
- Use separate recording server
- Implement load balancing
- Use external TURN servers for NAT traversal

## Security Model

### Authentication Domains

**Without Authentication (ENABLE_AUTH=0):**
- Anyone can create and join meetings
- No user accounts required
- "Guest" access for all participants

**With Authentication (ENABLE_AUTH=1):**
- Meeting creators must authenticate
- Guests can still join (if ENABLE_GUESTS=1)
- Prosody handles auth via configured backend

### E2EE and Recording

**Why E2EE is Disabled:**
- **E2EE (End-to-End Encryption):** Encrypted between browsers
- **Server-side recording requires** JVB to see media
- **JVB as SFU** needs unencrypted streams to route
- **MTR** needs unencrypted audio to record

**Trade-off:**
- ❌ No E2EE (less privacy between participants and server)
- ✅ Server-side multitrack recording possible

**Alternative:**
- Use E2EE + local recording (each participant records locally)
- Trade-off: Requires post-meeting file collection and sync

## Troubleshooting Architecture

### Common Issues

**1. Participants can join but no audio/video**
- **Likely cause:** JVB UDP port 10000 blocked
- **Check:** Firewall, NAT, network routing

**2. Recording file created but empty**
- **Likely cause:** JVB not connected to recorder
- **Check:** `docker-compose logs jvb | grep recorder`
- **Verify:** WebSocket connection established

**3. Only one track in recording (should be multiple)**
- **Likely cause:** JVB mixing mode enabled (shouldn't be)
- **Check:** `config/jvb/sip-communicator.properties`
- **Verify:** SFU mode enabled

**4. Recorder crashes during meeting**
- **Likely cause:** Disk full, permissions, or memory
- **Check:** `df -h` (disk space), `docker stats` (memory)

### Debugging Tools

**View Component Logs:**
```bash
./scripts/view-logs.sh <service>
```

**Test WebSocket Connection:**
```bash
docker-compose exec jvb curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://recorder:8989/record
```

**Check Network Connectivity:**
```bash
# From JVB to recorder
docker-compose exec jvb ping recorder

# From jicofo to prosody
docker-compose exec jicofo ping prosody
```

**Inspect Recording File:**
```bash
ffprobe -v error -show_format -show_streams recordings/room-*.mka
```

---

## Summary

This architecture leverages Jitsi's **SFU (Selective Forwarding Unit)** design to maintain **per-participant audio streams** throughout the media pipeline. The **Jitsi Videobridge** routes these separate streams to both participants and the **Multitrack Recorder**, which writes them as individual tracks in a **Matroska (MKA) container**.

The result: **True multitrack recording** with **per-speaker isolation**, eliminating the need for diarization and enabling **high-quality post-processing** for transcription and analysis.

---

For more information:
- [Testing Guide](TESTING.md)
- [Main README](../README.md)
- [Jitsi Handbook](https://jitsi.github.io/handbook/)
