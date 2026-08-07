import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { runBrain } from "./argos-brain.js";
import { getWorkingMemoryState } from "./argos-working-memory.js";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (!existsSync(join(ctx.cwd, ".arnes", "arnes.db"))) return;
    const wm = getWorkingMemoryState();
    const agent = wm.agent || "atlas";
    await runBrain(ctx.cwd, ["save", "-"], {
      agent,
      topic_key: `${agent}/turn-${Date.now()}`,
      type: "action",
      content: `Turno completado. Quest: ${wm.quest || "-"} | Next: ${wm.nextAction || "-"}`.slice(0, 500),
    });
    if (wm.activeSkill) {
      await runBrain(ctx.cwd, ["skill", "exec", "-"], {
        skill_id: wm.activeSkill,
        agent,
        success: true,
        stage: wm.procedureStage,
      });
    }
  });
}
