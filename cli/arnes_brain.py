"""
OSMA - Memoria cerebral del harness RPG
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
import re
import sqlite3
import sys
import datetime


def _fts_escape(query):
    """Sanitiza el texto para MATCH de FTS5: solo palabras alfanumericas (con acentos)."""
    words = re.findall(r"[\wÃƒÂÃƒâ€°ÃƒÂÃƒâ€œÃƒÅ¡Ãƒâ€˜ÃƒÅ“ÃƒÂ¡ÃƒÂ©ÃƒÂ­ÃƒÂ³ÃƒÂºÃƒÂ±ÃƒÂ¼]+", query or "")
    return " ".join(words) or '""'


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
    score       INTEGER DEFAULT 0,      -- importancia 1-5
    tags        TEXT DEFAULT '',
    archived    INTEGER DEFAULT 0,
    memory_kind TEXT DEFAULT 'episodic',    -- working | episodic | semantic | procedural
    confidence  REAL DEFAULT 0.5,           -- que tan cierto es (0-1)
    storage_strength REAL DEFAULT 0.4,      -- que tan consolidado (0-1)
    retrieval_strength REAL DEFAULT 0.6,    -- que tan accesible ahora (0-1)
    last_retrieved_at TEXT,
    volatility  TEXT DEFAULT 'stable',      -- immutable | stable | slow | dynamic | ephemeral
    state       TEXT DEFAULT 'active',      -- active | dormant | archived | contested | superseded
    evidence    TEXT DEFAULT '',            -- JSON: fuentes independientes
    source      TEXT DEFAULT '',
    supersedes  INTEGER,
    created_at  TEXT DEFAULT (datetime('now'))
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
    weight      REAL DEFAULT 0.5,            -- fuerza de la asociacion (0-1)
    success_count  INTEGER DEFAULT 0,
    failure_count  INTEGER DEFAULT 0,
    coactivation_count INTEGER DEFAULT 0,
    last_activated_at TEXT,
    last_success_at  TEXT,
    created_at  TEXT DEFAULT (datetime('now'))
);

-- V3: dominio de skills por proyecto (aprendizaje procedural)
CREATE TABLE IF NOT EXISTS skill_mastery (
    skill_id        TEXT PRIMARY KEY,
    skill_version   TEXT,
    state           TEXT DEFAULT 'new',      -- new | learning | reliable | mastered | needs_review | stale | quarantined
    mastery         REAL DEFAULT 0.0,
    confidence      REAL DEFAULT 0.0,
    success_count   INTEGER DEFAULT 0,
    failure_count   INTEGER DEFAULT 0,
    consecutive_successes INTEGER DEFAULT 0,
    trigger_patterns    TEXT DEFAULT '[]',
    anti_trigger_patterns TEXT DEFAULT '[]',
    contexts        TEXT DEFAULT '[]',
    failure_patterns    TEXT DEFAULT '[]',
    avg_tokens      REAL DEFAULT 0,
    avg_cost        REAL DEFAULT 0,
    last_used_at    TEXT,
    last_success_at TEXT,
    last_failure_at TEXT,
    last_verified_at TEXT,
    created_at      TEXT DEFAULT (datetime('now')),
    updated_at      TEXT
);

-- V3: registro de cada ejecucion de skill (que funciona de verdad)
CREATE TABLE IF NOT EXISTS skill_executions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_id      TEXT,
    skill_version TEXT,
    agent         TEXT,
    quest_id      TEXT,
    trigger       TEXT,
    context_summary TEXT,
    model         TEXT,
    provider      TEXT,
    started_at    TEXT,
    finished_at   TEXT,
    result        TEXT,
    verdict       TEXT,
    success       INTEGER DEFAULT 0,
    evidence      TEXT DEFAULT '',
    error         TEXT,
    tokens_in     INTEGER DEFAULT 0,
    tokens_out    INTEGER DEFAULT 0,
    tool_calls    INTEGER DEFAULT 0,
    created_at    TEXT DEFAULT (datetime('now'))
);

-- V3: vinculos memoria <-> skill
CREATE TABLE IF NOT EXISTS skill_memory_links (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    memory_id     INTEGER,
    skill_id      TEXT,
    relation      TEXT DEFAULT 'supports',   -- supports | trigger | precondition | warning | counterexample | result
    weight        REAL DEFAULT 0.5,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    last_used     TEXT
);

-- V3: revision programada (spaced review)
CREATE TABLE IF NOT EXISTS memory_reviews (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    memory_id       INTEGER,
    next_review_at  TEXT,
    importance      INTEGER DEFAULT 0,
    volatility      TEXT,
    confidence      REAL DEFAULT 0,
    last_reviewed_at TEXT,
    created_at      TEXT DEFAULT (datetime('now'))
);

-- V3: version de esquema (migraciones idempotentes)
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);

-- V3: COGNITIVE CHECKPOINTS (estado operativo para reconstruir la mente de trabajo)
CREATE TABLE IF NOT EXISTS cognitive_checkpoints (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id         TEXT,
    quest_id           TEXT,
    agent              TEXT,
    reason             TEXT,
    created_at         TEXT DEFAULT (datetime('now')),
    goal               TEXT,
    phase              TEXT,
    completed_tasks    TEXT DEFAULT '[]',
    pending_tasks      TEXT DEFAULT '[]',
    active_files       TEXT DEFAULT '[]',
    modified_files     TEXT DEFAULT '[]',
    active_decisions   TEXT DEFAULT '[]',
    critical_memory_ids TEXT DEFAULT '[]',
    active_skill       TEXT,
    skill_state        TEXT DEFAULT '{}',
    blockers           TEXT DEFAULT '[]',
    errors             TEXT DEFAULT '[]',
    test_state         TEXT,
    build_state        TEXT,
    git_state          TEXT,
    next_action        TEXT,
    working_memory_ids TEXT DEFAULT '[]',
    tokens_used        INTEGER DEFAULT 0,
    context_usage      REAL DEFAULT 0,
    metadata           TEXT DEFAULT '{}',
    recovery_capsule   TEXT,
    continuity_score   REAL DEFAULT 0
);

-- V3: AUTONOMOUS PARTY (task graph de quests autonomas)
CREATE TABLE IF NOT EXISTS autonomous_quests (
    id             TEXT PRIMARY KEY,       -- school-platform-001
    description    TEXT,
    status         TEXT DEFAULT 'active',  -- active | paused | done | blocked
    party          TEXT DEFAULT '[]',      -- JSON: agentes elegidos por Atlas
    progress       TEXT DEFAULT '{}',
    mode           TEXT DEFAULT 'balanced',
    created_at     TEXT DEFAULT (datetime('now')),
    updated_at     TEXT
);

CREATE TABLE IF NOT EXISTS autonomous_tasks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    quest_id        TEXT,
    task_id         TEXT,                  -- AUTH-03
    description     TEXT,
    agent           TEXT,
    status          TEXT DEFAULT 'pending',-- pending | ready | running | pass | fail | blocked
    dependencies    TEXT DEFAULT '[]',     -- JSON: [task_id]
    acceptance      TEXT DEFAULT '',
    summary         TEXT DEFAULT '',
    evidence        TEXT DEFAULT '',
    files_changed   TEXT DEFAULT '[]',
    tests           TEXT DEFAULT '',
    blockers        TEXT DEFAULT '[]',
    attempts        INTEGER DEFAULT 0,
    model           TEXT DEFAULT '',
    escalated_model TEXT DEFAULT '',
    tokens_used     INTEGER DEFAULT 0,
    created_at      TEXT DEFAULT (datetime('now')),
    updated_at      TEXT
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
        self._migrate()
        self._conn.commit()

    def _migrate(self):
        """Migracion V3 idempotente: agrega columnas/tablas sin romper datos existentes."""
        def _has_column(table, col):
            return any(r["name"] == col for r in self._conn.execute("PRAGMA table_info(%s)" % table))

        # observaciones: columnas cognitivas V3
        for col, ddl in [
            ("score", "ALTER TABLE observations ADD COLUMN score INTEGER DEFAULT 0"),
            ("tags", "ALTER TABLE observations ADD COLUMN tags TEXT DEFAULT ''"),
            ("archived", "ALTER TABLE observations ADD COLUMN archived INTEGER DEFAULT 0"),
            ("memory_kind", "ALTER TABLE observations ADD COLUMN memory_kind TEXT DEFAULT 'episodic'"),
            ("confidence", "ALTER TABLE observations ADD COLUMN confidence REAL DEFAULT 0.5"),
            ("storage_strength", "ALTER TABLE observations ADD COLUMN storage_strength REAL DEFAULT 0.4"),
            ("retrieval_strength", "ALTER TABLE observations ADD COLUMN retrieval_strength REAL DEFAULT 0.6"),
            ("last_retrieved_at", "ALTER TABLE observations ADD COLUMN last_retrieved_at TEXT"),
            ("volatility", "ALTER TABLE observations ADD COLUMN volatility TEXT DEFAULT 'stable'"),
            ("state", "ALTER TABLE observations ADD COLUMN state TEXT DEFAULT 'active'"),
            ("evidence", "ALTER TABLE observations ADD COLUMN evidence TEXT DEFAULT ''"),
            ("source", "ALTER TABLE observations ADD COLUMN source TEXT DEFAULT ''"),
            ("supersedes", "ALTER TABLE observations ADD COLUMN supersedes INTEGER"),
        ]:
            if not _has_column("observations", col):
                self._conn.execute(ddl)

        # edges: pesos de asociacion
        for col, ddl in [
            ("weight", "ALTER TABLE edges ADD COLUMN weight REAL DEFAULT 0.5"),
            ("success_count", "ALTER TABLE edges ADD COLUMN success_count INTEGER DEFAULT 0"),
            ("failure_count", "ALTER TABLE edges ADD COLUMN failure_count INTEGER DEFAULT 0"),
            ("coactivation_count", "ALTER TABLE edges ADD COLUMN coactivation_count INTEGER DEFAULT 0"),
            ("last_activated_at", "ALTER TABLE edges ADD COLUMN last_activated_at TEXT"),
            ("last_success_at", "ALTER TABLE edges ADD COLUMN last_success_at TEXT"),
        ]:
            if not _has_column("edges", col):
                try:
                    self._conn.execute(ddl)
                except Exception:
                    pass

        # tablas V3 (CREATE IF NOT EXISTS cubre frescas; para viejas las crea)
        self._conn.execute("""CREATE TABLE IF NOT EXISTS skill_mastery (
            skill_id TEXT PRIMARY KEY, skill_version TEXT,
            state TEXT DEFAULT 'new', mastery REAL DEFAULT 0.0, confidence REAL DEFAULT 0.0,
            success_count INTEGER DEFAULT 0, failure_count INTEGER DEFAULT 0,
            consecutive_successes INTEGER DEFAULT 0,
            trigger_patterns TEXT DEFAULT '[]', anti_trigger_patterns TEXT DEFAULT '[]',
            contexts TEXT DEFAULT '[]', failure_patterns TEXT DEFAULT '[]',
            avg_tokens REAL DEFAULT 0, avg_cost REAL DEFAULT 0,
            last_used_at TEXT, last_success_at TEXT, last_failure_at TEXT, last_verified_at TEXT,
            created_at TEXT DEFAULT (datetime('now')), updated_at TEXT)""")
        self._conn.execute("""CREATE TABLE IF NOT EXISTS skill_executions (
            id INTEGER PRIMARY KEY AUTOINCREMENT, skill_id TEXT, skill_version TEXT, agent TEXT,
            quest_id TEXT, trigger TEXT, context_summary TEXT, model TEXT, provider TEXT,
            started_at TEXT, finished_at TEXT, result TEXT, verdict TEXT, success INTEGER DEFAULT 0,
            evidence TEXT DEFAULT '', error TEXT, tokens_in INTEGER DEFAULT 0,
            tokens_out INTEGER DEFAULT 0, tool_calls INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now')))""")
        self._conn.execute("""CREATE TABLE IF NOT EXISTS skill_memory_links (
            id INTEGER PRIMARY KEY AUTOINCREMENT, memory_id INTEGER, skill_id TEXT,
            relation TEXT DEFAULT 'supports', weight REAL DEFAULT 0.5,
            success_count INTEGER DEFAULT 0, failure_count INTEGER DEFAULT 0, last_used TEXT)""")
        self._conn.execute("""CREATE TABLE IF NOT EXISTS memory_reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT, memory_id INTEGER, next_review_at TEXT,
            importance INTEGER DEFAULT 0, volatility TEXT, confidence REAL DEFAULT 0,
            last_reviewed_at TEXT, created_at TEXT DEFAULT (datetime('now')))""")
        self._conn.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
        self._conn.execute("CREATE TABLE IF NOT EXISTS observation_revisions ("
                           "id INTEGER PRIMARY KEY AUTOINCREMENT, observation_id INTEGER NOT NULL,"
                           "content TEXT, type TEXT, created_at TEXT DEFAULT (datetime('now')))")
        self._conn.execute("""CREATE TABLE IF NOT EXISTS autonomous_quests (
            id TEXT PRIMARY KEY, description TEXT, status TEXT DEFAULT 'active',
            party TEXT DEFAULT '[]', progress TEXT DEFAULT '{}', mode TEXT DEFAULT 'balanced',
            created_at TEXT DEFAULT (datetime('now')), updated_at TEXT)""")
        self._conn.execute("""CREATE TABLE IF NOT EXISTS autonomous_tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT, quest_id TEXT, task_id TEXT, description TEXT,
            agent TEXT, status TEXT DEFAULT 'pending', dependencies TEXT DEFAULT '[]',
            acceptance TEXT DEFAULT '', summary TEXT DEFAULT '', evidence TEXT DEFAULT '',
            files_changed TEXT DEFAULT '[]', tests TEXT DEFAULT '', blockers TEXT DEFAULT '[]',
            attempts INTEGER DEFAULT 0, model TEXT DEFAULT '', escalated_model TEXT DEFAULT '',
            tokens_used INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime('now')), updated_at TEXT)""")

        # backfill: defaults cognitivos para observaciones existentes
        kind_map = {"decision": "semantic", "pattern": "semantic", "preference": "semantic",
                    "recommendation": "semantic", "bugfix": "semantic"}
        for type_name, kind in kind_map.items():
            self._conn.execute(
                "UPDATE observations SET memory_kind=? WHERE memory_kind='episodic' AND type=?",
                (kind, type_name))
        conf_defaults = {"decision": 0.7, "verdict": 0.85, "pattern": 0.6, "discovery": 0.45,
                         "preference": 0.6, "recommendation": 0.6, "action": 0.5, "bugfix": 0.65,
                         "session_summary": 0.75}
        for type_name, c in conf_defaults.items():
            self._conn.execute(
                "UPDATE observations SET confidence=? WHERE confidence=0.5 AND type=?",
                (c, type_name))
        self._conn.execute(
            "INSERT OR IGNORE INTO meta (key, value) VALUES ('schema_version', '3')")
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
    @staticmethod
    def _default_confidence(type_name):
        return {"decision": 0.7, "verdict": 0.85, "pattern": 0.6, "discovery": 0.45,
                "preference": 0.6, "recommendation": 0.6, "action": 0.5, "bugfix": 0.65,
                "session_summary": 0.75}.get(type_name, 0.5)

    @staticmethod
    def _default_kind(type_name):
        return ("semantic" if type_name in ("decision", "pattern", "preference",
                                            "recommendation", "bugfix") else "episodic")

    def save_observation(self, agent, topic_key, type, content, quest_id=None, score=0,
                         tags=None, memory_kind=None, confidence=None, volatility="stable",
                         evidence=None, source=None):
        kind = memory_kind or self._default_kind(type)
        conf = confidence if confidence is not None else self._default_confidence(type)
        tags_json = json.dumps(tags, ensure_ascii=False) if tags else ""
        ev_json = json.dumps(evidence, ensure_ascii=False) if evidence else ""
        cur = self._conn.execute(
            "INSERT INTO observations (agent, topic_key, type, content, quest_id, score, tags, "
            "memory_kind, confidence, storage_strength, retrieval_strength, volatility, state, "
            "evidence, source) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (agent, topic_key, type, content, quest_id, int(score), tags_json, kind, conf,
             0.4 if kind != "episodic" else 0.35, 0.6, volatility, "active", ev_json, source or ""))
        obs_id = cur.lastrowid
        self._conn.commit()
        self._schedule_review(obs_id, importance=int(score), volatility=volatility, confidence=conf)
        return obs_id

    def save_observation_upsert(self, agent, topic_key, type, content, quest_id=None, score=0,
                                tags=None, memory_kind=None, confidence=None, volatility="stable",
                                evidence=None, source=None):
        """Upsert: si el topico existe, guarda la revision previa y actualiza (V3)."""
        row = self._conn.execute(
            "SELECT id, content, type, confidence, storage_strength, evidence FROM observations "
            "WHERE agent=? AND topic_key=? ORDER BY id DESC LIMIT 1",
            (agent, topic_key)).fetchone()
        if row:
            self._conn.execute(
                "INSERT INTO observation_revisions (observation_id, content, type) VALUES (?,?,?)",
                (row["id"], row["content"], row["type"]))
            kind = memory_kind or self._default_kind(type)
            conf = confidence if confidence is not None else self._default_confidence(type)
            tags_json = json.dumps(tags, ensure_ascii=False) if tags else ""
            ev_json = json.dumps(evidence, ensure_ascii=False) if evidence else ""
            self._conn.execute(
                "UPDATE observations SET content=?, type=?, quest_id=?, score=?, tags=?, "
                "memory_kind=?, confidence=?, volatility=?, evidence=?, source=? WHERE id=?",
                (content, type, quest_id, int(score), tags_json, kind, conf, volatility,
                 ev_json, source or "", row["id"]))
            self._conn.commit()
            return row["id"]
        return self.save_observation(agent, topic_key, type, content, quest_id, score, tags,
                                     memory_kind, confidence, volatility, evidence, source)

    def _schedule_review(self, obs_id, importance=0, volatility="stable", confidence=0.5):
        """Spaced review: cuan seguido revalidar segun volatilidad e importancia."""
        days = {"immutable": 365, "stable": 90, "slow": 45, "dynamic": 14, "ephemeral": 5}.get(volatility, 90)
        if importance >= 4:
            days = max(1, days // 2)
        next_at = (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
                   + datetime.timedelta(days=days)).strftime("%Y-%m-%d %H:%M:%S")
        self._conn.execute(
            "INSERT INTO memory_reviews (memory_id, next_review_at, importance, volatility, confidence) "
            "VALUES (?,?,?,?,?)", (obs_id, next_at, importance, volatility, confidence))
        self._conn.commit()

    def _effective_retrieval(self, row, now=None):
        """Retrieval strength efectiva con decay por volatilidad (olvido adaptativo, no borrado)."""
        lambdas = {"immutable": 365.0, "stable": 90.0, "slow": 45.0, "dynamic": 14.0, "ephemeral": 5.0}
        lam = lambdas.get(row.get("volatility", "stable"), 90.0)
        last = row.get("last_retrieved_at")
        base = float(row.get("retrieval_strength", 0.6))
        if not last:
            return base
        try:
            last_dt = datetime.datetime.strptime(last, "%Y-%m-%d %H:%M:%S")
            now_dt = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
            days = max(0.0, (now_dt - last_dt).total_seconds() / 86400.0)
            return base * (2.0 ** (-days / lam))
        except Exception:
            return base

    def recall(self, query, agent=None, limit=5, tag=None):
        """Recall V3: BM25 + retrieval efectivo + confianza + importancia. Practica de recuperacion."""
        raw = self.search(query, agent=agent, limit=limit * 3, tag=tag)
        scored = []
        for r in raw:
            rs = self._effective_retrieval(r)
            bm25 = -float(r.get("rank", 0.0))
            # ranking ponderado: BM25 .5 + retrieval .2 + confianza .15 + importancia .15
            total = bm25 * 0.5 + rs * 0.2 + float(r.get("confidence", 0.5)) * 0.15 + (float(r.get("score", 0)) / 5.0) * 0.15
            r["effective_retrieval"] = round(rs, 3)
            r["_recall_score"] = round(total, 4)
            scored.append(r)
        scored.sort(key=lambda x: x["_recall_score"], reverse=True)
        top = scored[:limit]
        # practica de recuperacion: sube retrieval_strength del usado
        for r in top:
            new_rs = min(1.0, float(r.get("retrieval_strength", 0.6)) + 0.05)
            self._conn.execute(
                "UPDATE observations SET retrieval_strength=?, last_retrieved_at=datetime('now') WHERE id=?",
                (new_rs, r["id"]))
        self._conn.commit()
        return top

    def reinforce(self, obs_id, evidence=None, success=True):
        """Fortalecer: sube storage/confianza solo con evidencia real (no por repeticion)."""
        row = self._conn.execute("SELECT * FROM observations WHERE id=?", (obs_id,)).fetchone()
        if not row:
            return False
        delta = 0.06 if evidence else 0.02   # sin evidencia: refuerzo minimo (evita 5x repeticion = verdad)
        if success:
            conf = min(0.99, float(row["confidence"]) + delta)
            storage = min(0.99, float(row["storage_strength"]) + (0.08 if evidence else 0.03))
        else:
            conf = max(0.05, float(row["confidence"]) - delta * 2)
            storage = max(0.05, float(row["storage_strength"]) - delta)
        self._conn.execute(
            "UPDATE observations SET confidence=?, storage_strength=? WHERE id=?",
            (conf, storage, obs_id))
        self._conn.commit()
        return True

    def verify(self, obs_id, verdict, evidence=None):
        """Tywin: PASS sube confianza con evidencia; FAIL baja y puede marcar contested."""
        row = self._conn.execute("SELECT * FROM observations WHERE id=?", (obs_id,)).fetchone()
        if not row:
            return False
        if verdict == "PASS":
            conf = min(0.99, float(row["confidence"]) + 0.10)
            storage = min(0.99, float(row["storage_strength"]) + 0.10)
            state = "active"
        elif verdict == "FAIL":
            conf = max(0.05, float(row["confidence"]) - 0.15)
            storage = max(0.05, float(row["storage_strength"]) - 0.10)
            state = "contested" if float(row["confidence"]) >= 0.6 else row["state"]
        else:
            return False
        self._conn.execute(
            "UPDATE observations SET confidence=?, storage_strength=?, state=? WHERE id=?",
            (conf, storage, state, obs_id))
        self._conn.commit()
        return True

    def reconsolidate(self, obs_id, new_content, evidence=None):
        """Reconsolidacion: revision + actualizacion con evidencia (nunca sobrescribir en silencio)."""
        row = self._conn.execute("SELECT * FROM observations WHERE id=?", (obs_id,)).fetchone()
        if not row:
            return False
        self._conn.execute(
            "INSERT INTO observation_revisions (observation_id, content, type) VALUES (?,?,?)",
            (obs_id, row["content"], row["type"]))
        ev_json = json.dumps(evidence, ensure_ascii=False) if evidence else row["evidence"]
        self._conn.execute(
            "UPDATE observations SET content=?, evidence=?, "
            "storage_strength=?, state='active' WHERE id=?",
            (new_content, ev_json, min(0.99, float(row["storage_strength"]) + 0.05), obs_id))
        self._conn.commit()
        return True

    def search(self, query, agent=None, limit=20, tag=None):
        """Busqueda FTS5 con ranking BM25 (relevancia real). Fallback: por importancia
        si las keywords no coinciden (sinonimos, preguntas parafraseadas)."""
        words = _fts_escape(query).split()
        # intentos progresivos: todas las palabras (AND) -> primeras 2 -> primera (prefix)
        attempts = []
        if words:
            attempts.append(words)
            if len(words) > 2:
                attempts.append(words[:2])
            attempts.append(words[:1])

        for attempt in attempts:
            q = " ".join(w + "*" for w in attempt)
            params = []
            sql = ("SELECT o.*, bm25(observations_fts) AS rank FROM observations o "
                   "JOIN observations_fts f ON o.id=f.rowid "
                   "WHERE observations_fts MATCH ? AND o.archived=0 AND o.state != 'archived'")
            params.append(q)
            if agent:
                sql += " AND o.agent=?"
                params.append(agent)
            if tag:
                sql += " AND o.tags LIKE ?"
                params.append("%" + tag + "%")
            sql += " ORDER BY rank LIMIT ?"
            params.append(limit)
            rows = [dict(r) for r in self._conn.execute(sql, params)]
            if rows:
                return rows

        # fallback por importancia: memorias activas top-score (recuperar senal correcta)
        params = []
        sql = ("SELECT * FROM observations WHERE archived=0 AND state != 'archived' "
               "AND score >= 4 ORDER BY score DESC, created_at DESC LIMIT ?")
        params.append(limit)
        if agent:
            sql = sql.replace("WHERE archived=0 AND state != 'archived' ",
                              "WHERE archived=0 AND state != 'archived' AND agent=? ")
            params.insert(0, agent)
        if tag:
            sql = sql.replace(" AND score >= 4", " AND tags LIKE ? AND score >= 4")
            params.insert(-1, "%" + tag + "%")
        return [dict(r) for r in self._conn.execute(sql, params)]

    def agent_memory(self, agent, limit=50):
        """Memoria completa de un agente - namespace privado (relevantes primero)."""
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM observations WHERE agent=? AND archived=0 "
            "ORDER BY score DESC, created_at DESC LIMIT ?",
            (agent, limit))]

    def recent_context(self, limit=30):
        """Contexto reciente del harness - para arranque de sesion (importantes primero)."""
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM observations WHERE archived=0 "
            "ORDER BY score DESC, created_at DESC LIMIT ?",
            (limit,))]

    def list_revisions(self, obs_id, limit=50):
        """Historial de revisiones de una observacion (la memoria de la memoria)."""
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM observation_revisions WHERE observation_id=? ORDER BY id DESC LIMIT ?",
            (obs_id, limit))]

    def compact(self, older_than_days=30):
        """El sueno: resume observaciones antiguas en un digest por agente y las archiva."""
        cutoff = (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
                  - datetime.timedelta(days=older_than_days)).strftime("%Y-%m-%d %H:%M:%S")
        rows = [dict(r) for r in self._conn.execute(
            "SELECT * FROM observations WHERE archived=0 AND created_at < ? ORDER BY agent, created_at",
            (cutoff,))]
        by_agent = {}
        for r in rows:
            by_agent.setdefault(r["agent"], []).append(r)
        digests = 0
        for agent, obs in by_agent.items():
            digest = "\n".join("[{0}] {1}".format(o["topic_key"], o["content"]) for o in obs)
            if len(digest) > 12000:
                digest = digest[:12000] + "..."
            self._conn.execute(
                "INSERT INTO observations (agent, topic_key, type, content, score, tags) VALUES (?,?,?,?,?,?)",
                (agent, "{0}/compact-{1}".format(agent, datetime.date.today().isoformat()),
                 "session_summary", digest, 5, '["compact"]'))
            ids = [o["id"] for o in obs]
            placeholders = ",".join("?" * len(ids))
            self._conn.execute(
                "UPDATE observations SET archived=1, state='archived' WHERE id IN ({0})".format(placeholders), ids)
            digests += 1
        self._conn.commit()
        return {"compacted": len(rows), "digests": digests, "cutoff": cutoff}

    # ---------- V3: SKILL MASTERY (aprendizaje procedural por proyecto) ----------
    def skill_register(self, skill_id, version="1.0", triggers=None, anti_triggers=None):
        row = self._conn.execute("SELECT * FROM skill_mastery WHERE skill_id=?", (skill_id,)).fetchone()
        now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%d %H:%M:%S")
        if row:
            version_changed = row["skill_version"] != version
            self._conn.execute(
                "UPDATE skill_mastery SET skill_version=?, trigger_patterns=?, anti_trigger_patterns=?, "
                "state=?, mastery=?, updated_at=? WHERE skill_id=?",
                (version,
                 json.dumps(triggers or [], ensure_ascii=False),
                 json.dumps(anti_triggers or [], ensure_ascii=False),
                 "needs_review" if version_changed else row["state"],
                 float(row["mastery"]) * 0.5 if version_changed else row["mastery"],
                 now, skill_id))
        else:
            self._conn.execute(
                "INSERT INTO skill_mastery (skill_id, skill_version, state, mastery, confidence, "
                "trigger_patterns, anti_trigger_patterns, updated_at) VALUES (?,?,?,?,?,?,?,?)",
                (skill_id, version, "new", 0.0, 0.0,
                 json.dumps(triggers or [], ensure_ascii=False),
                 json.dumps(anti_triggers or [], ensure_ascii=False), now))
        self._conn.commit()
        return skill_id

    def skill_record_execution(self, skill_id, version="1.0", agent=None, quest_id=None, trigger=None,
                               success=True, verdict=None, evidence=None, error=None,
                               tokens_in=0, tokens_out=0, tool_calls=0, model=None, provider=None):
        now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%d %H:%M:%S")
        self._conn.execute(
            "INSERT INTO skill_executions (skill_id, skill_version, agent, quest_id, trigger, "
            "success, verdict, evidence, error, tokens_in, tokens_out, tool_calls, model, provider, "
            "started_at, finished_at, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (skill_id, version, agent, quest_id, trigger, 1 if success else 0, verdict,
             evidence or "", error or "", tokens_in, tokens_out, tool_calls, model, provider,
             now, now, now))
        # actualizar mastery
        sm = self._conn.execute("SELECT * FROM skill_mastery WHERE skill_id=?", (skill_id,)).fetchone()
        if not sm:
            self.skill_register(skill_id, version)
            sm = self._conn.execute("SELECT * FROM skill_mastery WHERE skill_id=?", (skill_id,)).fetchone()
        success_count = int(sm["success_count"]) + (1 if success else 0)
        failure_count = int(sm["failure_count"]) + (0 if success else 1)
        consec = (int(sm["consecutive_successes"]) + 1) if success else 0
        total = max(1, success_count + failure_count)
        mastery = round((success_count / total) * (0.6 + 0.4 * min(1.0, total / 10.0)), 3)
        # transiciones de estado
        state = sm["state"]
        if success and mastery >= 0.8 and total >= 8 and consec >= 3:
            state = "mastered"
        elif success and mastery >= 0.6 and total >= 3:
            state = "reliable" if state in ("new", "learning") else state
        elif success and state == "new":
            state = "learning"
        elif not success and state == "mastered":
            state = "needs_review"
        elif not success and failure_count >= 5 and success_count == 0:
            state = "quarantined"
        avg_tokens = ((float(sm["avg_tokens"]) * (total - 1)) + (tokens_in + tokens_out)) / total if total > 1 else (tokens_in + tokens_out)
        self._conn.execute(
            "UPDATE skill_mastery SET state=?, mastery=?, success_count=?, failure_count=?, "
            "consecutive_successes=?, avg_tokens=?, last_used_at=?, "
            "last_success_at=?, last_failure_at=?, confidence=?, updated_at=? WHERE skill_id=?",
            (state, mastery, success_count, failure_count, consec, round(avg_tokens, 1),
             now, now if success else sm["last_success_at"], now if not success else sm["last_failure_at"],
             round(min(0.95, mastery * 0.9 + 0.05), 3), now, skill_id))
        self._conn.commit()
        return {"skill": skill_id, "state": state, "mastery": mastery,
                "success": success, "total": total}

    def skill_status(self, skill_id=None):
        if skill_id:
            row = self._conn.execute("SELECT * FROM skill_mastery WHERE skill_id=?", (skill_id,)).fetchone()
            return dict(row) if row else None
        return [dict(r) for r in self._conn.execute(
            "SELECT * FROM skill_mastery ORDER BY mastery DESC")]

    def skill_links(self, memory_id, skill_id, relation="supports", success=True):
        """Refuerza/debilita el vinculo memoria<->skill con resultados verificados."""
        row = self._conn.execute(
            "SELECT * FROM skill_memory_links WHERE memory_id=? AND skill_id=?",
            (memory_id, skill_id)).fetchone()
        if row:
            sc = int(row["success_count"]) + (1 if success else 0)
            fc = int(row["failure_count"]) + (0 if success else 1)
            total = max(1, sc + fc)
            weight = round(sc / total, 3)
            self._conn.execute(
                "UPDATE skill_memory_links SET weight=?, success_count=?, failure_count=?, "
                "last_used=datetime('now') WHERE id=?", (weight, sc, fc, row["id"]))
        else:
            self._conn.execute(
                "INSERT INTO skill_memory_links (memory_id, skill_id, relation, weight, "
                "success_count, failure_count, last_used) VALUES (?,?,?,?,?,?,datetime('now'))",
                (memory_id, skill_id, relation, 0.5, 1 if success else 0, 0 if success else 1))
        self._conn.commit()

    # ---------- V3: COGNITIVE EFFORT ROUTER (FAST | RECALL | SKILL | DELIBERATE | DEEP) ----------
    def route(self, query, risk_text=None):
        """Decide cuanta cognicion gastar. NO confundir recuperacion facil con verdad."""
        risk_markers = ["drop", "delete from", "truncate", "production", "deploy", "migra",
                        "security", "secret", "password", "token", "rls", "permisos", "database"]
        risk = sum(1 for m in risk_markers if m in (query + " " + (risk_text or "")).lower())
        hits = self.recall(query, limit=3)
        top = hits[0] if hits else None
        if top:
            conf = float(top.get("confidence", 0.5))
            state = top.get("state", "active")
            vol = top.get("volatility", "stable")
            rs = float(top.get("effective_retrieval", 0.6))
            if conf >= 0.9 and state == "active" and vol != "ephemeral" and risk == 0:
                return {"path": "FAST", "reason": "hecho estable con confianza %.2f" % conf,
                        "memory": top.get("id")}
            if conf >= 0.7 and rs >= 0.3:
                return {"path": "RECALL", "reason": "memoria recuperable (conf %.2f, rs %.2f)" % (conf, rs),
                        "memory": top.get("id")}
        # skill matching
        skills = self._conn.execute(
            "SELECT * FROM skill_mastery WHERE mastery >= 0.8 AND state IN ('reliable','mastered')").fetchall()
        for s in skills:
            triggers = json.loads(s["trigger_patterns"] or "[]")
            if any(t.lower() in query.lower() for t in triggers):
                return {"path": "SKILL", "reason": "patron conocido -> %s (mastery %.2f)" % (s["skill_id"], s["mastery"]),
                        "skill": s["skill_id"]}
        if risk >= 2 or (top and float(top.get("confidence", 0)) < 0.35):
            return {"path": "DEEP", "reason": "riesgo %d o confianza baja -> orquestacion completa" % risk}
        return {"path": "DELIBERATE", "reason": "contexto nuevo o confianza media -> razonar con herramientas"}

    def list_due_reviews(self, limit=20):
        """Spaced review: memorias que toca revalidar."""
        now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).strftime("%Y-%m-%d %H:%M:%S")
        return [dict(r) for r in self._conn.execute(
            "SELECT r.*, o.topic_key, o.content FROM memory_reviews r "
            "JOIN observations o ON o.id=r.memory_id "
            "WHERE r.next_review_at <= ? ORDER BY r.next_review_at LIMIT ?", (now, limit))]

    # ---------- V3: AUTONOMOUS PARTY (task graph) ----------
    def quest_create(self, quest_id, description, mode="balanced"):
        self._conn.execute(
            "INSERT OR REPLACE INTO autonomous_quests (id, description, status, mode) "
            "VALUES (?,?,?,?)", (quest_id, description, "active", mode))
        self._conn.commit()
        return quest_id

    def quest_update(self, quest_id, **fields):
        sets = []
        params = []
        for k, v in fields.items():
            if v is None:
                continue
            sets.append("{0}=?".format(k))
            params.append(json.dumps(v, ensure_ascii=False) if isinstance(v, (list, dict)) else v)
        if not sets:
            return False
        params.append(quest_id)
        self._conn.execute("UPDATE autonomous_quests SET {0}, updated_at=datetime('now') WHERE id=?".format(", ".join(sets)), params)
        self._conn.commit()
        return True

    def quest_get(self, quest_id):
        row = self._conn.execute("SELECT * FROM autonomous_quests WHERE id=?", (quest_id,)).fetchone()
        if not row:
            return None
        q = dict(row)
        for k in ("party", "progress"):
            try:
                q[k] = json.loads(q.get(k) or "{}" if k == "progress" else q.get(k) or "[]")
            except Exception:
                q[k] = [] if k == "party" else {}
        return q

    def quest_list(self, limit=10):
        return [dict(r) for r in self._conn.execute(
            "SELECT id, description, status, mode, created_at FROM autonomous_quests "
            "ORDER BY created_at DESC LIMIT ?", (limit,))]

    def task_create(self, quest_id, task_id, description, agent, dependencies=None, acceptance=""):
        cur = self._conn.execute(
            "INSERT INTO autonomous_tasks (quest_id, task_id, description, agent, dependencies, acceptance) "
            "VALUES (?,?,?,?,?,?)",
            (quest_id, task_id, description, agent,
             json.dumps(dependencies or []), acceptance))
        self._conn.commit()
        return cur.lastrowid

    def task_list(self, quest_id=None, status=None):
        sql = "SELECT * FROM autonomous_tasks"
        params = []
        if quest_id:
            sql += " WHERE quest_id=?"
            params.append(quest_id)
        if status:
            sql += (" AND status=?" if quest_id else " WHERE status=?")
            params.append(status)
        sql += " ORDER BY id"
        return [dict(r) for r in self._conn.execute(sql, params)]

    def task_update(self, task_id, **fields):
        sets = []
        params = []
        for k, v in fields.items():
            if v is None:
                continue
            sets.append("{0}=?".format(k))
            params.append(json.dumps(v, ensure_ascii=False) if isinstance(v, (list, dict)) else v)
        if not sets:
            return False
        params.append(task_id)
        self._conn.execute(
            "UPDATE autonomous_tasks SET {0}, updated_at=datetime('now') WHERE id=?".format(", ".join(sets)), params)
        self._conn.commit()
        return True

    def task_ready(self, quest_id):
        """Tareas listas para ejecutar: pendientes cuyas dependencias estan PASS."""
        tasks = self.task_list(quest_id)
        by_id = {t["task_id"]: t for t in tasks}
        ready = []
        for t in tasks:
            if t["status"] != "pending":
                continue
            deps = json.loads(t.get("dependencies") or "[]")
            if all(by_id.get(d, {}).get("status") == "pass" for d in deps):
                ready.append(t)
        return ready

    def quest_progress(self, quest_id):
        tasks = self.task_list(quest_id)
        counts = {}
        for t in tasks:
            counts[t["status"]] = counts.get(t["status"], 0) + 1
        total = max(1, len(tasks))
        done = counts.get("pass", 0)
        return {"total": len(tasks), "pass": counts.get("pass", 0),
                "running": counts.get("running", 0), "ready": counts.get("ready", 0),
                "blocked": counts.get("blocked", 0), "fail": counts.get("fail", 0),
                "pct": round(done / total * 100)}

    # ---------- V3: COGNITIVE COMPACTION (checkpoints + recuperacion) ----------
    _CP_COLS = ["session_id", "quest_id", "agent", "reason", "goal", "phase",
                "completed_tasks", "pending_tasks", "active_files", "modified_files",
                "active_decisions", "critical_memory_ids", "active_skill", "skill_state",
                "blockers", "errors", "test_state", "build_state", "git_state",
                "next_action", "working_memory_ids", "tokens_used", "context_usage", "metadata"]

    def create_checkpoint(self, data):
        """Checkpoint cognitivo estructurado (JSON en columnas, no markdown gigante)."""
        vals = {k: data.get(k) for k in self._CP_COLS}
        for k in ["completed_tasks", "pending_tasks", "active_files", "modified_files",
                  "active_decisions", "critical_memory_ids", "blockers", "errors",
                  "working_memory_ids"]:
            v = vals[k]
            vals[k] = json.dumps(v, ensure_ascii=False) if v is not None else "[]"
        for k in ["skill_state", "metadata"]:
            v = vals[k]
            vals[k] = json.dumps(v, ensure_ascii=False) if v is not None else "{}"
        cols = ",".join(self._CP_COLS)
        ph = ",".join("?" * len(self._CP_COLS))
        cur = self._conn.execute(
            "INSERT INTO cognitive_checkpoints ({0}) VALUES ({1})".format(cols, ph),
            [vals[k] for k in self._CP_COLS])
        cp_id = cur.lastrowid
        cp = dict(self._conn.execute("SELECT * FROM cognitive_checkpoints WHERE id=?", (cp_id,)).fetchone())
        score = self.continuity_score(cp)
        capsule = self.build_recovery_capsule(cp)
        self._conn.execute(
            "UPDATE cognitive_checkpoints SET continuity_score=?, recovery_capsule=? WHERE id=?",
            (score, capsule, cp_id))
        self._conn.commit()
        return {"id": cp_id, "continuity_score": score}

    def get_checkpoint(self, cp_id):
        row = self._conn.execute("SELECT * FROM cognitive_checkpoints WHERE id=?", (cp_id,)).fetchone()
        if not row:
            return None
        cp = dict(row)
        for k in ["completed_tasks", "pending_tasks", "active_files", "modified_files",
                  "active_decisions", "critical_memory_ids", "blockers", "errors",
                  "working_memory_ids", "skill_state", "metadata"]:
            try:
                cp[k] = json.loads(cp.get(k) or "[]" if k in ("skill_state", "metadata") else cp.get(k) or "[]")
            except Exception:
                cp[k] = []
        return cp

    def list_checkpoints(self, limit=10):
        return [dict(r) for r in self._conn.execute(
            "SELECT id, quest_id, agent, goal, next_action, continuity_score, created_at "
            "FROM cognitive_checkpoints ORDER BY id DESC LIMIT ?", (limit,))]

    def build_recovery_capsule(self, cp):
        """Capsula de recuperacion determinista (500-1500 tkns): estado minimo para continuar."""
        def _loads(x):
            if x is None:
                return []
            if isinstance(x, (list, dict)):
                return x
            try:
                return json.loads(x) if x else []
            except Exception:
                return []
        lines = ["[ARGOS RECOVERY CAPSULE]"]
        proj = os.path.basename(os.path.dirname(os.path.dirname(os.path.abspath(self.db_path))))
        lines.append("Project: " + proj)
        if cp.get("quest_id"):
            lines.append("Quest: " + cp["quest_id"])
        if cp.get("agent"):
            lines.append("Agent: " + cp["agent"])
        if cp.get("goal"):
            lines.append("Goal: " + cp["goal"])
        comp = _loads(cp.get("completed_tasks"))
        if comp:
            lines.append("Completed:")
            lines += ["- " + str(t) for t in comp[:6]]
        pend = _loads(cp.get("pending_tasks"))
        if pend:
            lines.append("Pending:")
            lines += ["- " + str(t) for t in pend[:6]]
        decs = _loads(cp.get("critical_memory_ids"))
        if decs:
            lines.append("Critical decisions: " + " ".join("#" + str(d) for d in decs[:6]))
        skill = cp.get("active_skill")
        if skill:
            ss = cp.get("skill_state") or {}
            stage = ss.get("stage", "") if isinstance(ss, dict) else ""
            lines.append("Active procedure: " + skill + ((" (stage: " + stage + ")") if stage else ""))
        blocks = _loads(cp.get("blockers"))
        if blocks:
            lines.append("Current blocker: " + str(blocks[0]))
        if cp.get("next_action"):
            lines.append("NEXT ACTION: " + cp["next_action"])
        capsule = "\n".join(lines)
        if len(capsule) > 1500:
            capsule = capsule[:1500] + "\n..."
        return capsule

    def continuity_score(self, cp):
        """% de campos criticos restaurados (goal/quest/agent/next/blockers/decisions/skill/pending)."""
        fields = {
            "goal": cp.get("goal"),
            "quest": cp.get("quest_id"),
            "agent": cp.get("agent"),
            "next_action": cp.get("next_action"),
            "blockers": cp.get("blockers"),
            "decisions": cp.get("critical_memory_ids"),
            "skill": cp.get("active_skill"),
            "pending": cp.get("pending_tasks"),
        }
        ok = 0
        for k, v in fields.items():
            if isinstance(v, (list, dict)):
                if v:
                    ok += 1
            elif v not in (None, ""):
                ok += 1
        return round(ok / len(fields), 2)

    def salience(self, content, type_name, score, tags, evidence):
        """Senal determinista de consolidacion: que merece guardarse (no confundir con verdad)."""
        s = 0.0
        s += {"decision": 2.0, "verdict": 3.0, "bugfix": 2.0, "pattern": 1.5,
              "preference": 1.0, "recommendation": 1.5, "action": 1.0}.get(type_name, 0.5)
        s += min(2.0, float(score or 0) / 5.0 * 2.0)
        if evidence:
            s += 2.0
        low = ["voy a revisar", "vamos a", "puedes", "podrias", "hola", "ok", "gracias",
               "dime", "revisa esto", "prueba esto", "dale", "ya quedo"]
        c = (content or "").lower()
        if any(w in c for w in low):
            s -= 1.5
        tags_s = " ".join(tags or []).lower()
        for k in ["schema", "arquitectura", "architecture", "seguridad", "security",
                  "constraint", "decision", "bug"]:
            if k in tags_s:
                s += 1.0
        return max(0.0, min(8.0, s))

    def consolidate_recent(self, hours=24):
        """PRE-COMPACTION: clasifica la experiencia reciente (working/episodic/semantic/procedural/noise)."""
        cutoff = (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
                  - datetime.timedelta(hours=hours)).strftime("%Y-%m-%d %H:%M:%S")
        rows = [dict(r) for r in self._conn.execute(
            "SELECT * FROM observations WHERE archived=0 AND created_at >= ?", (cutoff,))]
        cls = {"working": 0, "episodic": 0, "semantic": 0, "procedural": 0, "noise": 0, "classified": len(rows)}
        for r in rows:
            tags = json.loads(r.get("tags") or "[]")
            sal = self.salience(r.get("content", ""), r.get("type", "discovery"),
                                r.get("score", 0), tags, r.get("evidence"))
            kind = r.get("memory_kind", "episodic")
            if sal >= 4.0:
                new_kind = "procedural" if (kind == "procedural" or sal >= 5.5) else "semantic"
                self._conn.execute(
                    "UPDATE observations SET memory_kind=?, "
                    "storage_strength=min(0.9, storage_strength+0.1) WHERE id=?",
                    (new_kind, r["id"]))
                cls[new_kind] += 1
            elif sal <= 1.0:
                self._conn.execute(
                    "UPDATE observations SET archived=1, state='archived' WHERE id=?", (r["id"],))
                cls["noise"] += 1
            elif kind == "episodic":
                cls["episodic"] += 1
            else:
                cls["working"] += 1
        self._conn.commit()
        return cls

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
        return True

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
        if data.get("upsert"):
            obs_id = brain.save_observation_upsert(
                data.get("agent", "atlas"), data.get("topic_key", "atlas/general"),
                data.get("type", "discovery"), data.get("content", ""), data.get("quest_id"),
                data.get("score", 0), data.get("tags"), data.get("memory_kind"),
                data.get("confidence"), data.get("volatility"), data.get("evidence"), data.get("source"))
        else:
            obs_id = brain.save_observation(
                data.get("agent", "atlas"), data.get("topic_key", "atlas/general"),
                data.get("type", "discovery"), data.get("content", ""), data.get("quest_id"),
                data.get("score", 0), data.get("tags"), data.get("memory_kind"),
                data.get("confidence"), data.get("volatility"), data.get("evidence"), data.get("source"))
        print(json.dumps({"id": obs_id, "status": "saved"}))

    elif command == "recall":
        query = sys.argv[3]
        agent = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else None
        limit = int(sys.argv[5]) if len(sys.argv) > 5 else 5
        tag = sys.argv[6] if len(sys.argv) > 6 and sys.argv[6] != "-" else None
        print(json.dumps(brain.recall(query, agent=agent, limit=limit, tag=tag), ensure_ascii=False))

    elif command == "reinforce":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        ok = brain.reinforce(int(data.get("id", 0)), evidence=data.get("evidence"),
                             success=bool(data.get("success", True)))
        print(json.dumps({"ok": ok, "id": data.get("id")}))

    elif command == "verify":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        ok = brain.verify(int(data.get("id", 0)), data.get("verdict", "PASS"),
                          evidence=data.get("evidence"))
        print(json.dumps({"ok": ok, "id": data.get("id"), "verdict": data.get("verdict")}))

    elif command == "reconsolidate":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        ok = brain.reconsolidate(int(data.get("id", 0)), data.get("content", ""),
                                 evidence=data.get("evidence"))
        print(json.dumps({"ok": ok, "id": data.get("id")}))

    elif command == "skill":
        action = sys.argv[3]
        if action == "register":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            brain.skill_register(data.get("skill_id", ""), data.get("version", "1.0"),
                                 data.get("triggers"), data.get("anti_triggers"))
            print(json.dumps({"ok": True, "skill": data.get("skill_id")}))
        elif action == "exec":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            res = brain.skill_record_execution(
                data.get("skill_id", ""), data.get("version", "1.0"), data.get("agent"),
                data.get("quest_id"), data.get("trigger"), bool(data.get("success", True)),
                data.get("verdict"), data.get("evidence"), data.get("error"),
                data.get("tokens_in", 0), data.get("tokens_out", 0),
                data.get("tool_calls", 0), data.get("model"), data.get("provider"))
            print(json.dumps(res, ensure_ascii=False))
        elif action == "link":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            brain.skill_links(int(data.get("memory_id", 0)), data.get("skill_id", ""),
                              data.get("relation", "supports"), bool(data.get("success", True)))
            print(json.dumps({"ok": True}))
        elif action == "status":
            skill_id = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else None
            print(json.dumps(brain.skill_status(skill_id), ensure_ascii=False))
        elif action == "executions":
            rows = [dict(r) for r in brain._conn.execute(
                "SELECT * FROM skill_executions ORDER BY id DESC LIMIT 20")]
            print(json.dumps(rows, ensure_ascii=False))
        else:
            print(json.dumps({"error": "skill action desconocida"}))

    elif command == "route":
        query = sys.argv[3]
        risk = sys.argv[4] if len(sys.argv) > 4 else None
        print(json.dumps(brain.route(query, risk), ensure_ascii=False))

    elif command == "reviews":
        rows = brain.list_due_reviews(int(sys.argv[3]) if len(sys.argv) > 3 else 20)
        print(json.dumps(rows, ensure_ascii=False))

    elif command == "checkpoint":
        action = sys.argv[3]
        if action == "create":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            print(json.dumps(brain.create_checkpoint(data), ensure_ascii=False))
        elif action == "get":
            cp = brain.get_checkpoint(int(sys.argv[4]))
            print(json.dumps(cp, ensure_ascii=False))
        elif action == "list":
            lim = int(sys.argv[4]) if len(sys.argv) > 4 else 10
            print(json.dumps(brain.list_checkpoints(lim), ensure_ascii=False))
        else:
            print(json.dumps({"error": "checkpoint action desconocida"}))

    elif command == "capsule":
        cp_id = int(sys.argv[3])
        cp = brain.get_checkpoint(cp_id)
        if not cp:
            print(json.dumps({"error": "checkpoint no existe"}))
        else:
            print(json.dumps({"id": cp_id, "capsule": brain.build_recovery_capsule(cp),
                              "continuity_score": brain.continuity_score(cp)}, ensure_ascii=False))

    elif command == "consolidate-recent":
        hours = int(sys.argv[3]) if len(sys.argv) > 3 else 24
        print(json.dumps(brain.consolidate_recent(hours), ensure_ascii=False))

    elif command == "continuity":
        cp_id = int(sys.argv[3])
        cp = brain.get_checkpoint(cp_id)
        if not cp:
            print(json.dumps({"error": "checkpoint no existe"}))
        else:
            print(json.dumps({"id": cp_id, "continuity_score": brain.continuity_score(cp)},
                             ensure_ascii=False))

    elif command == "aquest":
        action = sys.argv[3]
        if action == "create":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            print(json.dumps({"id": brain.quest_create(data.get("id", "quest"), data.get("description", ""), data.get("mode", "balanced"))}))
        elif action == "get":
            print(json.dumps(brain.quest_get(sys.argv[4]), ensure_ascii=False))
        elif action == "list":
            print(json.dumps(brain.quest_list(int(sys.argv[4]) if len(sys.argv) > 4 else 10), ensure_ascii=False))
        elif action == "progress":
            print(json.dumps(brain.quest_progress(sys.argv[4]), ensure_ascii=False))
        elif action == "update":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            qid = data.pop("id", None)
            if qid:
                brain.quest_update(qid, **data)
                print(json.dumps({"ok": True, "id": qid}))
            else:
                print(json.dumps({"error": "falta id"}))
        else:
            print(json.dumps({"error": "quest action desconocida"}))

    elif command == "atask":
        action = sys.argv[3]
        if action == "create":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            tid = brain.task_create(data.get("quest_id", ""), data.get("task_id", "T"),
                                    data.get("description", ""), data.get("agent", "atlas"),
                                    data.get("dependencies"), data.get("acceptance", ""))
            print(json.dumps({"id": tid}))
        elif action == "list":
            qid = sys.argv[4] if len(sys.argv) > 4 else None
            st = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] != "-" else None
            print(json.dumps(brain.task_list(qid, st), ensure_ascii=False))
        elif action == "ready":
            print(json.dumps(brain.task_ready(sys.argv[4]), ensure_ascii=False))
        elif action == "update":
            data = _read_json_arg(sys.argv[4] if len(sys.argv) > 4 else "-")
            tid = int(data.pop("id", 0))
            if tid:
                brain.task_update(tid, **data)
                print(json.dumps({"ok": True, "id": tid}))
            else:
                print(json.dumps({"error": "falta id"}))
        elif action == "progress":
            print(json.dumps(brain.quest_progress(sys.argv[4]), ensure_ascii=False))
        else:
            print(json.dumps({"error": "task action desconocida"}))

    elif command == "get":
        obs_id = int(sys.argv[3])
        row = brain.get_observation(obs_id)
        print(json.dumps(dict(row) if row else {"error": "no encontrada"}, ensure_ascii=False))

    elif command == "update":
        data = _read_json_arg(sys.argv[3] if len(sys.argv) > 3 else "-")
        obs_id = int(data.get("id", 0))
        updated = brain.update_observation(
            obs_id, content=data.get("content"), topic_key=data.get("topic_key"))
        print(json.dumps({"id": obs_id, "updated": updated}, ensure_ascii=False))

    elif command == "revisions":
        obs_id = int(sys.argv[3])
        revs = brain.list_revisions(obs_id)
        print(json.dumps(revs, ensure_ascii=False))

    elif command == "compact":
        days = int(sys.argv[3]) if len(sys.argv) > 3 else 30
        print(json.dumps(brain.compact(days), ensure_ascii=False))

    elif command == "search":
        query = sys.argv[3]
        agent = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else None
        limit = int(sys.argv[5]) if len(sys.argv) > 5 else 20
        tag = sys.argv[6] if len(sys.argv) > 6 and sys.argv[6] != "-" else None
        print(json.dumps(brain.search(query, agent=agent, limit=limit, tag=tag), ensure_ascii=False))

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
