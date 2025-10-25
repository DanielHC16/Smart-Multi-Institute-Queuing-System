import express from "express";
import { deleteCounter, getCounterId, getCounters, getCurrentSession, getIsServer, getSessions, postCounter, putCounter } from "../controllers/session.controller.js"; 

const sessionRoutes = express.Router();

sessionRoutes.get("/counters", getCounters);
sessionRoutes.post("/counters", express.json(), postCounter);
sessionRoutes.put("/counters/:id", express.json(), putCounter);
sessionRoutes.delete("/counters/:id", deleteCounter);
sessionRoutes.get("/counters/:id", getCounterId);
sessionRoutes.get("/server/check", getIsServer);

// Should be disabled in production since it exposes all session info
sessionRoutes.get("/devices", getSessions);
sessionRoutes.get("/session", getCurrentSession);

export default sessionRoutes;