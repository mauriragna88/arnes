import { test } from "node:test";
import assert from "node:assert/strict";
import { getCognitionBlock } from "../../pi/extensions/argos-cognition";
import { getWorkingMemoryBlock, setQuest, recordFact, setNextAction } from "../../pi/extensions/argos-working-memory";

test("cognition: bloque contiene quest y marco de decisión", () => {
  const block = getCognitionBlock({ questType: "frontend", agent: "vivi", path: "SKILL" });
  assert.match(block, /frontend/);
  assert.match(block, /FAST/);
  assert.match(block, /RECALL/);
  assert.match(block, /SKILL/);
  assert.match(block, /DELIBERATE/);
  assert.match(block, /DEEP/);
});

test("working memory: bloque refleja estado y next action", () => {
  setQuest("Q-001", "backend");
  recordFact("Supabase es la DB verificada");
  setNextAction("crear schema zod");
  const block = getWorkingMemoryBlock();
  assert.match(block, /Q-001/);
  assert.match(block, /backend/);
  assert.match(block, /Supabase es la DB verificada/);
  assert.match(block, /crear schema zod/);
});
