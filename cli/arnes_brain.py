"""
ARNES BRAIN - Memoria cerebral del harness RPG
=============================================
SQLite + FTS5. HIPOCAMPO del arnes: guarda recuerdos (observations),
misiones (quests), sesiones, agentes y relaciones (edges, FASE 2).

Uso (desde Python):
    from arnes_brain import ArnesBrain
    brain = ArnesBrain(db_path)
    brain.save_observation(agent="vivi", topic_key="vivi/ui-patterns",
                           type="pattern", content="...")

Uso (desde CLI PowerShell): ver arnes-memory.ps1
100% local. CERO dependencias externas. Solo Python 3.14 + SQLite nativo.
"""

import json
import os
import sqlite3
import sys
import datetime


SCHEMA = """
CREATE TABLE IF NOT EXISTS agents (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    class        TEXT,
    role         TEXT,
    model        TEXT,
    trust_score  REAL DEFAULT 0.5,
    xp           INTEGER DEFAULT 0,
    level        INTEGER DEFAULT 1,
    created_at   TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS observations (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    agent       TEXT NOT NULL,
    topic_key   TEXT NOT NULL,
    type        TEXT NOT NULL,          -- bugfix | decision | pattern | discovery | preference | verdict | recommendation | action | session_summary
    content     TEXT NOT NULL,
    quest_id    TEXT,
    created_at  TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (agent) REFERENCES agents(id)
);

CREATE TABLE IF NOT EXISTS quests (
    id          TEXT PRIMARY KEY,        -- Q-001
    description TEXT,
    quest_type  TEXT,                    -- frontend | backend | fix | architecture | research | devops | boss
    party       TEXT,                    -- JSON: ["vivi","eiko"]
    result      TEXT,                    -- PASS | FAIL_PARTIAL | FAIL_TOTAL
    tokens_used INTEGER DEFAULT 0,
    created_at  TEXT DEFAULT (datetime('now')),
    completed_at TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at  TEXT DEFAULT (datetime('now')),
    ended_at    TEXT,
    summary     TEXT
);

CREATE TABLE IF NOT EXISTS edges (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    node_a      TEXT NOT NULL,           -- "login-form"
    node_b      TEXT NOT NULL,           -- "zod"
    relation    TEXT NOT NULL,           -- "uses" | "created_by" | "depends_on" | "touched_by"
    agent       TEXT,
    quest_id    TEXT,
    created_at  TEXT DEFAULT (datetime('now'))
);

CREATE VIRTUAL TABLE IF NOT EXISTS observations_fts USING fts5(
    content,
    content_rowid='id',
    content='observations',
    tokenize='unicode61'
);
"""

TRIGGERS = """
CREATE TRIGGER IF NOT EXISTS observations_ai AFTER INSERT ON observations BEGIN
    INSERT INTO observations_fts(rowid, content) VALUES (new.id, new.content);
END;
CREATE TRIGGER IF NOT EXISTS observations_ad AFTER DELETE ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, content)
    VALUES ('delete', old.id, old.content);
END;
CREATE TRIGGER IF NOT EXISTS observations_au AFTER UPDATE ON observations BEGIN
    INSERT INTO observations_fts(observations_fts, rowid, content)
    VALUES ('delete', old.id, old.content);
    INSERT INTO observations_fts(rowid, content) VALUES (new.id, new.content);
END;
"""


class ArnesBrain:
    """Cerebro del arnes: memoria persistente con SQLite + FTS5."""

    def __init__(self, db_path):
        self.db_path = db_path
        os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
        self._conn = sqlite3.connect(db_path)
        self._conn.row_factory = sqlite3.Row
        self._conn.executescript(SCHEMA)
        self._conn.executescript(TRIGGERS)
        self._conn.commit()

    # ---------- AGENTS ----------
    def upsert_agent(self, agent_id, name=None, cls=None, role=None, model=None):
        existing = self._conn.execute(
            "SELECT * FROM agents WHERE id=?", (agent_id,)).fetchone()
        if existing:
            self._conn.execute(
                "UPDATE agents SET name=COALESCE(?,name), class=COALESCE(?,class), "
                "role=COALESCE(?,role), model=COALESCE(?,model) WHERE id=?",
                (name, cls, role, model, agent_id))
        else:
            self._conn.execute(
                "INSERT INTO agents (id, name, class, role, model) VALUES (?,?,?,?,?)",
                (agent_id, name or agent_id, cls, role, model))
        self._conn.commit()
        return agent_id

    def list_agents(self):
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM agents ORDER BY id")]

    def get_agent(self, agent_id):
        return self._conn.execute(
            "SELECT * FROM agents WHERE id=?", (agent_id,)).fetchone()

    def add_xp(self, agent_id, xp_gain):
        self._conn.execute(
            "UPDATE agents SET xp=xp+?, level=1+(xp+?)/100 WHERE id=?",
            (xp_gain, xp_gain, agent_id))
        self._conn.commit()

    # ---------- OBSERVATIONS ----------
    def save_observation(self, agent, topic_key, type, content, quest_id=None):
        cur = self._conn.execute(
            "INSERT INTO observations (agent, topic_key, type, content, quest_id) "
            "VALUES (?,?,?,?,?)", (agent, topic_key, type, content, quest_id))
        self._conn.commit()
        return cur.lastrowid

    def search(self, query, agent=None, limit=20):
        """Búsqueda FTS5 - recall selectivo. Solo trae lo relevante."""
        params = []
        sql = "SELECT o.* FROM observations o JOIN observations_fts f ON o.id=f.rowid WHERE observations_fts MATCH ?"
        params.append(query)
        if agent:
            sql += " AND o.agent=?"
            params.append(agent)
        sql += " ORDER BY o.created_at DESC LIMIT ?"
        params.append(limit)
        return [dict(r) for r in self._conn.execute(sql, params)]

    def agent_memory(self, agent, limit=50):
        """Memoria completa de un agente - namespace privado."""
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM observations WHERE agent=? ORDER BY created_at DESC LIMIT ?",
            (agent, limit))]

    def get_observation(self, obs_id):
        return self._conn.execute(
            "SELECT * FROM observations WHERE id=?", (obs_id,)).fetchone()

    def update_observation(self, obs_id, content=None, topic_key=None):
        if content is not None:
            self._conn.execute("UPDATE observations SET content=? WHERE id=?",
                               (content, obs_id))
        if topic_key is not None:
            self._conn.execute("UPDATE observations SET topic_key=? WHERE id=?",
                               (topic_key, obs_id))
        self._conn.commit()

    def delete_observation(self, obs_id):
        self._conn.execute("DELETE FROM observations WHERE id=?", (obs_id,))
        self._conn.commit()

    def recent_context(self, limit=30):
        """Contexto reciente del harness - para arranque de sesion."""
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM observations ORDER BY created_at DESC LIMIT ?", (limit,))]

    def count_observations(self):
        return self._conn.execute("SELECT COUNT(*) FROM observations").fetchone()[0]

    # ---------- QUESTS ----------
    def save_quest(self, quest_id, description, quest_type, party, result, tokens_used=0):
        self._conn.execute(
            "INSERT INTO quests (id, description, quest_type, party, result, tokens_used, completed_at) "
            "VALUES (?,?,?,?,?,?,datetime('now')) "
            "ON CONFLICT(id) DO UPDATE SET result=excluded.result, "
            "tokens_used=excluded.tokens_used, completed_at=excluded.completed_at",
            (quest_id, description, quest_type, json.dumps(party), result, tokens_used))
        self._conn.commit()
        return quest_id

    def quest_history(self, limit=50):
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM quests ORDER BY created_at DESC LIMIT ?", (limit,))]

    def next_quest_id(self):
        row = self._conn.execute("SELECT MAX(id) FROM quests").fetchone()
        if not row or not row[0]:
            return "Q-001"
        num = int(row[0].replace("Q-", "")) + 1
        return f"Q-{num:03d}"

    # ---------- SESSIONS ----------
    def start_session(self):
        cur = self._conn.execute("INSERT INTO sessions DEFAULT VALUES")
        self._conn.commit()
        return cur.lastrowid

    def end_session(self, session_id, summary=None):
        self._conn.execute(
            "UPDATE sessions SET ended_at=datetime('now'), summary=? WHERE id=?",
            (summary, session_id))
        self._conn.commit()

    # ---------- EDGES (FASE 2) ----------
    def add_edge(self, node_a, node_b, relation, agent=None, quest_id=None):
        cur = self._conn.execute(
            "INSERT INTO edges (node_a, node_b, relation, agent, quest_id) VALUES (?,?,?,?,?)",
            (node_a, node_b, relation, agent, quest_id))
        self._conn.commit()
        return cur.lastrowid

    def query_edges(self, node=None, relation=None, agent=None):
        sql = "SELECT * FROM edges WHERE 1=1"
        params = []
        if node:
            sql += " AND (node_a=? OR node_b=?)"
            params += [node, node]
        if relation:
            sql += " AND relation=?"
            params.append(relation)
        if agent:
            sql += " AND agent=?"
            params.append(agent)
        sql += " ORDER BY created_at DESC LIMIT 100"
        return [dict(r) for r in self._conn.execute(sql, params)]

    def neighbors(self, node, max_depth=1, relation=None):
        """Vecinos de un nodo hasta profundidad max_depth (recorrido de relaciones)."""
        if max_depth < 1:
            return []
        visited = {node: 0}
        queue = [node]
        result = []
        while queue:
            current = queue.pop(0)
            depth = visited[current]
            if depth >= max_depth:
                continue
            sql = "SELECT * FROM edges WHERE node_a=? OR node_b=?"
            params = [current, current]
            if relation:
                sql += " AND relation=?"
                params.append(relation)
            for e in self._conn.execute(sql, params):
                other = e["node_b"] if e["node_a"] == current else e["node_a"]
                if other not in visited:
                    visited[other] = depth + 1
                    queue.append(other)
                    result.append({
                        "from": current, "to": other,
                        "relation": e["relation"], "agent": e["agent"],
                        "depth": depth + 1
                    })
        return result

    def path(self, start, end, max_depth=6):
        """BFS path-finding: encuentra el camino mas corto entre dos nodos."""
        if start == end:
            return [{"from": start, "to": end, "relation": "self"}]
        visited = {start}
        queue = [(start, [])]
        while queue:
            current, path = queue.pop(0)
            if len(path) >= max_depth:
                continue
            for e in self._conn.execute(
                    "SELECT * FROM edges WHERE node_a=? OR node_b=?", (current, current)):
                other = e["node_b"] if e["node_a"] == current else e["node_a"]
                edge_info = {"from": current, "to": other, "relation": e["relation"]}
                if other == end:
                    return path + [edge_info]
                if other not in visited:
                    visited.add(other)
                    queue.append((other, path + [edge_info]))
        return []

    def graph_stats(self):
        """Estadisticas del grafo: nodos, edges, relaciones mas comunes."""
        edges = [dict(r) for r in self._conn.execute("SELECT * FROM edges")]
        nodes = set()
        for e in edges:
            nodes.add(e["node_a"])
            nodes.add(e["node_b"])
        relations = {}
        for e in edges:
            relations[e["relation"]] = relations.get(e["relation"], 0) + 1
        agents = {}
        for e in edges:
            if e["agent"]:
                agents[e["agent"]] = agents.get(e["agent"], 0) + 1
        return {
            "nodes": len(nodes),
            "edges": len(edges),
            "relations": relations,
            "agents_active": agents,
        }

    # ---------- EXPORT / IMPORT ----------
    def export_jsonl(self, out_dir):
        """Snapshot portable para git/backup."""
        os.makedirs(out_dir, exist_ok=True)
        files = {}
        for row in self._conn.execute(
                "SELECT * FROM observations ORDER BY id"):
            agent = row["agent"]
            path = os.path.join(out_dir, f"{agent}-memory.jsonl")
            with open(path, "a", encoding="utf-8") as f:
                f.write(json.dumps(dict(row), ensure_ascii=False) + "\n")
            files[path] = files.get(path, 0) + 1
        return files

    def import_jsonl(self, in_dir):
        """Recupera memoria desde JSONL si no hay db."""
        count = 0
        for fname in os.listdir(in_dir):
            if not fname.endswith(".jsonl"):
                continue
            path = os.path.join(in_dir, fname)
            agent = fname.replace("-memory.jsonl", "").replace(".jsonl", "")
            with open(path, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                        self.save_observation(
                            agent=data.get("agent", agent),
                            topic_key=data.get("topic_key", "imported"),
                            type=data.get("type", "discovery"),
                            content=data.get("content", ""),
                            quest_id=data.get("quest_id"))
                        count += 1
                    except json.JSONDecodeError:
                        continue
        return count

    # ---------- STATS ----------
    def stats(self):
        return {
            "agents": self._conn.execute("SELECT COUNT(*) FROM agents").fetchone()[0],
            "observations": self._conn.execute("SELECT COUNT(*) FROM observations").fetchone()[0],
            "quests": self._conn.execute("SELECT COUNT(*) FROM quests").fetchone()[0],
            "sessions": self._conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0],
            "edges": self._conn.execute("SELECT COUNT(*) FROM edges").fetchone()[0],
            "db_size_bytes": os.path.getsize(self.db_path),
        }

    def close(self):
        self._conn.close()


def _read_json_arg(raw):
    """Lee JSON desde argumento o desde stdin (si raw == '-' o vacio)."""
    if raw and raw != "-":
        return json.loads(raw)
    # Leer de stdin (pipe desde PowerShell evita problemas de escaping)
    data = sys.stdin.read().strip()
    if not data:
        return {}
    return json.loads(data)


def main():
    """CLI: python arnes_brain.py <db> <command> [args]"""
    if len(sys.argv) < 3:
        print(json.dumps({"error": "uso: arnes_brain.py <db> <command> [args]"}))
        sys.exit(1)

    db_path, command = sys.argv[1], sys.argv[2]
    brain = ArnesBrain(db_path)

    if command == "init":
        agents = _read_json_arg(sys.argv[3]) if len(sys.argv) > 3 else []
        for a in agents:
            brain.upsert_agent(a["id"], a.get("name"), a.get("class"),
                               a.get("role"), a.get("model"))
        print(json.dumps(brain.stats()))

    elif command == "save":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        obs_id = brain.save_observation(
            data.get("agent", "atlas"),
            data.get("topic_key", "atlas/general"),
            data.get("type", "discovery"),
            data.get("content", ""),
            data.get("quest_id"))
        print(json.dumps({"id": obs_id, "status": "saved"}))

    elif command == "search":
        query = sys.argv[3]
        agent = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else None
        limit = int(sys.argv[5]) if len(sys.argv) > 5 else 20
        print(json.dumps(brain.search(query, agent=agent, limit=limit), ensure_ascii=False))

    elif command == "context":
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 30
        print(json.dumps(brain.recent_context(limit), ensure_ascii=False))

    elif command == "agent":
        agent = sys.argv[3]
        limit = int(sys.argv[4]) if len(sys.argv) > 4 else 50
        print(json.dumps(brain.agent_memory(agent, limit), ensure_ascii=False))

    elif command == "export":
        out = sys.argv[3]
        files = brain.export_jsonl(out)
        print(json.dumps({"exported": files, "count": len(files)}))

    elif command == "import":
        indir = sys.argv[3]
        count = brain.import_jsonl(indir)
        print(json.dumps({"imported": count}))

    elif command == "stats":
        print(json.dumps(brain.stats()))

    elif command == "quest":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        qid = brain.save_quest(
            data.get("id", brain.next_quest_id()),
            data.get("description", ""),
            data.get("quest_type", "general"),
            data.get("party", []),
            data.get("result", "PASS"),
            data.get("tokens_used", 0))
        print(json.dumps({"quest_id": qid, "status": "saved"}))

    elif command == "quests":
        print(json.dumps(brain.quest_history(), ensure_ascii=False))

    elif command == "edge":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        eid = brain.add_edge(
            data.get("node_a", ""), data.get("node_b", ""),
            data.get("relation", "related"),
            data.get("agent"), data.get("quest_id"))
        print(json.dumps({"edge_id": eid, "status": "saved"}))

    elif command == "edges":
        node = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "-" else None
        print(json.dumps(brain.query_edges(node=node), ensure_ascii=False))

    elif command == "neighbors":
        node = sys.argv[3]
        depth = int(sys.argv[4]) if len(sys.argv) > 4 else 1
        print(json.dumps(brain.neighbors(node, max_depth=depth), ensure_ascii=False))

    elif command == "path":
        start = sys.argv[3]
        end = sys.argv[4]
        max_depth = int(sys.argv[5]) if len(sys.argv) > 5 else 6
        print(json.dumps(brain.path(start, end, max_depth), ensure_ascii=False))

    elif command == "graph-stats":
        print(json.dumps(brain.graph_stats(), ensure_ascii=False))

    else:
        print(json.dumps({"error": f"comando desconocido: {command}"}))

    brain.close()


if __name__ == "__main__":
    main()
