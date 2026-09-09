/**
 * Export v5 live companion step 0 (Overall Demo) FlowStory embed to an animated GIF.
 * Captures one frame per hop (jumpTo index) and assembles with ffmpeg palettegen.
 * No cluster required.
 *
 * Env:
 *   ARCH_GIF_FIRST_INDEX   — first jumpTo index (default 0)
 *   ARCH_GIF_LAST_INDEX    — last jumpTo index (default 6 = request path through LLM)
 *   ARCH_GIF_FRAME_DELAY_MS — wait after jumpTo before screenshot (default 700)
 *   ARCH_GIF_FPS           — output GIF frame rate (default 2)
 *   ARCH_GIF_WIDTH         — output width in px (default 1200)
 *   ARCH_GIF_INCLUDE_RESET — include idle frame before hop 1 (default false)
 *   ARCH_GIF_OUTPUT        — output path (default assets/overall-architecture.gif)
 */
import { chromium } from "@playwright/test";
import { spawn, spawnSync } from "node:child_process";
import { mkdtemp, mkdir, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, "..");
const DOCS_DIR = path.join(ROOT_DIR, "docs");
const OUTPUT_PATH = process.env.ARCH_GIF_OUTPUT
  ? path.resolve(ROOT_DIR, process.env.ARCH_GIF_OUTPUT)
  : path.join(ROOT_DIR, "assets", "overall-architecture.gif");

const HTTP_PORT = Number(process.env.ARCH_DIAGRAM_HTTP_PORT || 18765);
const PAGE_URL = `http://127.0.0.1:${HTTP_PORT}/demo/v5/live.html#step-0`;
const VIEWPORT = { width: 1600, height: 1100 };
const DIAGRAM_SELECTOR = ".nr-v5-overall-mounted .fs-overall-canvas-wrap";

const FIRST_INDEX = Number(process.env.ARCH_GIF_FIRST_INDEX ?? 0);
const LAST_INDEX = Number(process.env.ARCH_GIF_LAST_INDEX ?? 6);
const FRAME_DELAY_MS = Number(process.env.ARCH_GIF_FRAME_DELAY_MS ?? 700);
const OUTPUT_FPS = Number(process.env.ARCH_GIF_FPS ?? 2);
const OUTPUT_WIDTH = Number(process.env.ARCH_GIF_WIDTH ?? 1200);
const INCLUDE_RESET =
  (process.env.ARCH_GIF_INCLUDE_RESET ?? "false").toLowerCase() === "true";

const LAYERS_DOCK_MODE_KEY = "agentops-layers-dock-mode";
const LAYERS_DOCK_VISIBLE_KEY = "agentops-layers-dock-visible";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function requireFfmpeg() {
  const probe = spawnSync("ffmpeg", ["-version"], { stdio: "ignore" });
  if (probe.status !== 0) {
    throw new Error("ffmpeg is required for GIF export (install ffmpeg and retry)");
  }
}

async function waitForServer(url, timeoutMs = 15_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(2_000) });
      if (res.ok) return;
    } catch {
      // retry
    }
    await sleep(200);
  }
  throw new Error(`Timed out waiting for static server at ${url}`);
}

function startStaticServer() {
  const child = spawn("python3", ["-m", "http.server", String(HTTP_PORT)], {
    cwd: DOCS_DIR,
    stdio: ["ignore", "pipe", "pipe"],
  });

  child.on("error", (err) => {
    console.error("Failed to start python3 http.server:", err.message);
    process.exit(1);
  });

  return child;
}

function assembleGif(framesDir, frameCount, outputPath) {
  const inputPattern = path.join(framesDir, "frame-%04d.png");
  const palettePath = path.join(framesDir, "palette.png");
  const scale = `scale=${OUTPUT_WIDTH}:-1:flags=lanczos`;

  const paletteGen = spawnSync(
    "ffmpeg",
    [
      "-y",
      "-framerate",
      String(OUTPUT_FPS),
      "-i",
      inputPattern,
      "-frames:v",
      String(frameCount),
      "-vf",
      `${scale},palettegen=stats_mode=diff`,
      palettePath,
    ],
    { stdio: "inherit" },
  );
  if (paletteGen.status !== 0) {
    throw new Error("ffmpeg palettegen failed");
  }

  const paletteUse = spawnSync(
    "ffmpeg",
    [
      "-y",
      "-framerate",
      String(OUTPUT_FPS),
      "-i",
      inputPattern,
      "-i",
      palettePath,
      "-frames:v",
      String(frameCount),
      "-lavfi",
      `${scale}[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5`,
      "-loop",
      "0",
      outputPath,
    ],
    { stdio: "inherit" },
  );
  if (paletteUse.status !== 0) {
    throw new Error("ffmpeg paletteuse failed");
  }
}

async function exportGif() {
  if (FIRST_INDEX < 0 || LAST_INDEX < FIRST_INDEX) {
    throw new Error(`Invalid hop range: ${FIRST_INDEX}..${LAST_INDEX}`);
  }

  requireFfmpeg();
  await mkdir(path.dirname(OUTPUT_PATH), { recursive: true });

  const framesDir = await mkdtemp(path.join(os.tmpdir(), "agentops-arch-gif-"));
  const server = startStaticServer();
  let browser;

  try {
    await waitForServer(PAGE_URL.split("#")[0]);

    browser = await chromium.launch({
      headless: true,
      args: ["--disable-gpu", "--disable-font-subpixel-positioning"],
    });
    const page = await browser.newPage({
      viewport: VIEWPORT,
      deviceScaleFactor: 1,
    });

    await page.addInitScript(
      ({ modeKey, visibleKey }) => {
        localStorage.clear();
        localStorage.setItem(modeKey, "off");
        localStorage.setItem(visibleKey, "false");

        const style = document.createElement("style");
        style.textContent = `
          :root {
            --nr-mono: "DejaVu Sans Mono", "Liberation Mono", monospace !important;
            --nr-display: "DejaVu Sans", "Liberation Sans", sans-serif !important;
            --nr-body: "DejaVu Sans", "Liberation Sans", sans-serif !important;
          }
          * {
            -webkit-font-smoothing: none !important;
            font-smooth: never !important;
          }
        `;
        document.documentElement.appendChild(style);
      },
      {
        modeKey: LAYERS_DOCK_MODE_KEY,
        visibleKey: LAYERS_DOCK_VISIBLE_KEY,
      },
    );

    await page.goto(PAGE_URL, { waitUntil: "load" });

    await page.waitForFunction(() => document.body.classList.contains("nr-v5-step-0"));
    await page.waitForSelector(".nr-v5-overall-mounted", { state: "attached" });
    await page.waitForFunction(() => Boolean(window.__flowstory?._canvas));
    await page.evaluate(() => document.body.classList.add("light"));

    const stepCount = await page.evaluate(() => {
      const viz = window.__flowstory;
      if (!viz?._diagram?.flows) {
        throw new Error("FlowStory diagram not loaded");
      }
      viz.closeOverlay?.();
      const flowId = viz.state.activeFlow || viz._diagram.defaultFlow || "baseline";
      const steps = viz._diagram.flows[flowId]?.steps;
      if (!steps?.length) {
        throw new Error(`No steps for flow: ${flowId}`);
      }
      return steps.length;
    });

    if (LAST_INDEX >= stepCount) {
      throw new Error(
        `ARCH_GIF_LAST_INDEX=${LAST_INDEX} exceeds baseline hop count (${stepCount})`,
      );
    }

    const diagram = page.locator(DIAGRAM_SELECTOR);
    await diagram.waitFor({ state: "visible" });
    await page.evaluate(() => document.fonts?.ready);

    let frameNumber = 1;

    async function captureFrame() {
      const framePath = path.join(framesDir, `frame-${String(frameNumber).padStart(4, "0")}.png`);
      await diagram.screenshot({
        path: framePath,
        animations: "disabled",
        scale: "css",
      });
      frameNumber += 1;
    }

    if (INCLUDE_RESET) {
      await page.evaluate(() => {
        window.__flowstory?.reset?.();
      });
      await page.waitForTimeout(FRAME_DELAY_MS);
      await captureFrame();
    }

    for (let index = FIRST_INDEX; index <= LAST_INDEX; index += 1) {
      await page.evaluate((hopIndex) => {
        const viz = window.__flowstory;
        viz.closeOverlay?.();
        viz.jumpTo(hopIndex);
        const flowId = viz.state.activeFlow || viz._diagram.defaultFlow || "baseline";
        const steps = viz._diagram.flows[flowId]?.steps ?? [];
        const expectedDone = hopIndex + 1;
        if (viz.state.currentStepDone !== expectedDone && hopIndex < steps.length - 1) {
          throw new Error(
            `jumpTo(${hopIndex}) expected currentStepDone=${expectedDone}, got ${viz.state.currentStepDone}`,
          );
        }
      }, index);
      await page.waitForTimeout(FRAME_DELAY_MS);
      await captureFrame();
    }

    const frameCount = frameNumber - 1;
    if (frameCount === 0) {
      throw new Error("No frames captured");
    }

    console.log(
      `Assembling ${frameCount} frame(s) (hops ${FIRST_INDEX}..${LAST_INDEX}${INCLUDE_RESET ? ", with reset" : ""}) at ${OUTPUT_FPS} fps`,
    );
    assembleGif(framesDir, frameCount, OUTPUT_PATH);
    console.log(`Wrote ${OUTPUT_PATH}`);
  } finally {
    if (browser) {
      await browser.close();
    }
    server.kill("SIGTERM");
    await sleep(300);
    if (!server.killed) {
      server.kill("SIGKILL");
    }
    await rm(framesDir, { recursive: true, force: true });
  }
}

exportGif().catch((err) => {
  console.error(err);
  process.exit(1);
});
