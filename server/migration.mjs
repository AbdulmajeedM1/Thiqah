import { decodeBase64Url } from "./legacy_password.mjs";
const encoder = new TextEncoder();
const digest = async (value) =>
  [
    ...new Uint8Array(
      await crypto.subtle.digest(
        "SHA-256",
        typeof value === "string" ? encoder.encode(value) : value,
      ),
    ),
  ]
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
const query = (db, sql, ...args) => db.prepare(sql).bind(...args);
const reject = (message, status = 400) => {
  throw Object.assign(new Error(message), { status });
};
const response = (value) =>
  Response.json(value, { headers: { "Cache-Control": "no-store" } });
function requireString(value, max = 200) {
  if (typeof value !== "string" || value.length > max)
    reject("invalid_migration");
  return value;
}
function requireList(value, max = 1000) {
  if (!Array.isArray(value) || value.length > max) reject("invalid_migration");
  return value;
}
async function authorizeMigration(request, env) {
  const key = request.headers.get("X-Migration-Key");
  if (
    !key ||
    !env.MIGRATION_KEY_SHA256 ||
    Date.now() > Number(env.MIGRATION_EXPIRES_AT) ||
    !Number.isFinite(Number(env.MIGRATION_EXPIRES_AT))
  )
    reject("forbidden", 403);
  if ((await digest(key)) !== env.MIGRATION_KEY_SHA256)
    reject("forbidden", 403);
}
function requireSource(source, env) {
  if (!/^[a-f0-9]{32}$/.test(source) || source !== env.MIGRATION_SOURCE_ID)
    reject("forbidden", 403);
}
async function mappedId(source, kind, id) {
  return "legacy-" + (await digest(source + "|" + kind + "|" + id));
}
async function fileId(source, path, checksum) {
  return mappedId(source, "file", path + "|" + checksum);
}

async function prepare(snapshot, env) {
  const source = requireString(snapshot.sourceId);
  requireSource(source, env);
  if (snapshot.version !== 1 || requireList(snapshot.missingFiles ?? []).length)
    reject("missing_local_files");
  const users = requireList(snapshot.accounts, 100);
  const requests = requireList(snapshot.marketplace?.requests, 1000);
  const files = snapshot.files;
  if (!files || typeof files !== "object" || Array.isArray(files))
    reject("invalid_migration");
  const payloadHash = await digest(JSON.stringify(snapshot));
  const previous = await query(
    env.DB,
    "SELECT * FROM migration_runs WHERE source_id=?",
    source,
  ).first();
  if (previous) {
    if (previous.payload_hash !== payloadHash)
      reject("migration_source_changed", 409);
    return { previous: JSON.parse(previous.result) };
  }
  const userMap = new Map(),
    accountRows = [],
    requestRows = [],
    uploadRows = new Map(),
    profileRows = [];
  const identities = new Set(),
    conflicts = [];
  for (const user of users) {
    const localId = requireString(user.id, 100);
    if (userMap.has(localId)) reject("duplicate_local_id");
    if (
      !["customer", "provider", "admin"].includes(user.role) ||
      !["active", "suspended"].includes(user.status)
    )
      reject("invalid_migration");
    const username = requireString(user.username, 100).toLowerCase();
    const email = requireString(user.email, 254).toLowerCase();
    const phone = requireString(user.phone ?? "", 30);
    if (!username || !email) reject("invalid_migration");
    for (const identity of [
      "username:" + username,
      "email:" + email,
      "phone:" + phone,
    ]) {
      if (identities.has(identity)) reject("duplicate_local_identity");
      identities.add(identity);
    }
    const existing = await query(
      env.DB,
      "SELECT username FROM accounts WHERE username=? OR email=? OR phone=?",
      username,
      email,
      phone,
    ).first();
    if (existing)
      conflicts.push({
        localUsername: username,
        cloudUsername: existing.username,
      });
    if (
      !Number.isInteger(user.iterations) ||
      user.iterations < 100000 ||
      user.iterations > 2000000 ||
      decodeBase64Url(requireString(user.passwordHash)).length !== 32 ||
      decodeBase64Url(requireString(user.salt)).length < 16
    )
      reject("invalid_password_record");
    const id = await mappedId(source, "account", localId);
    userMap.set(localId, id);
    accountRows.push({
      id,
      username,
      email,
      phone,
      fullName: requireString(user.fullName),
      city: requireString(user.city ?? ""),
      role: user.role,
      status: user.status,
      createdAt: requireString(user.createdAt),
      passwordHash: user.passwordHash,
      salt: user.salt,
      iterations: user.iterations,
    });
    const profile = snapshot.marketplace.profiles?.[localId] ?? {};
    const withdrawn = profile.withdrawn ?? 0;
    if (!Number.isSafeInteger(withdrawn) || withdrawn < 0)
      reject("invalid_profile");
    profileRows.push({ id, data: JSON.stringify(profile), withdrawn });
  }
  const requestIds = new Set();
  for (const original of requests) {
    const r = structuredClone(original),
      localId = requireString(r.id, 100);
    if (requestIds.has(localId)) reject("duplicate_request");
    requestIds.add(localId);
    const customerId = userMap.get(r.customerId);
    if (
      !customerId ||
      !users.some((u) => u.id === r.customerId && u.role === "customer")
    )
      reject("unresolved_request_owner");
    if (
      ![
        "draft",
        "open",
        "payment",
        "active",
        "confirmation",
        "completed",
        "disputed",
        "refunded",
        "cancelled",
      ].includes(r.stage)
    )
      reject("invalid_request_stage");
    r.id = await mappedId(source, "request", localId);
    r.customerId = customerId;
    requireString(r.title, 150);
    requireString(r.description, 10000);
    requireList(r.messages, 10000);
    requireList(r.timeline, 10000);
    const offerIds = new Set();
    for (const offer of requireList(r.offers, 1000)) {
      if (offerIds.has(offer.id)) reject("duplicate_offer");
      offerIds.add(offer.id);
      if (
        !userMap.has(offer.providerId) ||
        !users.some((u) => u.id === offer.providerId && u.role === "provider")
      )
        reject("unresolved_offer_owner");
      offer.providerId = userMap.get(offer.providerId);
    }
    if (r.selectedId && !offerIds.has(r.selectedId))
      reject("unresolved_selected_offer");
    for (const document of requireList(r.documents, 10)) {
      const path = requireString(document.path, 2000),
        metadata = files[path];
      if (
        !metadata ||
        !/^[a-f0-9]{64}$/.test(metadata.sha256) ||
        !Number.isSafeInteger(metadata.size) ||
        metadata.size < 1 ||
        metadata.size > 25 * 1024 * 1024
      )
        reject("invalid_file_metadata");
      const id = await fileId(source, path, metadata.sha256);
      const existing = uploadRows.get(id);
      if (existing && existing.ownerId !== customerId)
        reject("ambiguous_file_owner");
      uploadRows.set(id, {
        id,
        ownerId: customerId,
        name: requireString(document.name, 200),
        size: metadata.size,
        sha256: metadata.sha256,
      });
      document.path = "cloud:" + id;
      document.size = metadata.size;
    }
    r.operations = [];
    requestRows.push({
      id: r.id,
      customerId,
      selectedProvider:
        r.offers.find((o) => o.id === r.selectedId)?.providerId ?? null,
      stage: r.stage,
      data: JSON.stringify(r),
    });
  }
  return {
    source,
    payloadHash,
    accountRows,
    requestRows,
    uploadRows: [...uploadRows.values()],
    profileRows,
    conflicts,
  };
}
const summary = (plan) => ({
  accounts: plan.accountRows.length,
  requests: plan.requestRows.length,
  files: plan.uploadRows.length,
  usernames: plan.accountRows.map((u) => u.username),
  conflicts: plan.conflicts,
});

export async function migrationRoutes(request, env, path) {
  await authorizeMigration(request, env);
  if (path === "/migration/status" && request.method === "GET") {
    const row = await query(
      env.DB,
      "SELECT result FROM migration_runs WHERE source_id=?",
      env.MIGRATION_SOURCE_ID,
    ).first();
    return response({
      completed: !!row,
      result: row ? JSON.parse(row.result) : null,
    });
  }
  if (path === "/migration/file" && request.method === "POST") {
    if (
      Number(request.headers.get("content-length")) >
      25 * 1024 * 1024 + 100000
    )
      reject("file_too_large", 413);
    const form = await request.formData(),
      source = form.get("sourceId"),
      localPath = form.get("path"),
      file = form.get("file");
    requireSource(source, env);
    requireString(localPath, 2000);
    if (
      !(file instanceof File) ||
      file.size < 1 ||
      file.size > 25 * 1024 * 1024
    )
      reject("invalid_file");
    const committed = await query(
      env.DB,
      "SELECT source_id FROM migration_runs WHERE source_id=?",
      source,
    ).first();
    if (committed) reject("migration_already_completed", 409);
    const bytes = await file.arrayBuffer(),
      checksum = await digest(bytes);
    const id = await fileId(source, localPath, checksum);
    const existing = await env.BUCKET.head(id);
    if (!existing)
      await env.BUCKET.put(id, bytes, {
        customMetadata: { sha256: checksum, sourceId: source },
        httpMetadata: { contentType: "application/octet-stream" },
      });
    return response({ id, sha256: checksum, size: file.size });
  }
  if (
    !["/migration/preview", "/migration/import"].includes(path) ||
    request.method !== "POST"
  )
    reject("not_found", 404);
  const raw = await request.text();
  if (raw.length > 5 * 1024 * 1024) reject("migration_too_large", 413);
  let snapshot;
  try {
    snapshot = JSON.parse(raw);
  } catch {
    reject("invalid_migration");
  }
  const plan = await prepare(snapshot, env);
  if (plan.previous)
    return response({ completed: true, result: plan.previous });
  if (path === "/migration/preview") return response(summary(plan));
  if (plan.conflicts.length)
    return Response.json(
      { error: "migration_conflicts", conflicts: plan.conflicts },
      { status: 409 },
    );
  for (const file of plan.uploadRows) {
    const object = await env.BUCKET.head(file.id);
    if (
      !object ||
      object.size !== file.size ||
      object.customMetadata?.sha256 !== file.sha256
    )
      reject("missing_staged_file");
  }
  const writes = [];
  for (const user of plan.accountRows)
    writes.push(
      query(
        env.DB,
        "INSERT INTO accounts(id,username,email,phone,full_name,city,role,status,password_hash,salt,created_at,legacy_iterations,is_admin) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
        user.id,
        user.username,
        user.email,
        user.phone,
        user.fullName,
        user.city,
        user.role === "admin" ? "customer" : user.role,
        user.status,
        user.passwordHash,
        user.salt,
        user.createdAt,
        user.iterations,
        user.role === "admin" ? 1 : 0,
      ),
    );
  for (const file of plan.uploadRows)
    writes.push(
      query(
        env.DB,
        "INSERT INTO uploads(id,owner_id,name,size,created_at) VALUES(?,?,?,?,?)",
        file.id,
        file.ownerId,
        file.name,
        file.size,
        Date.now(),
      ),
    );
  for (const r of plan.requestRows)
    writes.push(
      query(
        env.DB,
        "INSERT INTO requests(id,customer_id,selected_provider,stage,data,updated_at) VALUES(?,?,?,?,?,?)",
        r.id,
        r.customerId,
        r.selectedProvider,
        r.stage,
        r.data,
        Date.now(),
      ),
    );
  for (const profile of plan.profileRows)
    writes.push(
      query(
        env.DB,
        "INSERT INTO profiles(user_id,data,withdrawn) VALUES(?,?,?)",
        profile.id,
        profile.data,
        profile.withdrawn,
      ),
    );
  const result = {
    ...summary(plan),
    accountIds: plan.accountRows.map((u) => u.id),
    requestIds: plan.requestRows.map((r) => r.id),
    fileIds: plan.uploadRows.map((f) => f.id),
  };
  writes.push(
    query(
      env.DB,
      "INSERT INTO migration_runs(source_id,payload_hash,result,completed_at) VALUES(?,?,?,?)",
      plan.source,
      plan.payloadHash,
      JSON.stringify(result),
      Date.now(),
    ),
  );
  try {
    await env.DB.batch(writes);
  } catch (error) {
    const completed = await query(
      env.DB,
      "SELECT result,payload_hash FROM migration_runs WHERE source_id=?",
      plan.source,
    ).first();
    if (completed?.payload_hash === plan.payloadHash)
      return response({
        completed: true,
        result: JSON.parse(completed.result),
      });
    throw error;
  }
  return response({ completed: true, result });
}
