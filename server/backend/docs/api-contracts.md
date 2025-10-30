# Smart Queue API Contract

## Overview

Central API for managing applicants, counters, devices, and sessions.

## Base URL

```
http://192.168.1.6:4000/api
```

## Session Management

The API uses cookie-based session management with the following behavior:

- **One session per device**: Each device/browser maintains only one session
- **Device fingerprinting**: Sessions are identified by a combination of:
  - Normalized IP address (localhost and LAN IPs treated as `local-machine`)
  - User agent string
- **Session persistence**: Sessions are stored in SQLite and persist for 24 hours (86400 seconds)
- **Automatic deduplication**: If a session already exists for a device, new session creation is prevented

### Session Headers

All requests automatically include session cookies:

**Headers**
```
Cookie: connect.sid=<sessionId>
```

---

## Counters

### **POST /counters**

Add a new counter to the database session management. Counter ID is automatically generated.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Request Body**
```
None required
```

**Response**

```json
200: { "message": "Counter created", "counterId": "counter-1729950000000" }
```

**Notes**:
- Counter ID is auto-generated with format: `counter-<timestamp>`
- Counter is created with status "inactive"
- No request body needed

---

### **PUT /counters/:id**

Update an existing counter.

**Headers**
```
Cookie: connect.sid=<sessionId>
Content-Type: application/json
```

**Request Body**
```json
{
  "counter": {
    "status": "active" | "inactive",
    "counterId": "<counterId>",
    "sessionId": "<sessionId>",
    "dateCreated": "<ISO-timestamp>"
  }
}
```

**Response**

```json
200: { "message": "Counter updated", "sessionId": "<sessionId>" }
404: { "error": "Counter not found" }
```

**Notes**:
- The `counter` object in request body can contain any counter properties to update
- Returns the sessionId (not counterId) of the updated counter

---

### **DELETE /counters/:id**

Delete a counter by session ID.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**URL Parameters**
- `id`: Session ID of the counter to delete

**Response**

```json
200: { "message": "Counter deleted", "sessionId": "<sessionId>" }
404: { "error": "Counter not found" }
```

---

### **GET /counters**

Retrieve all counters.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Response**

```json
200: {
  "<sessionId>": {
    "sessionId": "<sessionId>",
    "dateCreated": "2025-10-27T07:42:54.430Z",
    "status": "active",
    "counterId": "counter-1729950000000"
  },
  ...
}
```

**Notes**:
- Returns an object with session IDs as keys
- Each counter includes sessionId, dateCreated, status, and counterId

---

### **GET /counters/:id**

Retrieve and activate a specific counter. This endpoint also sets the session's userType to "counter".

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**URL Parameters**
- `id`: Session ID (not counterId) of the counter

**Response**

```json
200: {
  "sessionId": "<sessionId>",
  "dateCreated": "2025-10-27T07:42:54.430Z",
  "status": "Active",
  "counterId": "counter-1729950000000"
}
404: { "error": "Invalid key" }
```

**Notes**:
- This endpoint activates the counter by setting status to "Active"
- Sets the session's `userType` to "counter"
- Updates the counter's sessionId to the current session
- Stores the session in the database

---

## Devices

### **GET /devices**

Retrieve all devices (sessions) connected to the network.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Response**

```json
200: {
  "<sessionId>": {
    "cookie": {
      "originalMaxAge": 86400000,
      "expires": "<dateTime>",
      "secure": false,
      "httpOnly": true,
      "path": "/",
      "sameSite": "lax"
    },
    "deviceId": "local-machine-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...",
    "dateCreated": "2025-10-27T07:42:54.430Z",
    "ip": "192.168.1.6"
  },
  ...
}
```

**Device ID Format**: `<normalized-ip>-<user-agent>`
- `normalized-ip`: Either `local-machine` (for localhost/LAN) or the actual IP
- `user-agent`: Full browser user agent string

**Notes**:
- Each unique browser/device will have only one session
- IP addresses like `127.0.0.1`, `::1`, `192.168.x.x`, `10.x.x.x` are normalized to `local-machine`
- IPv4-mapped IPv6 addresses (`::ffff:x.x.x.x`) are converted to IPv4 format

---

## Sessions

### **GET /session**

Retrieve info about the current client session.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Response**

```json
200: {
  "cookie": {
    "originalMaxAge": 86400000,
    "expires": "2025-10-28T07:42:54.430Z",
    "secure": false,
    "httpOnly": true,
    "path": "/",
    "sameSite": "lax"
  },
  "deviceId": "local-machine-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...",
  "dateCreated": "2025-10-27T07:42:54.430Z",
  "ip": "192.168.1.6"
}
```

**Response Fields**:
- `cookie`: Session cookie configuration and expiration
- `deviceId`: Unique device fingerprint (format: `<normalized-ip>-<user-agent>`)
- `dateCreated`: ISO timestamp when the session was first created
- `ip`: The client's IP address (normalized)

**Notes**:
- This endpoint requires an existing session (cookie must be present)
- If no session exists, a new one will be created on the first navigation request
- Only one session per device is maintained

---

## Server

### **GET /server/check**

Check if the client is the server (same IP address as the server).

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Response**

```json
200: { "isServer": true }
200: { "isServer": false }
```

**Notes**:
- Compares the client's IP address with the server's IP address
- Returns `true` if they match (client is accessing from the server machine)
- Returns `false` otherwise

---

## QR Code

### **GET /qr**

Generate a QR code for client connection.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Request Body**
```
None required
```

**Response**

```json
200: {
  "qrImage": "<base64-encoded-QR-code-image>"
}
500: { "error": "<error-message>" }
```

**Notes**:
- Generates a QR code pointing to `http://localhost:4000/api/qr/connect`
- Returns the QR code as a base64-encoded image
- Used for mobile device authentication

---

### **POST /qr/connect**

Connect a client after scanning the QR code.

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Request Body**
```
None required (client info extracted from request)
```

**Response**

```json
200: {
  "message": "Client added to pending verification",
  "clientInfo": {
    "ip": "<client-ip>",
    "timestamp": "<ISO-timestamp>",
    "status": "pending"
  }
}
500: { "error": "<error-message>" }
```

**Notes**:
- Automatically captures client IP from request
- Adds client to pending verification list
- Status is set to "pending" by default

---

### **GET /qr/pending**

Get list of pending client connections (debug endpoint).

**Headers**
```
Cookie: connect.sid=<sessionId>
```

**Request Body**
```
None required
```

**Response**

```json
200: [
  {
    "ip": "<client-ip>",
    "timestamp": "<ISO-timestamp>",
    "status": "pending"
  },
  ...
]
```

**Notes**:
- Debug endpoint to view pending QR code connections
- Shows all clients waiting for verification