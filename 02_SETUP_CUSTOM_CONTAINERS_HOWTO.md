# Custom JVB/Jicofo Containers for Multitrack Recording

This project now ships with custom Dockerfiles that replace the stock Jitsi
Videobridge and Jicofo binaries with locally built jars, enabling the Colibri2
`connects`/media-json exporter pipeline needed for the multitrack recorder.
Use this guide whenever you need to rebuild or re‑deploy those images from
scratch.

---

## 1. Prerequisites

1. **System packages**
   ```bash
   sudo apt-get update
   sudo apt-get install -y openjdk-17-jdk maven docker.io docker-compose git
   ```
2. **Source trees**
   - `~/Work/guess-class/jitsi-videobridge` (clone from
     `https://github.com/jitsi/jitsi-videobridge.git`)
   - `~/Work/guess-class/jicofo` (clone from
     `https://github.com/jitsi/jicofo.git`)
3. Ensure Docker is running and your user can run `docker`/`docker-compose`
   without sudo.

---

## 2. Build the multitrack-enabled Videobridge jar

```bash
cd ~/Work/guess-class/jitsi-videobridge
mvn clean package -DskipTests
```

The jar we need lands here:
`jvb/target/jitsi-videobridge-2.3-SNAPSHOT.jar`

Copy it into the multitrack repo so Docker can use it:

```bash
cd ~/Work/guess-class/jitsi-multitrack-recording
mkdir -p docker/jvb
cp ~/Work/guess-class/jitsi-videobridge/jvb/target/jitsi-videobridge-2.3-SNAPSHOT.jar \
   docker/jvb/jitsi-videobridge.jar
```

---

## 3. Build the multitrack-aware Jicofo jar

```bash
cd ~/Work/guess-class/jicofo
mvn clean package -DskipTests
```

Pick up the shaded artifact:
`jicofo/target/jicofo-1.1-SNAPSHOT-jar-with-dependencies.jar`

Copy into the multitrack repo:

```bash
cd ~/Work/guess-class/jitsi-multitrack-recording
mkdir -p docker/jicofo
cp ~/Work/guess-class/jicofo/jicofo/target/jicofo-1.1-SNAPSHOT-jar-with-dependencies.jar \
   docker/jicofo/jicofo.jar
```

---

## 4. Dockerfiles and compose configuration

Two lightweight Dockerfiles live at the repo root:

```
Dockerfile.jvb     # FROM jitsi/jvb:stable-9584, COPY docker/jvb/jitsi-videobridge.jar …
Dockerfile.jicofo  # FROM jitsi/jicofo:stable-9584, COPY docker/jicofo/jicofo.jar …
```

`docker-compose.yml` already points the `jvb` and `jicofo` services at these
custom builds:

```yaml
  jvb:
    image: jvb-multitrack:latest
    build:
      context: .
      dockerfile: Dockerfile.jvb

  jicofo:
    image: jicofo-multitrack:latest
    build:
      context: .
      dockerfile: Dockerfile.jicofo
```

If you ever need to revert to upstream images, change `image:` back to the
official tags and remove the `build:` stanza.

---

## 5. Build the Docker images

```bash
cd ~/Work/guess-class/jitsi-multitrack-recording
docker-compose build jvb
docker-compose build jicofo
```

Each build stages the corresponding jar into the container filesystem and tags
the result as `jvb-multitrack:latest` / `jicofo-multitrack:latest`.

---

## 6. Deploy the new containers

Restart just the services we rebuilt:

```bash
docker-compose rm -fs jvb
docker-compose rm -fs jicofo
docker-compose up -d jvb jicofo
```

Verify everything is healthy:

```bash
docker-compose ps
```

You should see `jitsi_jvb` and `jitsi_jicofo` running alongside the other
services.

---

## 7. Verify multitrack exporter wiring

1. Start or join a meeting (e.g. `https://localhost:8443/test-mtr`).
2. Tail the logs:
   ```bash
   docker-compose logs -f jvb recorder
   ```
   Expect to see lines such as:
   - `ExporterWrapper Starting with url=ws://recorder:8989/record`
   - `Websocket connected: true`
   - Recorder reporting `Recording session started`
3. End the meeting and confirm the `.mka` and `.ready` files appear in
   `recordings/`.

If you don’t see exporter log lines, double-check the jars you copied really
contain the media-json exporter changes and that your browser session is
triggering a Colibri2 `connects` request (current builds use automatic
recording through the exporter rather than the legacy
`ENABLE_MULTITRACK_RECORDER` flag).

---

## 8. Maintenance tips

- Rebuild both jars whenever you pull upstream changes or apply local patches.
- Keep `docker/jvb/jitsi-videobridge.jar` and `docker/jicofo/jicofo.jar`
  together with this repository so `docker-compose build` works offline.
- If you push these images to a registry, update `image:` to the registry tag
  (e.g. `ghcr.io/your-org/jvb-multitrack:2025-11-14`) and drop the `build`
  section in compose.
- Document the exact git commit of each upstream source build when deploying to
  other environments so you can reproduce the jars later.

---

With the steps above you can rebuild the multitrack-enabled JVB/Jicofo pair at
any time and ensure the recorder receives per-participant audio over the Colibri
`connects` exporter pipeline.
