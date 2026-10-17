import { Hono } from "hono";
import { ipRestriction } from "hono/ip-restriction";
import { getConnInfo } from "@hono/cloudflare-workers";

const app = new Hono<{ Bindings: CloudflareBindings }>();

// https://api.github.com/meta -> "hooks"
const githubHookIPs = [
  "9.234.106.48/28",
  "9.234.98.160/28",
  "9.234.98.176/28",
  "192.30.252.0/22",
  "185.199.108.0/22",
  "140.82.112.0/20",
  "143.55.64.0/20",
  "2a0a:a440::/29",
  "2606:50c0::/32",
];
const localIPs = ["127.0.0.1/32", "::1/128"];

const forwardHeaders = [
  "Content-Type",
  "User-Agent",
  "X-GitHub-Delivery",
  "X-GitHub-Event",
  "X-GitHub-Hook-ID",
  "X-GitHub-Hook-Installation-Target-ID",
  "X-GitHub-Hook-Installation-Target-Type",
  "X-Hub-Signature-256",
];

// DEV is only set in .dev.vars, which `wrangler dev` loads and deploys ignore.
app.use("*", (c, next) =>
  ipRestriction(getConnInfo, {
    allowList: c.env.DEV === "true" ? [...githubHookIPs, ...localIPs] : githubHookIPs,
  })(c, next),
);

async function verifySignature(secret: string, body: string, header?: string) {
  if (!header?.startsWith("sha256=")) return false;
  try {
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"],
    );
    // subtle.verify compares in constant time
    return await crypto.subtle.verify(
      "HMAC",
      key,
      Uint8Array.fromHex(header.slice(7)),
      new TextEncoder().encode(body),
    );
  } catch {
    return false; // malformed hex
  }
}

app.post("/api/webhook", async (c) => {
  const rawPayload = await c.req.text();

  const valid = await verifySignature(
    c.env.GITHUB_WEBHOOK_SECRET,
    rawPayload,
    c.req.header("X-Hub-Signature-256"),
  );
  if (!valid) return c.json({ error: "invalid signature" }, 401);

  let payload: { ref?: string } | null;
  try {
    payload = JSON.parse(rawPayload);
  } catch {
    return c.json({ error: "invalid input" }, 400);
  }

  if (payload?.ref !== "refs/heads/main") return c.text("ignoring");

  const headers = new Headers();
  for (const name of forwardHeaders) {
    const value = c.req.header(name);
    if (value) headers.set(name, value);
  }

  try {
    const response = await c.env.VPC_SERVICE.fetch(c.env.ARGOCD_WEBHOOK_URL, {
      method: "POST",
      headers,
      body: rawPayload,
    });
    console.log({ relay_status_code: response.status, relay_url: c.env.ARGOCD_WEBHOOK_URL });
    return response;
  } catch (err) {
    console.error({ relay_error: String(err), relay_url: c.env.ARGOCD_WEBHOOK_URL });
    return c.json({ error: "upstream unavailable" }, 502);
  }
});

export default app;
