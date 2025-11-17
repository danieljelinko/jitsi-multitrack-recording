# Critical Fixes Applied - Jitsi Multitrack Recording

**Date**: 2025-11-17
**Status**: ✅ All critical issues resolved

---

## Summary

This document details all critical fixes applied to make the Jitsi multitrack recording server work properly. These fixes resolve:
1. JVB container crashes on startup
2. Instant meeting disconnection issues
3. Configuration file generation problems

---

## Fix #1: JVB Library Dependencies (CRITICAL)

### Problem
JVB container was crashing immediately on startup with:
```
java.lang.NoSuchFieldError: USE_PUSH_API
at org.jitsi.videobridge.MainKt.startIce4j
```

### Root Cause
The custom-built `jitsi-videobridge.jar` was compiled against newer library versions (ice4j 3.2), but the Dockerfile only copied the main jar file. The old libraries from the base image (ice4j 3.0) remained in the classpath, causing version conflicts.

### Solution
**Updated [Dockerfile.jvb](Dockerfile.jvb)**:
```dockerfile
FROM jitsi/jvb:stable-9584

# Remove old libraries to avoid classpath conflicts
RUN rm -rf /usr/share/jitsi-videobridge/lib/*

# Copy the locally built multitrack-enabled videobridge and all its dependencies
COPY docker/jvb/jitsi-videobridge.jar /usr/share/jitsi-videobridge/jitsi-videobridge.jar
COPY docker/jvb/lib/ /usr/share/jitsi-videobridge/lib/
```

**Updated [02_SETUP_CUSTOM_CONTAINERS_HOWTO.md](02_SETUP_CUSTOM_CONTAINERS_HOWTO.md)** build instructions:
```bash
# Extract the full distribution with all dependencies
cd ~/Work/guess-class/jitsi-videobridge/jvb/target
unzip -q jitsi-videobridge-2.3-SNAPSHOT-archive.zip

# Copy entire distribution (jar + lib directory)
cd ~/Work/guess-class/jitsi-multitrack-recording
rm -rf docker/jvb/*
mkdir -p docker/jvb
cp -r ~/Work/guess-class/jitsi-videobridge/jvb/target/jitsi-videobridge-2.3-SNAPSHOT/* docker/jvb/
```

### Impact
✅ JVB now starts successfully
✅ No more classpath conflicts
✅ All required libraries present

---

## Fix #2: Jicofo Trusted Domains Configuration (CRITICAL)

### Problem
Meetings would disconnect instantly (after ~15 seconds) with this error:
```
XmppStringprepException: domainpart can't be the empty string
at org.jitsi.jicofo.xmpp.XmppConfig.getTrustedDomains
```

Followed by:
```
Expiring due to initial timeout.
Conference stopped.
```

### Root Cause
The Jicofo configuration template in `/defaults/jicofo.conf` included:
```
trusted-domains = [ "" ]
```

When `$TRUSTED_DOMAINS` environment variable was empty, it generated an array with an empty string, which is invalid XMPP JID syntax and caused parsing to fail when processing participant presence.

### Solution
**Updated [Dockerfile.jicofo](Dockerfile.jicofo)**:
```dockerfile
FROM jitsi/jicofo:stable-9584

# Replace the bundled jicofo jar with the locally built one that understands colibri2 connects
COPY docker/jicofo/jicofo.jar /usr/share/jicofo/jicofo.jar

# Comment out the trusted-domains line that causes XmppStringprepException with empty strings
RUN sed -i 's/^      trusted-domains/      # trusted-domains/g' /defaults/jicofo.conf
```

This comments out the `trusted-domains` line in the template, preventing the invalid empty string from being added to the configuration.

### Impact
✅ No more XmppStringprepException errors
✅ Meetings stay connected
✅ Participants can join successfully
✅ No 15-second timeout disconnections

---

## Fix #3: Docker Build Context Issues

### Problem
Docker build was failing with:
```
error checking context: can't stat '/home/helinko/Work/guess-class/jitsi-multitrack-recording/config/prosody/data/auth%2emeet%2ejitsi'
```

### Root Cause
The Docker build context included the entire repository directory, including runtime-generated config files with special characters that Docker couldn't handle.

### Solution
**Created [.dockerignore](.dockerignore)**:
```
config/
recordings/
.git/
.env
.env.*
*.md
```

### Impact
✅ Docker builds complete successfully
✅ Build context is smaller and faster
✅ No config file conflicts

---

## Fix #4: HTTPS Port Configuration

### Problem
When using `DISABLE_HTTPS=0`, the config.js was generated with `https://localhost:8000/` but port 8000 only serves HTTP. The HTTPS port is 8443.

### Root Cause
The `PUBLIC_URL` environment variable was set to `localhost:8000` which is the HTTP port, not the HTTPS port.

### Solution
**Updated [.env](.env)**:
```bash
# For HTTPS (production or testing with self-signed cert)
PUBLIC_URL=localhost:8443

# Enable HTTPS
DISABLE_HTTPS=0
```

### Impact
✅ Config.js generates correct URLs: `https://localhost:8443/`
✅ WebSocket uses correct URL: `wss://localhost:8443/`
✅ No TLS handshake errors

---

## Fix #5: Docker Compose Volume Mount Issues (Historical)

### Problem (Now Fixed in Base Setup)
Original docker-compose.yml tried to mount config files as read-only before they existed, causing Docker to create directories instead of files.

### Solution
These problematic lines were already removed from the base docker-compose.yml:
```yaml
# REMOVED (previously caused issues):
# - ./config/web/interface_config.js:/usr/share/jitsi-meet/interface_config.js:ro
# - ./config/web/config.js:/usr/share/jitsi-meet/config.js:ro
# - ./config/prosody/config:/config:ro
# - ./config/jvb/sip-communicator.properties:/config/sip-communicator.properties:ro
```

---

## Prerequisites for Clean Install

### 1. Source Code Repositories
Clone these repositories to `~/Work/guess-class/`:
```bash
cd ~/Work/guess-class/
git clone https://github.com/jitsi/jitsi-videobridge.git
git clone https://github.com/jitsi/jicofo.git
```

### 2. Build the Custom JARs
```bash
# Build JVB
cd ~/Work/guess-class/jitsi-videobridge
mvn clean package -DskipTests

# Build Jicofo
cd ~/Work/guess-class/jicofo
mvn clean package -DskipTests
```

### 3. Extract and Copy Build Artifacts

**For JVB (IMPORTANT - must copy full distribution)**:
```bash
cd ~/Work/guess-class/jitsi-videobridge/jvb/target
unzip -q jitsi-videobridge-2.3-SNAPSHOT-archive.zip

cd ~/Work/guess-class/jitsi-multitrack-recording
rm -rf docker/jvb/*
mkdir -p docker/jvb
cp -r ~/Work/guess-class/jitsi-videobridge/jvb/target/jitsi-videobridge-2.3-SNAPSHOT/* docker/jvb/
```

**For Jicofo**:
```bash
cd ~/Work/guess-class/jitsi-multitrack-recording
mkdir -p docker/jicofo
cp ~/Work/guess-class/jicofo/jicofo/target/jicofo-1.1-SNAPSHOT-jar-with-dependencies.jar \
   docker/jicofo/jicofo.jar
```

### 4. Generate Passwords
```bash
cd ~/Work/guess-class/jitsi-multitrack-recording
./scripts/generate-passwords.sh
```

Or manually set these in `.env`:
- `JICOFO_COMPONENT_SECRET`
- `JICOFO_AUTH_PASSWORD`
- `JVB_AUTH_PASSWORD`
- `JIBRI_RECORDER_PASSWORD`

### 5. Configure for Your Environment

**For production** (public server):
```bash
cp .env.production .env
# Edit .env and set:
# - PUBLIC_URL=your-domain.com (no https://)
# - DOCKER_HOST_ADDRESS=your-server-public-ip
```

**For localhost testing** (HTTPS with self-signed cert):
```bash
# Use existing .env or create from template
# Set:
# - PUBLIC_URL=localhost:8443
# - DISABLE_HTTPS=0
# - DOCKER_HOST_ADDRESS=127.0.0.1
```

### 6. Build and Start
```bash
# Build custom images
docker-compose build jicofo jvb

# Start all services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

---

## Verification Checklist

After clean install, verify:

- [ ] All 5 containers are running (`docker-compose ps`)
- [ ] JVB logs show `Starting jitsi-videobridge version 2.3.SNAPSHOT`
- [ ] JVB logs show `Joined MUC: jvbbrewery@internal-muc.meet.jitsi`
- [ ] Jicofo logs show `Added new videobridge`
- [ ] Jicofo logs show NO `XmppStringprepException` errors
- [ ] Web interface loads at configured URL
- [ ] Can create and join meetings
- [ ] Meetings stay connected (no instant disconnection)
- [ ] Audio/video works
- [ ] Recordings are created in `./recordings/` directory

---

## Files Modified/Created

### Dockerfiles
- ✅ [Dockerfile.jvb](Dockerfile.jvb) - Added lib directory copy and cleanup
- ✅ [Dockerfile.jicofo](Dockerfile.jicofo) - Added trusted-domains fix

### Configuration
- ✅ [.dockerignore](.dockerignore) - Exclude runtime files from build context
- ✅ [.env](.env) - Updated PUBLIC_URL and HTTPS settings
- ✅ [.env.localhost](.env.localhost) - Template for localhost
- ✅ [.env.production](.env.production) - Template for production

### Documentation
- ✅ [02_SETUP_CUSTOM_CONTAINERS_HOWTO.md](02_SETUP_CUSTOM_CONTAINERS_HOWTO.md) - Updated build instructions
- ✅ [CRITICAL_FIXES.md](CRITICAL_FIXES.md) - This file
- ✅ [FIXES_APPLIED.md](FIXES_APPLIED.md) - Historical troubleshooting log

---

## Common Issues and Solutions

### Issue: "NoSuchFieldError: USE_PUSH_API"
**Solution**: Make sure you copied the ENTIRE `docker/jvb/` distribution including the `lib/` directory, not just the jar file.

### Issue: "XmppStringprepException: domainpart can't be the empty string"
**Solution**: Rebuild the jicofo container with the updated Dockerfile.jicofo that comments out trusted-domains.

### Issue: "TLS handshake errors" or "wrong version number"
**Solution**: Make sure `PUBLIC_URL` matches the port and protocol you're using:
- For HTTPS: `PUBLIC_URL=localhost:8443` or `PUBLIC_URL=yourdomain.com`
- For HTTP (not recommended): `PUBLIC_URL=localhost:8000`

### Issue: Containers restart continuously
**Solution**: Check logs with `docker-compose logs [service_name]` and verify all passwords are set in `.env`

---

## Testing the Fixes

To verify all fixes are working:

```bash
# Stop everything
docker-compose down

# Clean rebuild
docker-compose build jicofo jvb

# Start fresh
docker-compose up -d

# Wait for startup
sleep 10

# Check all containers are up
docker-compose ps

# Monitor for errors
docker-compose logs -f jicofo jvb | grep -E "(Error|Exception|Started|Joined)"
```

Expected output:
- ✅ `Starting jitsi-videobridge version 2.3.SNAPSHOT`
- ✅ `Joined MUC: jvbbrewery@internal-muc.meet.jitsi`
- ✅ `Added new videobridge`
- ✅ NO `NoSuchFieldError`
- ✅ NO `XmppStringprepException`

---

## Summary of Required Files in Repository

For a clean clone-and-run experience, the repository MUST include:

1. **Dockerfiles** (with all fixes):
   - `Dockerfile.jvb` (with lib copy)
   - `Dockerfile.jicofo` (with trusted-domains fix)
   - `Dockerfile.recorder` (if custom)

2. **Build Context Management**:
   - `.dockerignore`

3. **Configuration Templates**:
   - `.env.example`
   - `.env.localhost`
   - `.env.production`

4. **Docker Compose**:
   - `docker-compose.yml` (base configuration)
   - `docker-compose.localhost.yml` (localhost overrides)
   - `docker-compose.production.yml` (production overrides)

5. **Setup Scripts**:
   - `scripts/generate-passwords.sh`
   - `scripts/start-localhost.sh`
   - `scripts/start-production.sh`

6. **Documentation**:
   - `README.md` (main documentation)
   - `02_SETUP_CUSTOM_CONTAINERS_HOWTO.md` (build instructions)
   - `CRITICAL_FIXES.md` (this file)

**What SHOULD NOT be in the repository**:
- ❌ `docker/jvb/` directory (built artifacts, too large)
- ❌ `docker/jicofo/` directory (built artifacts)
- ❌ `.env` (contains secrets)
- ❌ `config/` directory (runtime generated)
- ❌ `recordings/` directory (runtime generated)

---

**Note**: Users must build the JVB and Jicofo JARs themselves as documented in [02_SETUP_CUSTOM_CONTAINERS_HOWTO.md](02_SETUP_CUSTOM_CONTAINERS_HOWTO.md) before running `docker-compose build`.

