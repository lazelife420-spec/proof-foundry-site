// Proof Foundry — /downloads/* R2 streaming function.
//
// Serves release artifacts from the account-local R2 bucket `proof-foundry-downloads`
// (binding: DOWNLOADS). This exists because the historical downloads origin
// (downloads.theprooffoundry.com) is backed by a bucket in a different Cloudflare
// account that this project's deploy identity cannot write to, and Cloudflare Pages
// caps static assets at 25 MiB — below real release artifacts.
//
// Scope guard: ONLY the `cache-vault/` key prefix is exposed here. Other keys in the
// bucket are not public and must not become public by accident. Versioned artifact
// keys are immutable; responses are marked immutable so the CDN can cache them.

const ALLOWED_PREFIXES = ["cache-vault/"];

const EXTENSION_TYPES = {
  ".zip": "application/zip",
  ".json": "application/json",
  ".md": "text/markdown; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
};

function contentTypeFor(key) {
  const dot = key.lastIndexOf(".");
  if (dot === -1) return "application/octet-stream";
  const ext = key.slice(dot).toLowerCase();
  return EXTENSION_TYPES[ext] || "application/octet-stream";
}

function dispositionFor(key) {
  if (key.toLowerCase().endsWith(".zip")) {
    const name = key.split("/").pop();
    return `attachment; filename="${name}"`;
  }
  return "inline";
}

async function serve(context, headOnly) {
  const { env, params } = context;
  const segments = Array.isArray(params.path) ? params.path : [params.path];
  const key = segments.map(decodeURIComponent).join("/");

  // TEMPORARY diagnostics — remove after binding verification.
  if (key === "_diag") {
    const bucket = env.DOWNLOADS;
    const diag = { bindingPresent: Boolean(bucket), list: null, head: null, error: null };
    try {
      const l = await bucket.list({ prefix: "cache-vault/", limit: 10 });
      diag.list = l.objects.map((o) => ({ key: o.key, size: o.size }));
    } catch (e) { diag.error = String(e); }
    try {
      const h = await bucket.head("cache-vault/v0.2.3-rc1/SHA256SUMS.txt");
      diag.head = h ? { size: h.size } : null;
    } catch (e) { diag.error = String(e); }
    return new Response(JSON.stringify(diag, null, 2), { status: 200, headers: { "Content-Type": "application/json" } });
  }

  if (!ALLOWED_PREFIXES.some((prefix) => key.startsWith(prefix) && key !== prefix && !key.startsWith(prefix + ".."))) {
    return new Response("Not found", { status: 404 });
  }

  const bucket = env.DOWNLOADS;
  if (!bucket) {
    return new Response("Downloads binding unavailable", { status: 503 });
  }

  if (headOnly) {
    const obj = await bucket.head(key);
    if (!obj) return new Response("Not found", { status: 404 });
    const headers = new Headers();
    headers.set("Content-Type", contentTypeFor(key));
    headers.set("Content-Length", String(obj.size));
    headers.set("ETag", obj.httpEtag);
    headers.set("Cache-Control", "public, max-age=31536000, immutable");
    headers.set("Content-Disposition", dispositionFor(key));
    return new Response(null, { status: 200, headers });
  }

  const obj = await bucket.get(key);
  if (!obj) return new Response("Not found", { status: 404 });
  const headers = new Headers();
  headers.set("Content-Type", contentTypeFor(key));
  headers.set("Content-Length", String(obj.size));
  headers.set("ETag", obj.httpEtag);
  headers.set("Cache-Control", "public, max-age=31536000, immutable");
  headers.set("Content-Disposition", dispositionFor(key));
  return new Response(obj.body, { status: 200, headers });
}

export async function onRequestGet(context) {
  return serve(context, false);
}

export async function onRequestHead(context) {
  return serve(context, true);
}

export async function onRequest(context) {
  const method = context.request.method;
  if (method === "GET") return serve(context, false);
  if (method === "HEAD") return serve(context, true);
  return new Response("Method not allowed", { status: 405 });
}
