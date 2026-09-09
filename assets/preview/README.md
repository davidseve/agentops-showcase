# Architecture GIF previews (local, temporary)

**Do not commit this folder.** It exists only to compare three animated variants of the v5 **Overall Demo** FlowStory diagram before picking one for the README (or dropping the GIF entirely).

Source: `docs/demo/v5/live.html#step-0` (same canvas as `assets/overall-architecture.png`).

## Variants in this folder

| File | Hops (`jumpTo` index) | Narrative | Frames | FPS | ~Duration |
|------|------------------------|-----------|--------|-----|-----------|
| `overall-architecture-request-path.gif` | 0–6 | End user → OpenClaw → inference → NeMo → MaaS → LLM | 7 | 2 | ~3.5 s |
| `overall-architecture-request-response.gif` | 0–13 | Above + LLM response path + Landlock | 14 | 2 | ~7 s |
| `overall-architecture-full.gif` | 0–21 | Full baseline (+ egress + MLflow trace) | 22 | 3 | ~7.3 s |

Open each GIF side by side in the IDE or a browser tab to compare pacing and scope.

## Regenerate previews

From repo root (requires `ffmpeg`, Node, Playwright Chromium):

```bash
./scripts/export-architecture-gif-preview.sh
```

Single variant with custom output:

```bash
cd tests
ARCH_GIF_LAST_INDEX=13 \
ARCH_GIF_FPS=2 \
ARCH_GIF_OUTPUT=../assets/preview/my-variant.gif \
PLAYWRIGHT_BROWSERS_PATH=0 node export-architecture-gif.mjs
```

Useful env vars (see `tests/export-architecture-gif.mjs` header):

| Variable | Default | Purpose |
|----------|---------|---------|
| `ARCH_GIF_FIRST_INDEX` | `0` | First hop index |
| `ARCH_GIF_LAST_INDEX` | `6` | Last hop index |
| `ARCH_GIF_FPS` | `2` | GIF playback rate |
| `ARCH_GIF_FRAME_DELAY_MS` | `700` | Wait after each `jumpTo` before screenshot |
| `ARCH_GIF_WIDTH` | `1200` | Output width (px) |
| `ARCH_GIF_INCLUDE_RESET` | `false` | Extra idle frame before hop 1 |
| `ARCH_GIF_OUTPUT` | `assets/overall-architecture.gif` | Output path |

Official export (after a variant is chosen):

```bash
make export-architecture-gif
# example: ARCH_GIF_LAST_INDEX=13 make export-architecture-gif
```

## When you pick a winner — cleanup checklist

### A) Keep one GIF in the repo

1. Copy the chosen file to the canonical path:
   ```bash
   cp assets/preview/overall-architecture-<winner>.gif assets/overall-architecture.gif
   ```
2. Set defaults in `tests/export-architecture-gif.mjs` (`ARCH_GIF_LAST_INDEX`, `ARCH_GIF_FPS`) to match the winner so `make export-architecture-gif` reproduces it.
3. **Delete temporary preview boilerplate:**
   - `assets/preview/` (this entire directory, including this README and the three `*.gif` files)
   - `scripts/export-architecture-gif-preview.sh`
4. Optionally wire `assets/overall-architecture.gif` into root `README.md` next to the PNG.
5. Commit only `assets/overall-architecture.gif` + any default/env doc tweaks — not `assets/preview/`.

### B) Do not ship a GIF

1. **Delete preview artifacts:**
   - `assets/preview/` (entire directory)
   - `scripts/export-architecture-gif-preview.sh`
2. **Delete GIF export tooling** (if no longer needed):
   - `tests/export-architecture-gif.mjs`
   - `scripts/export-readme-architecture-gif.sh`
   - `assets/overall-architecture.gif` (if present)
   - `make export-architecture-gif` target in root `Makefile`
   - `export-architecture-gif` script in `tests/package.json`
   - GIF section in `docs/demo/README.md`
   - `export-readme-architecture-gif.sh` line in `AGENTS.md`
3. Keep `make export-architecture` (PNG) — that remains the documented static diagram.

## Related (keep unless option B)

| Path | Role |
|------|------|
| `tests/export-architecture-gif.mjs` | Playwright frame capture + ffmpeg assembly |
| `scripts/export-readme-architecture-gif.sh` | Wrapper for `make export-architecture-gif` |
| `tests/export-architecture-diagram.mjs` | Static PNG export (unchanged) |

---

*Temporary local note — remove with `assets/preview/` once a decision is made.*
