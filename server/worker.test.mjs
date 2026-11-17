import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import worker from "./worker.mjs";
import { migrationRoutes } from "./migration.mjs";
import { createHash, pbkdf2Sync } from "node:crypto";
const sql = new DatabaseSync(":memory:");
sql.exec(
  readFileSync(
    new URL("./drizzle/0000_shared_marketplace.sql", import.meta.url),
    "utf8",
  ),
);
sql.exec(
  readFileSync(
    new URL("./drizzle/0001_local_migration.sql", import.meta.url),
    "utf8",
  ),
);
class Statement {
  constructor(query, values = []) {
    this.query = query;
    this.values = values;
  }
  bind(...values) {
    return new Statement(this.query, values);
  }
  async first() {
    return sql.prepare(this.query).get(...this.values) ?? null;
  }
  async all() {
    return { results: sql.prepare(this.query).all(...this.values) };
  }
  async run() {
    const r = sql.prepare(this.query).run(...this.values);
    return { meta: { changes: Number(r.changes) } };
  }
}
const objects = new Map();
const env = {
  DB: {
    prepare: (q) => new Statement(q),
    batch: async (statements) => {
      sql.exec("BEGIN");
      try {
        const result = [];
        for (const statement of statements) result.push(await statement.run());
        sql.exec("COMMIT");
        return result;
      } catch (error) {
        sql.exec("ROLLBACK");
        throw error;
      }
    },
  },
  BUCKET: {
    put: async (id, stream, options = {}) => {
      const body = await new Response(stream).arrayBuffer();
      objects.set(id, { body, size: body.byteLength, ...options });
    },
    head: async (id) => objects.get(id) ?? null,
    get: async (id) => objects.get(id) ?? null,
    delete: async (id) => objects.delete(id),
  },
  ASSETS: { fetch: () => new Response("app") },
};
async function call(path, method = "GET", input, token) {
  const response = await worker.fetch(
    new Request("https://test.local/api" + path, {
      method,
      headers: {
        ...(token ? { Authorization: "Bearer " + token } : {}),
        ...(input ? { "Content-Type": "application/json" } : {}),
      },
      body: input ? JSON.stringify(input) : undefined,
    }),
    env,
  );
  return { status: response.status, data: await response.json() };
}
async function register(role, suffix) {
  const response = await call("/auth/register", "POST", {
    fullName: "Test " + suffix,
    username: "test" + suffix,
    email: suffix + "@example.com",
    phone: "050000000" + suffix,
    city: "Riyadh",
    role,
    password: "Testing-only-123",
    termsAccepted: true,
  });
  assert.equal(response.status, 200, JSON.stringify(response.data));
  return response.data;
}
const customer = await register("customer", "1"),
  provider = await register("provider", "2"),
  other = await register("provider", "3"),
  stranger = await register("customer", "4");
const input = {
  title: "Test request",
  description: "A sufficiently long request description",
  category: 0,
  city: "Riyadh",
  budget: 50000,
  consent: true,
  documents: [],
  stage: "open",
};
const act = (user, id, action, values = {}) =>
  call(
    "/requests/" + id + "/actions",
    "POST",
    { action, operation: crypto.randomUUID(), ...values },
    user.token,
  );
assert.equal(
  (await act(customer, "request-one", "create", { request: input })).status,
  200,
);
assert.equal(
  (
    await act(customer, "draft-one", "create", {
      request: { ...input, stage: "draft" },
    })
  ).status,
  200,
);
assert.equal(
  (await call("/marketplace", "GET", undefined, provider.token)).data.requests
    .length,
  1,
);
assert.equal(
  (await call("/marketplace", "GET", undefined, stranger.token)).data.requests
    .length,
  0,
);
assert.equal((await act(stranger, "request-one", "cancel")).status, 403);
const [offerOne, offerTwo] = await Promise.all([
  act(provider, "request-one", "offer", {
    amount: 10000,
    days: 3,
    notes: "First provider",
  }),
  act(other, "request-one", "offer", {
    amount: 12000,
    days: 4,
    notes: "Second provider",
  }),
]);
assert.equal(offerOne.status, 200);
assert.equal(offerTwo.status, 200);
let view = (await call("/marketplace", "GET", undefined, customer.token)).data;
assert.equal(
  view.requests.find((r) => r.id === "request-one").offers.length,
  2,
);
const offer = view.requests
  .find((r) => r.id === "request-one")
  .offers.find((o) => o.providerId === provider.user.id);
assert.equal(
  (await act(provider, "request-one", "select", { offerId: offer.id })).status,
  403,
);
assert.equal(
  (await act(customer, "request-one", "select", { offerId: offer.id })).status,
  200,
);
assert.equal(
  (await act(other, "request-one", "send", { text: "intrusion" })).status,
  403,
);
assert.equal(
  (
    await act(provider, "request-one", "send", {
      text: "I will handle the task",
    })
  ).status,
  200,
);
assert.equal(
  (await call("/marketplace", "GET", undefined, other.token)).data.requests[0]
    .messages.length,
  0,
);
const operation = crypto.randomUUID();
await call(
  "/requests/request-one/actions",
  "POST",
  { action: "send", operation, text: "Only once" },
  customer.token,
);
await call(
  "/requests/request-one/actions",
  "POST",
  { action: "send", operation, text: "Only once" },
  customer.token,
);
view = (await call("/marketplace", "GET", undefined, customer.token)).data;
assert.equal(
  view.requests
    .find((r) => r.id === "request-one")
    .messages.filter((m) => m.text === "Only once").length,
  1,
);
assert.equal((await act(customer, "request-one", "pay")).status, 200);
assert.equal(
  (await act(other, "request-one", "complete", { proof: "Completed safely" }))
    .status,
  403,
);
assert.equal(
  (
    await act(provider, "request-one", "complete", {
      proof: "Completed safely",
    })
  ).status,
  200,
);
assert.equal((await act(customer, "request-one", "confirm")).status, 200);
assert.equal(
  (await act(customer, "request-one", "review", { rating: 5, text: "Great" }))
    .status,
  200,
);
assert.equal(
  (
    await call(
      "/withdraw",
      "POST",
      { amount: 9000, version: 1, operation: crypto.randomUUID() },
      provider.token,
    )
  ).status,
  200,
);
assert.equal(
  (
    await call(
      "/withdraw",
      "POST",
      { amount: 9000, version: 1, operation: crypto.randomUUID() },
      provider.token,
    )
  ).status,
  409,
);
const login = await call("/auth/login", "POST", {
  login: "test1",
  password: "Testing-only-123",
});
assert.equal(login.status, 200);
assert.equal(
  (await call("/marketplace", "GET", undefined, login.data.token)).data.requests
    .length,
  2,
);
const form = new FormData();
form.set("file", new File(["sample attachment"], "test.pdf"));
const uploaded = await worker.fetch(
  new Request("https://test.local/api/uploads", {
    method: "POST",
    headers: { Authorization: "Bearer " + customer.token },
    body: form,
  }),
  env,
);
assert.equal(uploaded.status, 200);
const doc = (await uploaded.json()).document;
assert.equal(
  (
    await act(customer, "with-file", "create", {
      request: { ...input, documents: [doc] },
    })
  ).status,
  200,
);
const forbidden = await worker.fetch(
  new Request("https://test.local/api/uploads/" + doc.path.slice(6), {
    headers: { Authorization: "Bearer " + other.token },
  }),
  env,
);
assert.equal(forbidden.status, 403);
assert.equal(
  (
    await act(provider, "with-file", "offer", {
      amount: 100,
      days: 1,
      notes: "",
    })
  ).status,
  200,
);
view = (await call("/marketplace", "GET", undefined, customer.token)).data;
await act(customer, "with-file", "select", {
  offerId: view.requests.find((r) => r.id === "with-file").offers[0].id,
});
const allowed = await worker.fetch(
  new Request("https://test.local/api/uploads/" + doc.path.slice(6), {
    headers: { Authorization: "Bearer " + provider.token },
  }),
  env,
);
assert.equal(allowed.status, 200);
assert.equal(await allowed.text(), "sample attachment");
const changed = await call(
  "/auth/password",
  "POST",
  { currentPassword: "Testing-only-123", newPassword: "Changed-test-456" },
  customer.token,
);
assert.equal(changed.status, 200);
assert.equal(
  (await call("/auth/me", "GET", undefined, customer.token)).status,
  401,
);
assert.equal(
  (await call("/auth/me", "GET", undefined, changed.data.token)).status,
  200,
);
console.log(
  "PASS shared accounts, concurrent offers, ownership, lifecycle, idempotency, files, password rotation, and cross-session persistence",
);

const migrationKey = "test-only-migration-secret";
const sourceId = "a".repeat(32);
env.MIGRATION_KEY_SHA256 = createHash("sha256")
  .update(migrationKey)
  .digest("hex");
env.MIGRATION_SOURCE_ID = sourceId;
env.MIGRATION_EXPIRES_AT = String(Date.now() + 60000);
const salt = Buffer.alloc(16, 7);
const legacyPassword = "Original-password-123";
const passwordHash = pbkdf2Sync(
  legacyPassword,
  salt,
  600000,
  32,
  "sha256",
).toString("base64url");
const accounts = ["customer", "provider", "admin"].map((role, index) => ({
  id: role,
  role,
  username: "legacy" + role,
  email: role + "@legacy.example",
  phone: "+96650000100" + index,
  fullName: "Legacy " + role,
  city: "Riyadh",
  status: "active",
  createdAt: new Date().toISOString(),
  iterations: 600000,
  salt: salt.toString("base64url"),
  passwordHash,
}));
const bytes = Buffer.from("original attachment");
const snapshot = {
  version: 1,
  sourceId,
  accounts,
  missingFiles: [],
  files: {
    "/old/file.pdf": {
      name: "file.pdf",
      size: bytes.length,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    },
  },
  marketplace: {
    profiles: { provider: { withdrawn: 120 } },
    requests: [
      {
        ...input,
        id: "old-request",
        customerId: "customer",
        stage: "completed",
        offers: [{ id: "offer1", providerId: "provider", amount: 10000 }],
        selectedId: "offer1",
        documents: [{ name: "file.pdf", path: "/old/file.pdf" }],
        messages: [{ text: "Original message" }],
        timeline: [{ text: "Original event" }],
      },
    ],
  },
};
async function migrate(path, body, key = migrationKey) {
  const isForm = body instanceof FormData;
  try {
    const result = await migrationRoutes(
      new Request("https://test.local/api/migration/" + path, {
        method: body ? "POST" : "GET",
        headers: {
          "X-Migration-Key": key,
          ...(!isForm && body ? { "Content-Type": "application/json" } : {}),
        },
        body: body ? (isForm ? body : JSON.stringify(body)) : undefined,
      }),
      env,
      "/migration/" + path,
    );
    return { status: result.status, data: await result.json() };
  } catch (error) {
    return { status: error.status ?? 500, data: { error: error.message } };
  }
}
assert.equal((await call("/migration/status")).status, 403);
assert.equal((await migrate("preview", snapshot, "")).status, 403);
assert.equal((await migrate("preview", snapshot)).data.accounts, 3);
assert.equal(
  sql.prepare("SELECT COUNT(*) AS n FROM migration_runs").get().n,
  0,
);
assert.equal(
  (await migrate("import", snapshot)).data.error,
  "missing_staged_file",
);
const migrationFile = new FormData();
migrationFile.set("sourceId", sourceId);
migrationFile.set("path", "/old/file.pdf");
migrationFile.set("file", new File([bytes], "file.pdf"));
assert.equal((await migrate("file", migrationFile)).status, 200);
const imported = await migrate("import", snapshot);
assert.equal(imported.status, 200, JSON.stringify(imported.data));
assert.equal((await migrate("import", snapshot)).data.completed, true);
assert.equal(
  sql.prepare("SELECT COUNT(*) AS n FROM migration_runs").get().n,
  1,
);
for (const account of accounts) {
  const login = await call("/auth/login", "POST", {
    login: account.username,
    password: legacyPassword,
  });
  assert.equal(login.status, 200, JSON.stringify(login.data));
  assert.equal(login.data.user.role, account.role);
  if (account.role === "admin")
    assert.equal(
      (await call("/admin/users", "GET", undefined, login.data.token)).status,
      200,
    );
  if (account.role === "provider") {
    const records = (
      await call("/marketplace", "GET", undefined, login.data.token)
    ).data.requests;
    const record = records.find(
      (r) => r.id === imported.data.result.requestIds[0],
    );
    assert.equal(record.offers[0].providerId, login.data.user.id);
    assert.equal(record.messages[0].text, "Original message");
    const download = await worker.fetch(
      new Request(
        "https://test.local/api/uploads/" + imported.data.result.fileIds[0],
        { headers: { Authorization: "Bearer " + login.data.token } },
      ),
      env,
    );
    assert.equal(await download.text(), bytes.toString());
    assert.equal(
      sql
        .prepare("SELECT withdrawn FROM profiles WHERE user_id=?")
        .get(login.data.user.id).withdrawn,
      120,
    );
    const rotated = await call(
      "/auth/password",
      "POST",
      { currentPassword: legacyPassword, newPassword: "Updated-password-456" },
      login.data.token,
    );
    assert.equal(rotated.status, 200);
    assert.equal(
      sql
        .prepare("SELECT legacy_iterations FROM accounts WHERE id=?")
        .get(login.data.user.id).legacy_iterations,
      0,
    );
  }
}
env.MIGRATION_EXPIRES_AT = "0";
assert.equal((await migrate("status")).status, 403);
console.log(
  "PASS legacy 600000-round passwords, atomic import, retries, ownership, attachments, profiles and administrator access",
);
