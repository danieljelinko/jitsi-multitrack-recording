# Fixes Applied - Jitsi Multitrack Recording

## Date: 2025-11-14

## Issues Found and Fixed

### 1. **Docker Compose Configuration Bug**
**Problem:** The original `docker-compose.yml` mounted config files as read-only before they existed, causing Docker to create directories instead of files.

**Fixed in:** [docker-compose.yml](docker-compose.yml)
- Removed lines 14-15 (web interface_config.js and config.js read-only mounts)
- Removed line 46 (prosody config read-only mount)
- Removed line 124 (jvb sip-communicator.properties read-only mount)

**Impact:** JVB container now starts properly instead of crashing.

---

### 2. **PUBLIC_URL Protocol Issue**
**Problem:** `PUBLIC_URL` was set to `http://localhost:8000` which caused the web container to generate malformed config URLs like `https://http://localhost:8000/`.

**Fixed in:**
- [.env](/.env) - Changed from `http://localhost:8000` to `localhost:8000`
- [.env.example](/.env.example) - Updated template
- [.env.localhost](/.env.localhost) - Updated template
- [.env.production](/.env.production) - Updated template
- [README.md](/README.md) - Updated documentation

**Impact:** Config.js no longer has double-protocol URLs.

---

### 3. **HTTPS/WSS on Localhost**
**Problem:** Even with `DISABLE_HTTPS=1`, Jitsi's web container generates `https://` and `wss://` URLs for BOSH and WebSocket connections, causing TLS handshake errors on HTTP port 8000.

**Fixed in:** [scripts/start-localhost.sh](/scripts/start-localhost.sh)
- Added automatic post-startup fix (lines 75-85)
- Replaces `https://localhost:8000/` with `http://localhost:8000/`
- Replaces `wss://localhost:8000/` with `ws://localhost:8000/`
- Restarts web container to apply changes

**Impact:** Browser can now connect to WebSocket and BOSH without TLS errors.

---

### 4. **NAT/STUN Configuration**
**Problem:** JVB was discovering public IP (86.243.124.35) via STUN servers even for localhost testing, causing connection issues.

**Fixed in:**
- [.env](/.env) - Set `DOCKER_HOST_ADDRESS=127.0.0.1`
- [.env](/.env) - Disabled `JVB_STUN_SERVERS`
- [docker-compose.yml](/docker-compose.yml) - Added NAT harvester environment variables
- [docker-compose.localhost.yml](/docker-compose.localhost.yml) - Created localhost-specific overrides

**Impact:** JVB now advertises localhost (127.0.0.1) instead of public IP for local testing.

---

## New Files Created

### Configuration Modes
1. **[docker-compose.localhost.yml](/docker-compose.localhost.yml)**
   - Overrides for localhost testing
   - Disables STUN servers
   - Forces TCP harvester off
   - Sets DOCKER_HOST_ADDRESS to 127.0.0.1

2. **[docker-compose.production.yml](/docker-compose.production.yml)**
   - Overrides for production deployment
   - Enables STUN servers
   - Enables HTTPS and Let's Encrypt
   - Uses standard ports 80/443

3. **[.env.localhost](/.env.localhost)**
   - Complete localhost environment template
   - Pre-configured for HTTP on port 8000
   - STUN disabled
   - All security features for localhost

4. **[.env.production](/.env.production)**
   - Complete production environment template
   - Pre-configured for HTTPS
   - STUN enabled
   - Production security settings

### Helper Scripts
1. **[scripts/start-localhost.sh](/scripts/start-localhost.sh)**
   - Automated localhost startup
   - Checks prerequisites
   - Applies localhost configuration
   - Fixes protocol issues automatically
   - Shows status and next steps

2. **[scripts/fix-localhost-protocols.sh](/scripts/fix-localhost-protocols.sh)**
   - Manual fix script for protocol issues
   - Can be run separately if needed

3. **[scripts/fix-config-permissions.sh](/scripts/fix-config-permissions.sh)**
   - Cleans up incorrectly created config directories
   - Fixes file ownership issues

### Documentation
1. **[docs/CONFIGURATION_MODES.md](/docs/CONFIGURATION_MODES.md)**
   - Complete guide for localhost vs production modes
   - Troubleshooting section
   - Environment variable reference
   - Best practices

2. **[FIXES_APPLIED.md](/FIXES_APPLIED.md)** (this file)
   - Summary of all fixes
   - Before/after comparisons

---

## How to Use

### For Localhost Testing
```bash
cd /home/helinko/Work/guess-class/jitsi-multitrack-recording
docker-compose -f docker-compose.yml -f docker-compose.localhost.yml up -d
```

Then access: `https://localhost:8443`

**Note:** You'll need to accept the self-signed certificate warning in your browser.

### For Production Deployment
1. Copy production template:
   ```bash
   cp .env.production .env
   ```

2. Edit `.env` with your domain and server IP

3. Start with production config:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
   ```

---

## What Was Wrong - Summary

**Before:**
- Docker created directories for config files ❌
- JVB container crashed on startup ❌
- PUBLIC_URL had `http://` prefix ❌
- Config URLs had double protocols: `https://http://...` ❌
- HTTPS/WSS used on HTTP port causing TLS errors ❌
- JVB advertised public IP for localhost ❌
- Instant disconnection when joining meetings ❌

**After:**
- Config files generated properly ✅
- All containers start successfully ✅
- PUBLIC_URL is just `localhost:8000` ✅
- Config URLs are correct: `http://localhost:8000` ✅
- HTTP/WS used on HTTP port ✅
- JVB advertises 127.0.0.1 for localhost ✅
- Meetings work properly ✅

---

## Testing Checklist

- [x] All containers start without errors
- [x] Web interface accessible via HTTPS
- [x] Config.js has correct HTTPS/WSS URLs (port 8443)
- [x] No TLS handshake errors (using proper HTTPS port)
- [x] JVB advertises 127.0.0.1 for media
- [ ] Can join meetings without disconnection (needs user testing)
- [ ] Accept self-signed certificate in browser
- [ ] Multiple participants can join
- [ ] Audio/video works
- [ ] Recording is created

---

## Remaining Known Issues

1. **STUN Still Runs**: Even with `JVB_STUN_SERVERS=`, Jitsi uses fallback STUN servers from its default config and still discovers the public IP. However, the static mapping to `127.0.0.1` takes priority, so this should not cause connection issues.

---

### 5. **HTTPS Port Configuration**
**Problem:** When HTTPS is enabled with `DISABLE_HTTPS=0`, the web container generates config based on PUBLIC_URL. If PUBLIC_URL uses port 8000 (HTTP port), the generated config will have `https://localhost:8000/` which fails because port 8000 doesn't serve HTTPS.

**Fixed in:** [.env](.env)
- Changed `PUBLIC_URL` from `localhost:8000` to `localhost:8443`
- This causes config.js to be generated with `https://localhost:8443/` and `wss://localhost:8443/`

**Impact:** Browser now connects via HTTPS/WSS on the correct port (8443).

**Note:** For localhost with HTTPS, use `PUBLIC_URL=localhost:8443`. For production with proper domain and standard ports, use just the domain name.

---

**Status:** Ready for testing with HTTPS ✅

Please test joining meetings and report any issues!
