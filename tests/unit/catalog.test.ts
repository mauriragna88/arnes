import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildAgentCatalog } from "../../pi/extensions/argos-party";
import { loadAgentModels, resolveModel } from "../../pi/extensions/argos-model-router";

test("catalog: construye agentes desde fuentes canónicas", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-cat-"));
  mkdirSync(join(dir, "core/classes"), { recursive: true });
  mkdirSync(join(dir, "core/auditors"), { recursive: true });
  writeFileSync(join(dir, "core/classes/mage.agent.md"), "# Vivi (Mage) - Frontend DPS");
  writeFileSync(join(dir, "core/classes/tidus.agent.md"), "# Tidus - Infra");
  writeFileSync(join(dir, "core/auditors/tywin.agent.md"), "# Tywin - Verifier");
  const cards = await buildAgentCatalog(dir);
  assert.ok(cards.length >= 3);
  const mage = cards.find((c) => c.id === "mage");
  assert.ok(mage);
  assert.equal(mage.role, "Frontend");
  assert.equal(mage.displayName, "Vivi");
  const tywin = cards.find((c) => c.id === "tywin");
  assert.ok(tywin);
  assert.equal(tywin.role, "Verifier/Memory Judge");
});

test("model router: mapea asignación ARNES → provider/model", () => {
  const m = resolveModel("opencode-go/gpt-5.6-luna");
  assert.equal(m.provider, "opencode-go");
  assert.equal(m.modelId, "gpt-5.6-luna");
  const n = resolveModel("nvidia/minimaxai/minimax-m3");
  assert.equal(n.provider, "nvidia");
  assert.equal(n.modelId, "minimaxai/minimax-m3");
});

test("model router: lee agent-models.json (o fallback)", async () => {
  const dir = mkdtempSync(join(tmpdir(), "argos-mm-"));
  mkdirSync(join(dir, ".arnes"), { recursive: true });
  writeFileSync(
    join(dir, ".arnes", "model-assignments.json"),
    JSON.stringify({ assignments: { vivi: "opencode-go/gpt-5.6-luna" } })
  );
  const models = await loadAgentModels(dir);
  assert.equal(models["vivi"], "opencode-go/gpt-5.6-luna");
});
