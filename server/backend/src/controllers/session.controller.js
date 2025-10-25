import { createCounter, delCounter, fetchCounterSessions, updateCounter } from "../db/counters.js";
import { fetchSessions, storeSession } from "../db/sessions.js";


export async function getSessions(req, res) {
    const obj = Object.fromEntries(fetchSessions());
    res.json(obj);
}   
export async function getCurrentSession(req, res) {
  res.json(fetchSessions().get(req.sessionID))
};
export function getCounters(req, res) {
  res.json(Object.fromEntries(fetchCounterSessions()));
}
export function postCounter(req, res) {
  const { sessionId, counter } = req.body;
  if (!sessionId) return res.status(400).json({ error: "sessionId required" });

  counter.mac = ""
  createCounter(sessionId, counter || {});
  res.json({ message: "Counter created", sessionId });
}

export function putCounter(req, res) {
  const sessionId = req.params.id;
  const counters = fetchCounterSessions()
  if (!counters.has(sessionId))
    return res.status(404).json({ error: "Counter not found" });

  updateCounter(sessionId, req.body.counter || {});
  res.json({ message: "Counter updated", sessionId });
}

export function deleteCounter(req, res) {
  const sessionId = req.params.id;
  const counters = fetchCounterSessions()
  if (!counters.has(sessionId))
    return res.status(404).json({ error: "Counter not found" });

  delCounter(sessionId);
  res.json({ message: "Counter deleted", sessionId });
}
export async function getCounterId(req, res) {
  const id = req.params.id;
  const counters = fetchCounterSessions()
  if (!counters.has(id)) return res.status(404).json({ error: "Invalid key" });

  const counter = counters.get(id)
  const devices = fetchSessions()
  const mac = await getDeviceMac(req)
  const device = devices.get(mac)
  device.userType = "counter"
  counter.mac = mac
  counter.status = "Active"
  updateCounter(id, counter)
  storeSession(mac, device)
  
  res.json(counters.get(id));
}
  
export async function getIsServer(req, res) {
  const serverIp = req.socket.localAddress?.replace("::ffff:", "") || "unknown";
  const clientIp = req.headers["x-forwarded-for"]?.split(",")[0] ||
  req.socket.remoteAddress?.replace("::ffff:", "") ||
  "unknown";
  console.warn("Server IP:", serverIp, "Client IP:", clientIp);
  res.json({ isServer: serverIp === clientIp });
}