# Jitsi Multitrack Architecture Overview

This document explains the moving pieces inside this repository, how the
containers interact, and why each component is required to produce per-speaker
recordings.

---

## 1. High-level topology

```
Browsers ↔ Jitsi Web (nginx) ↔ Prosody (XMPP)
                                 │
                                 ├─ Jicofo (conference controller)
                                 └─ JVB (media bridge, SFU)
                                         │
                                         └─ Multitrack Recorder (WebSocket)
```

- **Jitsi Web** serves the React client and proxies BOSH/WebSocket control
  traffic to Prosody.
- **Prosody** is the XMPP server every other component talks to for signaling.
  Think “chat + presence + authentication”.
- **Jicofo** (“Jitsi Conference Focus”) orchestrates meetings: it creates
  conferences, authorizes participants, and instructs the bridge which
  transports/codecs to use.
- **JVB** (Jitsi Videobridge) is an SFU. It receives each participant’s
  audio/video and forwards it separately—this per-stream routing is what makes
  multitrack recording possible.
- **Multitrack Recorder** is a dedicated WebSocket service that receives the
  raw Opus frames from JVB, one stream per participant, and writes them into a
  Matroska `.mka` container.

All services live on a single Docker compose network (`meet.jitsi`), so they
can discover each other via service names (`prosody`, `jvb`, `recorder`, etc.).

---

## 2. Container Roles

### 2.1 Web (`jitsi/web:stable-9584`)
- Runs nginx + the Jitsi Meet frontend.
- Exposes ports `8000` (HTTP) and `8443` (HTTPS).
- Proxies `/http-bind` and `/xmpp-websocket` to Prosody.
- Reads configuration from `config/web/config.js` and `interface_config.js`.

### 2.2 Prosody (`jitsi/prosody:stable-9584`)
- XMPP server with multiple virtual hosts: `meet.jitsi`, `auth.meet.jitsi`,
  `muc.meet.jitsi`, etc.
- Stores component credentials (Jicofo/JVB/Jibri) and handles guest auth.
- Listens on `5222`, `5280`, `5347` inside the Docker net.

### 2.3 Jicofo (custom `jicofo-multitrack`)
- Talks to Prosody over XMPP.
- Creates/destroys conferences, manages participant endpoints, and (with our
  patched jar) sends Colibri2 `connects` messages instructing JVB to open a
  media-json exporter to the recorder.
- Has no public ports; everything flows through Prosody.

### 2.4 JVB (custom `jvb-multitrack`)
- SFU listening on UDP 10000 (media) and TCP 4443 (fallback).
- Reads `config/jvb/sip-communicator.properties` and `config/jvb/jvb.conf` for
  NAT/STUN/WebSocket settings.
- Our custom jar injects the exporter (MediaJsonSerializer + WebSocket client),
  so when it receives a `connect` with `protocol=mediajson`, it streams Opus
  RTP packets to the recorder over `ws://recorder:8989/record`.

### 2.5 Multitrack Recorder (`jitsi/jitsi-multitrack-recorder:latest`)
- WebSocket server on port `8989`.
- Accepts individual audio streams per participant, writes them into a single
  Matroska file (`recordings/room-<timestamp>.mka`).
- Runs the post-processing hook `scripts/finalize-recording.sh` at the end of
  each session (creates `.ready` marker, logs track info via `ffprobe`).

---

## 3. Recording Flow (“Why multitrack works”)

1. User opens `https://localhost:8443/<room>`; the frontend loads from Web, and
   signaling goes to Prosody.
2. Jicofo receives the meeting request via XMPP, allocates the conference on
   JVB, and notifies Prosody/participants.
3. Once audio streams begin, Jicofo issues a Colibri2 `conference-modify` with
   a `connect` block instructing JVB to open a media-json exporter to the
   recorder.
4. JVB establishes `ws://recorder:8989/record?room=…` and starts sending each
   participant’s Opus frames as serialized JSON events (`Start`, `Media`).
5. The recorder demuxes those streams into a `.mka` container—tracks are kept
   separate because the SFU never mixes audio.
6. When the last participant leaves, Jicofo tears down the connect; JVB closes
   the WebSocket; the recorder finalizes the file and invokes the finalize
   script (creating the `.ready` file, logging track info).

Key benefit: because JVB is an SFU, it forwards individual streams without
mixing, so each participant’s audio stays isolated all the way into the .mka
file—no diarization needed later.

---

## 4. Supporting Scripts & Configuration

- **`.env`** controls ports, PUBLIC_URL, auto-recording flag, NAT hints, etc.
- **`docker-compose.yml`** wires the services together and mounts configs.
- **`Dockerfile.jvb` / `Dockerfile.jicofo`** overlay our custom jars on top of
  upstream images.
- **`scripts/`** provides operational helpers:
  - `generate-passwords.sh`: creates `.env` with random component secrets.
  - `start-server.sh` / `stop-server.sh`: bring the stack up/down.
  - `view-logs.sh`: tail specific service logs (`web`, `jvb`, `recorder`).
  - `list-recordings.sh`, `extract-tracks.sh`, `finalize-recording.sh`: work
    with the `.mka` outputs.
- **`docs/`** contains detailed testing and configuration guides (localhost vs
  production, architecture diagrams, etc.).
- **`01_ADMIN_AGENT_SETUP.md` / `02_SETUP_CUSTOM_CONTAINERS_HOWTO.md`** cover
  deployment responsibilities and custom image builds.

---

## 5. Networking and Ports

| Port | Service | Purpose                          | External? |
|------|---------|----------------------------------|-----------|
| 8000 | web     | HTTP (optional)                  | Yes       |
| 8443 | web     | HTTPS for Jitsi Meet             | Yes       |
| 10000/UDP | jvb | RTP media for participants       | Yes       |
| 4443/TCP | jvb  | TCP fallback for media           | Optional  |
| 5222 | prosody | XMPP client connections (internal)| No        |
| 5280 | prosody | BOSH / WebSocket (internal)      | No        |
| 5347 | prosody | Component connections            | No        |
| 8989 | recorder| WebSocket ingest from JVB        | No        |

In production you typically expose only 80/443/10000 (and optionally 4443) and
keep the rest on the Docker network.

---

## 6. Why we ship custom jars

The current upstream `stable-9584` images don’t include the media-json exporter
or the `connects` API, so setting `ENABLE_MULTITRACK_RECORDER` alone no longer
triggers recording. We build:

- **JVB** from the upstream master branch (post-exporter merge), so it can
  stream media-json events to the recorder when it receives a Colibri2 connect.
- **Jicofo** from upstream master so it knows how to send those `connect`
  blocks automatically at conference start.

The Dockerfiles simply swap out the jar files inside the official images,
keeping the rest of the packaging (entrypoints, configs) untouched.

---

## 7. Putting it together

1. Each meeting is orchestrated over XMPP (Prosody + Jicofo) and rendered in
   browsers via Jitsi Web.
2. JVB routes every participant’s audio individually; our custom build can
   mirror that audio to the recorder over WebSocket.
3. The recorder writes isolated tracks, and helper scripts extract them for
   post-processing.
4. Supporting docs/scripts in this repo make it repeatable on localhost and
   production hosts.

With this architecture, you get server-side, per-speaker recordings without
requiring client-side captures or post-call diarization.
