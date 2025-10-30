import { createCounter, delCounter, fetchCounterSessions, updateCounter } from "../db/counters.js";
import { fetchSessions, storeSession } from "../db/sessions.js";
import { Counter } from "../models/counter.model.js";

export function getCounters(req, res) {
  res.json(fetchCounterSessions());
}
export function postCounter(req, res) {
  const counterId = `counter-${Date.now()}`
  const dateCreated = new Date().toISOString();
  const c = new Counter("", dateCreated, "inactive", counterId)
  createCounter(c);
  res.json({ message: "Counter created", counterId });
}

export function putCounter(req, res) {
  const sessionId = req.params.id;
  const counters = fetchCounterSessions();
  if (!counters || !counters[sessionId]) return res.status(404).json({ error: "Counter not found" });

  updateCounter(sessionId, req.body.counter || {});
  res.json({ message: "Counter updated", sessionId });
}

export function deleteCounter(req, res) {
  const sessionId = req.params.id;
  const counters = fetchCounterSessions();
  if (!counters || !counters[sessionId]) return res.status(404).json({ error: "Counter not found" });

  delCounter(sessionId);
  res.json({ message: "Counter deleted", sessionId });
}

function getDeviceId(req) {
  return req.sessionID || null;
}

export async function getCounterId(req, res) {
  const id = req.params.id;
  const counters = fetchCounterSessions();
  if (!counters || !counters[id]) return res.status(404).json({ error: "Invalid key" });

  const counter = counters[id];

  const sid = getDeviceId(req);

  if (req.session) {
    req.session.userType = "counter";
    try {
      await new Promise((resolve, reject) => {
        req.session.save((err) => {
          if (err) return reject(err);
          resolve();
        });
      });
    } catch (e) {
      console.error("Error saving express session:", e);
    }
  }

  counter.sessionId = sid;
  counter.status = "Active";
  updateCounter(id, counter);

  const devices = fetchSessions();
  const device = devices.get(sid) || req.session || { deviceId: req.session?.deviceId };
  if (sid) storeSession(sid, device);

  res.json(counter);
}
  