import express from "express";
import { getIsServer } from "../controllers/server.controller.js";

const serverRoutes = express.Router();

serverRoutes.get("/server/check", getIsServer);

export default serverRoutes;