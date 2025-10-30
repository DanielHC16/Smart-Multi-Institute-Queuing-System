import { fetchSessions } from "../db/sessions.js";

export async function getSessions(req, res) {
    const obj = Object.fromEntries(fetchSessions());
    res.json(obj);
}   
export async function getCurrentSession(req, res) {
  res.json(fetchSessions().get(req.sessionID))
};