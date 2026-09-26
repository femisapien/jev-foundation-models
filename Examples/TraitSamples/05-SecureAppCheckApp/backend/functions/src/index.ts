import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

/**
 * 2nd Generation Cloud Function acting as a secure gateway for TypeSafe AI Jev decision models.
 *
 * Verifies Apple App Attest / DeviceCheck cryptographically via Firebase App Check tokens,
 * preventing API key exfiltration and unauthenticated automated scraping.
 */
export const jevProxy = onRequest(
  {
    cors: true,
    invoker: "public",
    secrets: ["TYPESAFE_API_KEY"],
  },
  async (req, res) => {
    // Only accept HTTP POST requests
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed. Expected POST." });
      return;
    }

    // 1. Verify App Check Token from Header
    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      console.warn("Unauthorized: Missing X-Firebase-AppCheck header.");
      res.status(401).json({
        error: "Unauthorized",
        message: "Missing required X-Firebase-AppCheck header."
      });
      return;
    }

    try {
      if (process.env.FUNCTIONS_EMULATOR === "true") {
        // In local emulator mode, accept debug tokens without strict Apple App Attest signature validation
        console.log(`[Emulator] Validating App Check token: ${appCheckToken.substring(0, 10)}...`);
      } else {
        // Production: Cryptographically verify token with Firebase App Check service
        const appCheckClaims = await admin.appCheck().verifyToken(appCheckToken);
        console.log(`[Production] Verified App Check claims for app ID: ${appCheckClaims.appId}`);
      }
    } catch (err: any) {
      console.error("App Check token verification failed:", err);
      res.status(401).json({
        error: "Unauthorized",
        message: "Invalid or expired App Check token."
      });
      return;
    }

    // 2. Resolve Upstream API Key (from Secret Manager or Environment)
    const apiKey = process.env.TYPESAFE_API_KEY;

    // 3. Fallback to offline / mock proxy if API key is not configured
    if (!apiKey || apiKey === "mock" || apiKey === "mock-key") {
      console.log("[Proxy] Running in simulated mock mode (no TYPESAFE_API_KEY secret found).");
      const startTime = Date.now();
      
      const incomingBody = req.body || {};
      const questions = incomingBody.questions || {};
      const answers: Record<string, any> = {};

      for (const key of Object.keys(questions)) {
        const q = questions[key];
        if (q.type === "noul") {
          answers[key] = { type: "noul", noul: 0.96, confidence: 0.98 };
        } else if (q.type === "choice") {
          const firstOption = q.criteria ? Object.keys(q.criteria)[0] : "default";
          answers[key] = {
            type: "choice",
            choice: firstOption,
            confidence: 0.95,
            probabilities: { [firstOption]: 0.95 }
          };
        } else if (q.type === "score") {
          answers[key] = { type: "score", score: 3.0, confidence: 0.90 };
        }
      }

      const elapsedMs = Date.now() - startTime;
      res.setHeader("x-envoy-upstream-service-time", `${elapsedMs}`);
      res.status(200).json({
        model: incomingBody.model || "jev-latest",
        answers,
        usage: { input_tokens: 32, output_tokens: 4 },
        serverDurationMs: elapsedMs
      });
      return;
    }

    // 4. Dispatch to upstream TypeSafe AI API
    const upstreamEndpoint = process.env.TYPESAFE_ENDPOINT || "https://api.typesafe.ai/v1/systemone";

    try {
      const upstreamResponse = await fetch(upstreamEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify(req.body),
      });

      const responseBody = await upstreamResponse.text();

      // Pass through status code and timing headers
      const serviceTime = upstreamResponse.headers.get("x-envoy-upstream-service-time");
      if (serviceTime) {
        res.setHeader("x-envoy-upstream-service-time", serviceTime);
      }

      res.status(upstreamResponse.status);
      res.setHeader("Content-Type", upstreamResponse.headers.get("Content-Type") || "application/json");
      res.send(responseBody);
    } catch (networkError: any) {
      console.error("Error communicating with upstream Jev API:", networkError);
      res.status(502).json({
        error: "Bad Gateway",
        message: "Upstream decision service temporarily unavailable."
      });
    }
  }
);
