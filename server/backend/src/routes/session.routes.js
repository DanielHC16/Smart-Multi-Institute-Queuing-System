import express from "express";
import { getCurrentSession, getSessions } from "../controllers/session.controller.js";

const sessionRoutes = express.Router();

sessionRoutes.get("/devices", getSessions);
sessionRoutes.get("/session", getCurrentSession);

export default sessionRoutes;