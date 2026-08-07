import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getWorkingMemoryBlock } from "./argos-working-memory.js";

export function getCognitionBlock(state: {
  questType?: string;
  agent?: string;
  path?: string;
}): string {
  return [
    "## ARGOS COGNITIVE ROUTER",
    `Path cognitivo actual: ${state.path ?? "por decidir"} · Quest type: ${state.questType ?? "-"} · Agente: ${state.agent ?? "atlas"}`,
    "Eres ARGOS SUPERPOWERS. Elige el esfuerzo MÍNIMO SUFICIENTE (nunca el máximo por defecto):",
    "- FAST: ya lo sé (working/semantic memory) → responde. Sin agentes, sin skills, sin tools extra.",
    "- RECALL: existe en memoria pero no en working memory → busca (argos_memory_search) y responde. Sin plan.",
    "- SKILL: tarea conocida con procedimiento → activa la skill (ej. systematic-debugging para bugs). 1 agente, contexto ligero.",
    "- DELIBERATE: feature normal, contexto incompleto → memoria + tools + agente + skill + verificación.",
    "- DEEP: arquitectura/seguridad/migración/riesgo/conflicto → SDD/FDD/Amarant/party/Auron/Tywin. Especialistas, verificación fuerte.",
    "",
    "NUNCA: no sé → inventar. INVESTIGA (memoria → repo → tools).",
    "Jerarquía de evidencia: repo verificado > tests/tools > hecho del usuario > memoria verificada > memoria observada > inferencia > hipótesis.",
    "",
    getWorkingMemoryBlock(),
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, _ctx) => {
    if (!event.prompt) return;
    return {
      message: {
        customType: "argos-cognition",
        content: getCognitionBlock({}),
        display: false,
      },
    };
  });
}
