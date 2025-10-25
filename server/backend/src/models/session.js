
export class Session {
  constructor(ip, mac, id, userType = "applicant") {
    this.dateCreated = new Date().toLocaleString();
    this.userType = userType;
    this.sessionId = id;
    this.ip = ip;
    this.mac = mac;
  }
}