// src/routes/index.js
import { Router } from 'express';
import QRCode from 'qrcode';
import sessionRoutes from './session.routes.js';

const router = Router();

// Example QR Code generator
router.get("/qr", async (req, res) => {
  try {
    const url = "http://localhost:4000/test.html";
    const qrDataUrl = await QRCode.toDataURL(url);
    res.json({ qr: qrDataUrl });
  } catch (err) {
    console.error("QR Error:", err);
    res.status(500).json({ error: "Failed to generate QR" });
  }
});

router.use(sessionRoutes)
// Applicant chatbot route
// router.use("/chatbot", applicantRoutes);

export default router;
