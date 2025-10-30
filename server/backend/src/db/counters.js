import { Counter } from "../models/counter.model.js";

const counters = new Map();

export function fetchCounterSessions() {
    const out = {};
    for (const [id, c] of counters.entries()) out[id] = c;
    return out;
}

export function createCounter(counter) {
    if (!counter || !counter.counterId) return;
    counters.set(counter.counterId, counter);
}

export function updateCounter(id, counterObj) {
    if (!id || !counterObj) return;
    counters.set(id, counterObj);
}

export function delCounter(counterId) {
    if (!counterId) return;
    counters.delete(counterId);
}