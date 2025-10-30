export class Counter {
  constructor(sessionId, createdAt, status, counterId) {
    this.sessionId = sessionId;
    this.createdAt = createdAt;
    this.status = status;
    this.counterId = counterId;
  }
}
