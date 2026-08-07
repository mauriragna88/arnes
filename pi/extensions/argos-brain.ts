import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";

export function isArnesProject(cwd: string): boolean {
  return existsSync(join(cwd, ".arnes", "arnes.db"));
}

export function resolveBrainPath(cwd: string): string {
  // La fusión asume argos pi desde la raíz del repo (donde vive cli/arnes_brain.py)
  const local = resolve(cwd, "cli", "arnes_brain.py");
  if (existsSync(local)) return local;
  throw new Error("ARGOS: no se encontró cli/arnes_brain.py en la raíz del proyecto");
}

export async function runBrain(
  cwd: string,
  args: string[],
  stdinJson?: unknown
): Promise<{ ok: boolean; data: unknown; error?: string }> {
  try {
    const brain = resolveBrainPath(cwd);
    const db = join(cwd, ".arnes", "arnes.db");
    const child = spawn("python", [brain, db, ...args], {
      cwd,
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    if (stdinJson !== undefined) {
      child.stdin.write(JSON.stringify(stdinJson));
    }
    child.stdin.end();
    const code: number = await new Promise((res) => child.on("close", res));
    if (code !== 0) {
      return { ok: false, data: null, error: stderr.trim() || `exit ${code}` };
    }
    const trimmed = stdout.trim();
    if (!trimmed) return { ok: true, data: null };
    try {
      return { ok: true, data: JSON.parse(trimmed) };
    } catch {
      return { ok: true, data: trimmed };
    }
  } catch (e) {
    return { ok: false, data: null, error: (e as Error).message };
  }
}
