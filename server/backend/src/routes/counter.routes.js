import express from "express";
import { deleteCounter, getCounterId, getCounters, postCounter, putCounter } from "../controllers/counter.controller.js"; 

const counterRoutes = express.Router();

counterRoutes.get("/counters", getCounters);
counterRoutes.post("/counters", express.json(), postCounter);
counterRoutes.put("/counters/:id", express.json(), putCounter);
counterRoutes.delete("/counters/:id", deleteCounter);
counterRoutes.get("/counters/:id", getCounterId);

export default counterRoutes;