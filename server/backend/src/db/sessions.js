
import Database from "better-sqlite3";
import fs from "fs";
import path from "path";

const dataDir = path.join(process.cwd(), "data");
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const db = new Database(path.join(dataDir, "sessions.sqlite"));

db.prepare(`CREATE TABLE IF NOT EXISTS sessions (sid TEXT PRIMARY KEY, expired INTEGER, sess TEXT)`).run();

const DEFAULT_TTL_SECONDS = parseInt(process.env.SESSION_TTL || "86400", 10);

export function fetchSessions() {
  const rows = db.prepare("SELECT sid AS id, sess AS data FROM sessions").all();
  return new Map(
    rows.map((r) => {
      try {
        return [r.id, JSON.parse(r.data)];
      } catch (e) {
        return [r.id, r.data];
      }
    })
  );
}

export function storeSession(sessionID, session) {
  const ttlMs = DEFAULT_TTL_SECONDS * 1000;
  const expiry = Date.now() + ttlMs;


  db.prepare(`INSERT OR REPLACE INTO sessions (sid, sess, expired) VALUES (?, ?, ?)`).run(
    sessionID,
    JSON.stringify(session),
    expiry
  );
}

export function findSessionByDeviceId(deviceId) {
  const rows = db.prepare("SELECT sid AS id, sess AS data FROM sessions").all();
  for (const row of rows) {
    try {
      const sessionData = JSON.parse(row.data);
      if (sessionData.deviceId === deviceId) {
        return { id: row.id, data: sessionData };
      }
    } catch (e) {
      // Skip invalid JSON
    }
  }
  return null;
}

export function findSessionsByUserAgent(userAgent) {
  const rows = db.prepare("SELECT sid AS id, sess AS data FROM sessions").all();
  const matches = [];
  for (const row of rows) {
    try {
      const sessionData = JSON.parse(row.data);
      // Check if deviceId contains the user agent (since deviceId is "ip-useragent")
      if (sessionData.deviceId && sessionData.deviceId.includes(userAgent)) {
        matches.push({ id: row.id, data: sessionData });
      }
    } catch (e) {
      // Skip invalid JSON
    }
  }
  return matches;
}

export function deleteSession(sessionID) {
  db.prepare("DELETE FROM sessions WHERE sid = ?").run(sessionID);
}
