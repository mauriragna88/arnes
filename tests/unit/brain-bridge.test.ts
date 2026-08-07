import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { runBrain } from "../../pi/extensions/argos-brain";

// Proyecto ARNES simulado: el contrato del plan resuelve el brain en
// <proyecto>/cli/arnes_brain.py, así que se copia el brain real al fixture temporal.
const REPO_ROOT = fileURLToPath(new URL("../../", import.meta.url));

function makeFakeArnesProject(): string {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  mkdirSync(join(dir, "cli"), { recursive: true });
  copyFileSync(
    join(REPO_ROOT, "cli", "arnes_brain.py"),
    join(dir, "cli", "arnes_brain.py")
  );
  return dir;
}

test("runBrain: save+recall round-trip contra arnes_brain.py", async () => {
  const dir = makeFakeArnesProject();
  // init db via brain (runBrain inyecta <proyecto>/.arnes/arnes.db automáticamente)
  await runBrain(dir, ["init"]);
  await runBrain(dir, ["save", "-"], {
    agent: "vivi", topic_key: "vivi/ui-patterns", type: "pattern",
    content: "User prefiere dark mode", confidence: 0.99,
  });
  const res = await runBrain(dir, ["recall", "dark mode", "vivi", "5"]);
  assert.equal(res.ok, true);
  const rows = (res.data as any[]);
  assert.ok(rows.some((r) => (r.content as string).includes("dark mode")));
});

test("runBrain: falla fuera de proyecto arnes", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-bridge-"));
  const res = await runBrain(dir, ["stats"]);
  assert.equal(res.ok, false);
});
