import fs from "fs";
import path from "path";
import session from "express-session";
import SQLiteStoreFactory from "connect-sqlite3";

const SQLiteStore = SQLiteStoreFactory(session);
const isProd = process.env.NODE_ENV === "production";

const dataDir = path.join(process.cwd(), "data");
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

export const sessionMiddleware = session({
  name: "connect.sid",
  store: new SQLiteStore({
    db: "sessions.sqlite",
    dir: dataDir,
    ttl: 86400,
  }),
  secret: process.env.SESSION_SECRET || "TODO",
  resave: false,
  saveUninitialized: false,
  cookie: {
    maxAge: 86400000,
    httpOnly: true,
    sameSite: isProd ? "none" : "lax",
    secure: isProd,
  },
});

export function recordSession(req, res, next) {
  if (!req.session) return next();

  if (!req.session.deviceId) {
    req.session.deviceId = `device-${Date.now()}-${Math.random().toString(36).slice(2,8)}`;
    req.session.dateCreated = new Date().toISOString();

    req.session.save((err) => {
      if (err) console.error("Error saving session:", err);
      else console.warn("Saved new session", req.sessionID);
      next();
    });
    return;
  }
  
  next();
}