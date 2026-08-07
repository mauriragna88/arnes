import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { runBrain } from "./argos-brain.js";

export function memoryCard(row: any): string {
  return [
    `MEMORY #${row.id}`,
    "",
    `kind: ${row.memory_kind ?? "-"}`,
    `topic: ${row.topic_key}`,
    "",
    `state: ${row.state}`,
    `epistemic: ${row.epistemic_type ?? "unverified"}`,
    "",
    `confidence: ${row.confidence}`,
    `trust: ${row.trust ?? "-"}`,
    `importance: ${row.score ?? "-"}`,
    "",
    `source: ${row.source || "-"}`,
    "",
    `summary:`,
    ` ${row.content}`,
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  const register = (
    name: string,
    label: string,
    description: string,
    params: any,
    map: (p: any) => string[],
    customExecute?: (params: any, ctx: any) => Promise<{ content: any; details: any }>
  ) => {
    pi.registerTool({
      name,
      label,
      description,
      parameters: params,
      async execute(_id, params: any, _sig, _upd, ctx) {
        if (!runBrain) throw new Error("ARGOS: no project");
        if (customExecute) {
          return customExecute(params, ctx);
        }
        const res = await runBrain(ctx.cwd, map(params));
        if (!res.ok)
          return {
            content: [{ type: "text", text: `ARGOS error: ${res.error}` }],
            details: {},
          };
        const rows = res.data as any[];
        const text = Array.isArray(rows)
          ? rows.map(memoryCard).join("\n\n---\n\n")
          : JSON.stringify(res.data, null, 2);
        return {
          content: [{ type: "text", text }],
          details: { count: Array.isArray(rows) ? rows.length : 0 },
        };
      },
    });
  };

  // Search: uses recall command
  register(
    "argos_memory_search",
    "Memory Search",
    "Busca hechos verificados en Memory V3 (RAG). Úsalo antes de afirmar hechos del proyecto.",
    Type.Object({
      query: Type.String({ description: "búsqueda" }),
      agent: Type.Optional(Type.String()),
      limit: Type.Optional(Type.Integer({ default: 5 })),
      tag: Type.Optional(Type.String()),
    }),
    (p) => ["recall", p.query, p.agent ?? "-", String(p.limit ?? 5), p.tag ?? "-"]
  );

  // Get: uses get command
  register(
    "argos_memory_get",
    "Memory Get",
    "Obtiene una memoria por id.",
    Type.Object({ id: Type.Integer() }),
    (p) => ["get", String(p.id)]
  );

  // Save: uses save command with JSON stdin
  register(
    "argos_memory_save",
    "Memory Save",
    "Guarda una observación (working|episodic|semantic|procedural). Después de trabajar.",
    Type.Object({
      agent: Type.String(),
      topic_key: Type.String(),
      type: Type.Union([
        Type.Literal("bugfix"),
        Type.Literal("decision"),
        Type.Literal("pattern"),
        Type.Literal("discovery"),
        Type.Literal("preference"),
        Type.Literal("verdict"),
        Type.Literal("recommendation"),
        Type.Literal("action"),
        Type.Literal("session_summary"),
      ]),
      content: Type.String(),
      kind: Type.Optional(Type.String()),
      confidence: Type.Optional(Type.Number()),
      score: Type.Optional(Type.Integer()),
      quest_id: Type.Optional(Type.String()),
    }),
    (p) => ["save", "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, ["save", "-"], params);
      return {
        content: [{ type: "text", text: res.ok ? `Guardado id=${JSON.stringify(res.data)}` : `ARGOS error: ${res.error}` }],
        details: {},
      };
    }
  );

  // Update: uses update command with JSON stdin
  register(
    "argos_memory_update",
    "Memory Update",
    "Actualiza contenido de una memoria (mantiene revisiones).",
    Type.Object({ id: Type.Integer(), content: Type.String() }),
    (p) => ["update", "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, ["update", "-"], params);
      return {
        content: [{ type: "text", text: res.ok ? "Actualizado" : `ARGOS error: ${res.error}` }],
        details: {},
      };
    }
  );

  // Verify: uses verify command with JSON stdin
  register(
    "argos_memory_verify",
    "Memory Verify",
    "Marca una memoria como verificada (PASS/FAIL) con evidencia.",
    Type.Object({
      id: Type.Integer(),
      verdict: Type.String(),
      evidence: Type.Optional(Type.String()),
    }),
    (p) => ["verify", "-"],
    async (params: any, ctx: any) => {
      const res = await runBrain(ctx.cwd, ["verify", "-"], params);
      return {
        content: [{ type: "text", text: res.ok ? "Verificado" : `ARGOS error: ${res.error}` }],
        details: {},
      };
    }
  );

  // Stats: uses stats command
  register(
    "argos_memory_stats",
    "Memory Stats",
    "Estadísticas del cerebro (observaciones, estados, FTS, grafo).",
    Type.Object({}),
    (p) => ["stats"]
  );

  // Context: uses context command
  register(
    "argos_memory_context",
    "Memory Context",
    "Contexto reciente del harness.",
    Type.Object({}),
    (p) => ["context"]
  );

  // Timeline: uses revisions command
  register(
    "argos_memory_timeline",
    "Memory Timeline",
    "Timeline de una memoria (revisiones).",
    Type.Object({ id: Type.Integer() }),
    (p) => ["revisions", String(p.id)]
  );

  // Relations: uses edges command
  register(
    "argos_memory_relations",
    "Memory Relations",
    "Relaciones del grafo de un nodo.",
    Type.Object({ node: Type.String() }),
    (p) => ["edges", p.node]
  );
}
