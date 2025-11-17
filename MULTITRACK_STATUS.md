# Multitrack Recording Investigation - Final Status

**Date**: 2025-11-17
**Status**: ❌ Not Production-Ready (Experimental Feature)

---

## Executive Summary

After extensive investigation and configuration, we conclude that **jitsi-multitrack-recorder is not production-ready**. While the component exists and can be configured, the integration with Jicofo requires Jibri availability checks that prevent the transcription-based recording from functioning independently.

**Recommendation**: Use official Jibri for production recording needs (see separate repository: `jitsi-jibri-recording`).

---

## What We Accomplished

### 1. Discovered the Transcription Architecture ✅

Through web research (GitHub Issue #26), we discovered that multitrack recording uses **transcription infrastructure**, NOT recording infrastructure:

- `ENABLE_RECORDING=1` is **irrelevant** for multitrack recorder
- Uses `transcription.url-template` in Jicofo config
- Triggered by `isTranscribingEnabled=true` in room metadata
- JVB should send audio streams via WebSocket to recorder

### 2. Successfully Configured All Components ✅

**Jicofo Configuration** - [Dockerfile.jicofo](Dockerfile.jicofo:9-18):
```hocon
jicofo {
  transcription {
    url-template = "ws://recorder:8989/record/MEETING_ID"
  }
}
```

**Frontend Configuration** - [config/web/custom-config.js](config/web/custom-config.js):
```javascript
config.transcription = {
    enabled: true,
    inviteJigasiOnBackendTranscribing: false,
    autoTranscribeOnRecord: true
};
config.recording = { enabled: true };
```

**Custom Builds**:
- JVB built from master with exporter code (ExporterWrapper.kt, Exporter.kt)
- Jicofo built from master with Colibri2 support
- Multitrack recorder container running on port 8989

### 3. Verified Configuration Loading ✅

```bash
# Jicofo config verified
$ docker-compose exec -T jicofo cat /config/jicofo.conf | grep -A10 transcription
transcription {
    url-template = "ws://recorder:8989/record/MEETING_ID"
  }
}

# Frontend config verified
$ docker-compose exec -T web grep -A2 "config.recording = {" /config/config.js
config.recording = {
    enabled: true
};
```

### 4. Successfully Triggered Transcription Metadata ✅

When clicking the recording button, Jicofo correctly sets:
```
RoomMetadata(metadata=Metadata(recording=Recording(isTranscribingEnabled=true)))
```

---

## The Blocking Issue ❌

### Problem: Jicofo Requires Jibri Availability

Even though transcription metadata is set correctly, Jicofo's code path checks for Jibri availability:

```
[ERROR] Unable to find an available Jibri, can't start
[ERROR] Failed to start a Jibri session, no Jibris available
```

**Root Cause**: When the UI sends a recording start request, it goes through Jicofo's Jibri handling code which requires:
1. At least one Jibri instance in the jibribrewery MUC
2. Jibri to be in IDLE state
3. Successful XMPP authentication

Only after these checks pass would Jicofo potentially send Colibri2 connect messages to JVB.

### What Doesn't Work

Despite correct configuration:
- ❌ No Colibri2 `<connect>` messages sent from Jicofo to JVB
- ❌ No "Setting enableTranscribing" log in Jicofo (beyond metadata)
- ❌ No "Starting with url=" log in JVB exporter
- ❌ No WebSocket connection from JVB to recorder
- ❌ No .mka files created

---

## Technical Findings

### Architecture Understanding

```
┌─────────────┐  Click Record  ┌─────────────┐
│             │───────────────▶│             │
│  Jitsi Web  │                │   Jicofo    │
│             │◀───────────────│             │
└─────────────┘   Set Metadata └──────┬──────┘
                                      │
                                      │ Checks for
                                      │ Jibri availability
                                      ▼
                              ❌ BLOCKS HERE
                              (No Jibri found)

                              Should send:
                              ┌──────────────┐
                              │ Colibri2     │
                              │ <connect>    │
                              │ protocol=    │
                              │ MEDIAJSON    │
                              └──────┬───────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │     JVB     │
                              │  (Exporter) │
                              └──────┬──────┘
                                     │ WebSocket
                                     ▼
                              ┌─────────────┐
                              │  Multitrack │
                              │  Recorder   │
                              └─────────────┘
```

### Why Jibri is Required

The current Jicofo code (even in master branch) appears to:
1. Receive recording request via XMPP IQ (`<jibri action='start'>`)
2. Look up available Jibri instances in brewery MUC
3. Block if no Jibri found with error: "recording service not available"
4. Never reach the transcription/connect code path

This suggests either:
- The multitrack feature is incomplete in current master
- Additional undocumented configuration is required
- The GitHub maintainer's comments from 2020 no longer apply
- The feature requires Jibri as an intermediate component

---

## Attempts to Resolve

### Attempt 1: Build from Master Branch
- **Action**: Built JVB and Jicofo from master branch
- **Result**: Exporter code present, but not activated
- **Outcome**: ❌ Failed - no connect messages

### Attempt 2: Configure Transcription URL
- **Action**: Added `transcription.url-template` to Jicofo config
- **Result**: Configuration loaded successfully
- **Outcome**: ❌ Failed - config ignored without Jibri

### Attempt 3: Enable Recording/Transcription Environment Variables
- **Action**: Set `ENABLE_RECORDING=1`, `ENABLE_TRANSCRIPTIONS=1`
- **Result**: Recording button visible, transcription enabled
- **Outcome**: ❌ Failed - still requires Jibri

### Attempt 4: Add Dummy Jibri Container
- **Action**: Added official Jibri container to satisfy availability check
- **Result**: Jibri container requires complex setup (XMPP auth, virtual display, etc.)
- **Outcome**: ⏸️  Abandoned - too complex, defeats purpose

---

## Evidence from Logs

### Jicofo Correctly Receives Request
```
INFO: Accepted jibri request: action='start' recording_mode='file'
```

### Jicofo Sets Transcription Metadata
```
INFO: Setting room metadata: RoomMetadata(metadata=Metadata(recording=Recording(isTranscribingEnabled=true)))
```

### But Then Fails on Jibri Check
```
SEVERE: Unable to find an available Jibri, can't start
INFO: Failed to start a Jibri session, no Jibris available
```

### No Connect Messages Ever Sent
```bash
# Searched entire Jicofo log output:
$ docker-compose logs jicofo | grep -i "connect.*url"
# (no results)

# Searched entire JVB log output:
$ docker-compose logs jvb | grep -i "starting with url"
# (no results)
```

---

## Comparison with Jibri

| Feature | Multitrack Recorder | Jibri |
|---------|-------------------|-------|
| **Status** | Experimental | Production-Ready |
| **Documentation** | Minimal (2 GitHub issues) | Extensive |
| **Setup Complexity** | Very High | Medium |
| **Dependencies** | Master branch builds required | Official stable images |
| **Output Format** | MKA (separate tracks) | MP4 (mixed video/audio) |
| **Success Rate** | 0% (blocked by Jibri check) | High (well-tested) |
| **Community Support** | None found | Active |
| **Use Case** | Podcast/interviews (unmixed) | General recording |
| **Post-Processing** | Native separation | Diarization required |

---

## Conclusions

### For This Project

1. **Multitrack recorder exists** and is real (not vaporware)
2. **Architecture is sound** (WebSocket + transcription infrastructure)
3. **Configuration is correct** (verified in our setup)
4. **Integration is incomplete** (Jibri dependency not removable)
5. **Not production-ready** (requires deep Jitsi knowledge to debug further)

### For Production Use

**Recommendation**: Use official Jibri for recording:
- Well-documented and stable
- Easy to set up with official docker-compose
- Produces mixed audio/video MP4 files
- Post-process with speaker diarization if needed
- Proven track record in production deployments

**If multitrack is critical**:
- Contact Jitsi maintainers directly
- Contribute to the project to complete integration
- Or implement custom solution outside of Jitsi
  - Record client-side audio streams
  - Use Jitsi API to capture separate tracks
  - Process with custom backend

---

## Repository Purpose

This repository documents:
- ✅ Correct transcription configuration for Jicofo
- ✅ Correct frontend enablement for recording/transcription
- ✅ Custom JVB/Jicofo builds from master branch
- ✅ Evidence of multitrack recorder's experimental status
- ✅ Troubleshooting steps and findings

**Use this repository as**:
- Reference for transcription configuration
- Research documentation for future attempts
- Proof that multitrack recorder is not production-ready (as of 2025-11-17)

**Do NOT use for production** - see `jitsi-jibri-recording` repository instead.

---

## Files of Interest

### Configuration
- [Dockerfile.jicofo](Dockerfile.jicofo) - Jicofo with transcription URL template
- [docker-compose.yml](docker-compose.yml) - Full multitrack setup
- [config/web/custom-config.js](config/web/custom-config.js) - Frontend transcription config
- [.env](.env) - Environment variables (with transcription settings)

### Documentation
- [CRITICAL_FIXES.md](CRITICAL_FIXES.md) - JVB and Jicofo stability fixes
- [MULTITRACK_RECORDING_SETUP.md](MULTITRACK_RECORDING_SETUP.md) - Configuration guide
- [REPOSITORY_STATUS.md](REPOSITORY_STATUS.md) - Commit readiness checklist

### Build Instructions
- [02_SETUP_CUSTOM_CONTAINERS_HOWTO.md](02_SETUP_CUSTOM_CONTAINERS_HOWTO.md) - Building JVB/Jicofo from master

---

## Next Steps

1. ✅ Document findings (this file)
2. ⏭️  Create separate `jitsi-jibri-recording` repository
3. ⏭️  Set up official Jibri from Jitsi's recommended configuration
4. ⏭️  Copy proven fixes (trusted-domains, NAT configuration) from this repo
5. ⏭️  Deploy production recording with Jibri

---

**Status**: Research complete. Use Jibri for production.
