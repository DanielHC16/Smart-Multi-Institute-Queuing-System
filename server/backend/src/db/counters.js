

const counters = new Map(); 

export function fetchCounterSessions() {
    return counters
}
export function createCounter(sessionId, counter) {
    counters.set(sessionId, counter)
}
export function updateCounter(sessionId, counter) {
    counters.set(sessionId, counter)
}
export function delCounter(sessionId) {
    counters.delete(sessionId)
}