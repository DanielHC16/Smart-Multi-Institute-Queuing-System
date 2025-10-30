
export async function getIsServer(req, res) {
  const serverIp = req.socket.localAddress?.replace("::ffff:", "") || "unknown";
  const clientIp = req.headers["x-forwarded-for"]?.split(",")[0] ||
  req.socket.remoteAddress?.replace("::ffff:", "") ||
  "unknown";
  console.warn("Server IP:", serverIp, "Client IP:", clientIp);
  res.json({ isServer: serverIp === clientIp });
}