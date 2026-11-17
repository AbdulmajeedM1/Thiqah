const encoder = new TextEncoder();
const MAX_FILE = 25 * 1024 * 1024;
const fail = (code, status = 400) => {
  throw Object.assign(new Error(code), { status });
};
const json = (body, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
const hex = (bytes) =>
  [...new Uint8Array(bytes)]
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
const hash = async (value) =>
  hex(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
const token = () => hex(crypto.getRandomValues(new Uint8Array(32)));
const now = () => Date.now();
const text = (value, min = 0, max = 2000) => {
  if (
    typeof value !== "string" ||
    value.trim().length < min ||
    value.length > max
  )
    fail("invalid_input");
  return value.trim();
};
const integer = (value, min, max) => {
  if (!Number.isSafeInteger(value) || value < min || value > max)
    fail("invalid_input");
  return value;
};
const require = (condition) => {
  if (!condition) fail("forbidden", 403);
};
const stmt = (db, sql, ...values) => db.prepare(sql).bind(...values);
const publicUser = (row) => ({
  id: row.id,
  fullName: row.full_name,
  username: row.username,
  email: row.email,
  phone: row.phone,
  city: row.city,
  role: row.role,
  status: row.status,
  createdAt: row.created_at,
});

async function passwordHash(password, salt) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  return hex(
    await crypto.subtle.deriveBits(
      {
        name: "PBKDF2",
        hash: "SHA-256",
        salt: encoder.encode(salt),
        iterations: 100000,
      },
      key,
      256,
    ),
  );
}
function passwordValue(value) {
  if (typeof value !== "string" || value.length < 1 || value.length > 128)
    fail("invalid_password");
  return value;
}
async function verify(password, account) {
  const actual = await passwordHash(password, account.salt);
  let difference = actual.length ^ account.password_hash.length;
  for (let i = 0; i < actual.length; i++)
    difference |= actual.charCodeAt(i) ^ account.password_hash.charCodeAt(i);
  return difference === 0;
}
function validPassword(value) {
  if (
    typeof value !== "string" ||
    value.length < 8 ||
    value.length > 128 ||
    !/[A-Za-z]/.test(value) ||
    !/[0-9]/.test(value)
  )
    fail("invalid_password");
  return value;
}
async function rateLimit(db, key, limit, duration) {
  const at = now();
  const row = await stmt(
    db,
    `INSERT INTO rate_limits(key,hits,expires_at) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET hits=CASE WHEN expires_at<=? THEN 1 ELSE hits+1 END, expires_at=CASE WHEN expires_at<=? THEN excluded.expires_at ELSE expires_at END RETURNING hits`,
    key,
    at + duration,
    at,
    at,
  ).first();
  if (row.hits > limit) fail("rate_limited", 429);
}
async function session(db, user) {
  const value = token();
  await stmt(
    db,
    "INSERT INTO sessions(hash,user_id,expires_at) VALUES(?,?,?)",
    await hash(value),
    user.id,
    now() + 604800000,
  ).run();
  return { user: publicUser(user), token: value };
}
async function authorize(request, db) {
  const value = request.headers.get("Authorization")?.replace(/^Bearer /, "");
  if (!value || !/^[a-f0-9]{64}$/.test(value)) fail("unauthorized", 401);
  const user = await stmt(
    db,
    "SELECT a.* FROM accounts a JOIN sessions s ON s.user_id=a.id WHERE s.hash=? AND s.expires_at>?",
    await hash(value),
    now(),
  ).first();
  if (!user) fail("unauthorized", 401);
  if (user.status !== "active") fail("account_suspended", 403);
  return user;
}
async function body(request) {
  if (Number(request.headers.get("content-length")) > 100000)
    fail("invalid_input", 413);
  const raw = await request.text();
  if (raw.length > 100000) fail("invalid_input", 413);
  try {
    return JSON.parse(raw);
  } catch {
    fail("invalid_input");
  }
}
function normalizePhone(value) {
  let phone = text(value, 9, 30)
    .replace(/[٠-٩۰-۹]/g, (c) =>
      String(c.charCodeAt(0) - (c >= "۰" ? 0x6f0 : 0x660)),
    )
    .replace(/[\s()-]/g, "");
  if (phone.startsWith("00966")) phone = "+" + phone.slice(2);
  if (/^05\d{8}$/.test(phone)) phone = "+966" + phone.slice(1);
  if (/^9665\d{8}$/.test(phone)) phone = "+" + phone;
  if (!/^\+9665\d{8}$/.test(phone)) fail("invalid_input");
  return phone;
}
async function authRoutes(request, env, path) {
  const db = env.DB;
  if (
    request.method === "POST" &&
    ["/auth/register", "/auth/login"].includes(path)
  ) {
    const input = await body(request);
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    await rateLimit(db, "auth-ip:" + (await hash(ip)), 40, 900000);
    if (path === "/auth/register") {
      if (input.termsAccepted !== true) fail("terms_required");
      const username = text(input.username, 3, 32).toLowerCase();
      const email = text(input.email, 5, 254).toLowerCase();
      if (
        !/^[a-z0-9_.-]+$/.test(username) ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
      )
        fail("invalid_input");
      if (!["customer", "provider"].includes(input.role)) fail("invalid_input");
      const user = {
        id: crypto.randomUUID(),
        username,
        email,
        phone: normalizePhone(input.phone),
        full_name: text(input.fullName, 3, 100),
        city: text(input.city, 2, 100),
        role: input.role,
        status: "active",
        created_at: new Date().toISOString(),
        salt: token(),
      };
      user.password_hash = await passwordHash(
        validPassword(input.password),
        user.salt,
      );
      try {
        await stmt(
          db,
          "INSERT INTO accounts(id,username,email,phone,full_name,city,role,password_hash,salt,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
          user.id,
          username,
          email,
          user.phone,
          user.full_name,
          user.city,
          user.role,
          user.password_hash,
          user.salt,
          user.created_at,
        ).run();
      } catch (error) {
        if (String(error).includes("UNIQUE")) fail("duplicate_account", 409);
        throw error;
      }
      return json(await session(db, user));
    }
    const login = text(input.login, 1, 254).toLowerCase();
    await rateLimit(db, "login:" + (await hash(login)), 20, 900000);
    const user = await stmt(
      db,
      "SELECT * FROM accounts WHERE username=? OR email=?",
      login,
      login,
    ).first();
    const password = passwordValue(input.password);
    const candidate = user || {
      salt: "unregistered-account",
      password_hash: "0".repeat(64),
    };
    const matches = await verify(password, candidate);
    if (!user || !matches) fail("invalid_credentials", 401);
    if (user.status !== "active") fail("account_suspended", 403);
    return json(await session(db, user));
  }
  const user = await authorize(request, db);
  if (path === "/auth/me" && request.method === "GET")
    return json({ user: publicUser(user) });
  if (path === "/auth/logout" && request.method === "POST") {
    await stmt(
      db,
      "DELETE FROM sessions WHERE hash=?",
      await hash(request.headers.get("Authorization").slice(7)),
    ).run();
    return json({});
  }
  if (path === "/auth/password" && request.method === "POST") {
    const input = await body(request);
    if (!(await verify(passwordValue(input.currentPassword), user)))
      fail("invalid_password");
    const password = validPassword(input.newPassword);
    if (password === input.currentPassword) fail("password_unchanged");
    const salt = token(),
      derived = await passwordHash(password, salt);
    const value = token();
    await db.batch([
      stmt(
        db,
        "UPDATE accounts SET password_hash=?,salt=? WHERE id=?",
        derived,
        salt,
        user.id,
      ),
      stmt(db, "DELETE FROM sessions WHERE user_id=?", user.id),
      stmt(
        db,
        "INSERT INTO sessions(hash,user_id,expires_at) VALUES(?,?,?)",
        await hash(value),
        user.id,
        now() + 604800000,
      ),
    ]);
    return json({ user: publicUser(user), token: value });
  }
  fail("not_found", 404);
}

const selected = (r) => r.offers.find((o) => o.id === r.selectedId);
const participant = (r, user) =>
  r.customerId === user.id || selected(r)?.providerId === user.id;
const visible = (r, user) =>
  r.customerId === user.id ||
  (user.role === "provider" &&
    (r.stage === "open" || r.offers.some((o) => o.providerId === user.id)));
function redact(r, user) {
  const output = structuredClone(r);
  delete output.operations;
  if (!participant(r, user)) {
    output.documents = [];
    output.messages = [];
    output.proof = "";
    output.dispute = "";
  }
  if (r.customerId !== user.id)
    output.offers = output.offers.filter((o) => o.providerId === user.id);
  return output;
}
async function snapshot(env, user) {
  const result = await stmt(
    env.DB,
    `SELECT data FROM requests WHERE customer_id=? OR (?='provider' AND (stage='open' OR selected_provider=? OR EXISTS(SELECT 1 FROM json_each(requests.data,'$.offers') o WHERE json_extract(o.value,'$.providerId')=?))) ORDER BY updated_at DESC`,
    user.id,
    user.role,
    user.id,
    user.id,
  ).all();
  const profile = await stmt(
    env.DB,
    "SELECT data,withdrawn,version FROM profiles WHERE user_id=?",
    user.id,
  ).first();
  const summaries = {};
  const completed = await stmt(
    env.DB,
    "SELECT data FROM requests WHERE stage='completed'",
  ).all();
  for (const row of completed.results) {
    const r = JSON.parse(row.data),
      provider = selected(r)?.providerId;
    if (!provider) continue;
    const stats = (summaries[provider] ??= { completed: 0, ratings: [] });
    stats.completed++;
    if (r.rating > 0)
      stats.ratings.push({ rating: r.rating, review: r.review });
  }
  return {
    requests: result.results.map((row) => redact(JSON.parse(row.data), user)),
    profile: profile
      ? {
          ...JSON.parse(profile.data),
          withdrawn: profile.withdrawn,
          version: profile.version,
        }
      : {},
    providerSummaries: summaries,
  };
}
async function validateDocuments(env, documents, user) {
  if (!Array.isArray(documents) || documents.length > 10) fail("invalid_input");
  const checked = [];
  for (const document of documents) {
    const id = text(document.path, 1, 100).replace(/^cloud:/, "");
    const row = await stmt(
      env.DB,
      "SELECT * FROM uploads WHERE id=? AND owner_id=?",
      id,
      user.id,
    ).first();
    if (!row) fail("invalid_document");
    checked.push({ name: row.name, path: "cloud:" + row.id, size: row.size });
  }
  return checked;
}
async function requestInput(env, input, user, id) {
  return {
    id,
    customerId: user.id,
    title: text(input.title, 5, 150),
    description: text(input.description, 15, 10000),
    category: integer(input.category, 0, 5),
    city: text(input.city, 2, 100),
    budget: integer(input.budget, 1, 100000000),
    urgent: input.urgent === true,
    consent: input.consent === true,
    documents: await validateDocuments(env, input.documents ?? [], user),
  };
}
const eventText = {
  create: "تم نشر الطلب",
  publish: "تم نشر الطلب",
  offer: "وصل عرض جديد",
  withdrawOffer: "تم سحب العرض",
  select: "تم اختيار مقدم الخدمة",
  pay: "محاكاة إيداع المبلغ في الضمان",
  complete: "رفع مقدم الخدمة إثبات الإنجاز",
  confirm: "تم تأكيد الإنجاز",
  cancel: "تم إلغاء الطلب",
  dispute: "فُتح نزاع",
  review: "تم إضافة التقييم",
  editDraft: "حُفظت المسودة",
};
async function mutateRequest(env, user, id, input) {
  const action = text(input.action, 1, 30),
    operation = text(input.operation, 10, 100);
  require(/^[a-zA-Z0-9-]{1,100}$/.test(id));
  if (action === "create") {
    require(user.role === "customer");
    const previous = await stmt(
      env.DB,
      "SELECT data FROM requests WHERE id=?",
      id,
    ).first();
    if (previous) {
      const r = JSON.parse(previous.data);
      require(r.customerId === user.id);
      return;
    }
    const fields = await requestInput(env, input.request, user, id);
    const stage = input.request.stage === "draft" ? "draft" : "open";
    if (stage === "open" && !fields.consent) fail("terms_required");
    const r = {
      ...fields,
      stage,
      mine: true,
      selectedId: null,
      proof: "",
      dispute: "",
      review: "",
      rating: 0,
      offers: [],
      messages: [],
      timeline: [stage === "draft" ? "حُفظت المسودة" : eventText.create],
      operations: [operation],
    };
    await stmt(
      env.DB,
      "INSERT INTO requests(id,customer_id,stage,data,updated_at) VALUES(?,?,?,?,?)",
      id,
      user.id,
      stage,
      JSON.stringify(r),
      now(),
    ).run();
    return;
  }
  for (let attempt = 0; attempt < 5; attempt++) {
    const row = await stmt(
      env.DB,
      "SELECT data,version FROM requests WHERE id=?",
      id,
    ).first();
    if (!row) fail("not_found", 404);
    const r = JSON.parse(row.data),
      owner = r.customerId === user.id,
      provider = user.role === "provider";
    require(visible(r, user));
    if (r.operations.includes(operation)) return;
    switch (action) {
      case "editDraft":
      case "publish":
        require(owner && r.stage === "draft");
        Object.assign(r, await requestInput(env, input.request, user, id));
        if (action === "publish") {
          require(r.consent);
          r.stage = "open";
        }
        break;
      case "offer":
        require(
          provider &&
            !owner &&
            r.stage === "open" &&
            !r.offers.some((o) => o.providerId === user.id),
        );
        r.offers.push({
          id: crypto.randomUUID(),
          name: user.full_name,
          providerId: user.id,
          mine: true,
          amount: integer(input.amount, 1, 100000000),
          days: integer(input.days, 1, 90),
          notes: text(input.notes ?? "", 0, 1000),
        });
        break;
      case "withdrawOffer":
        require(
          provider &&
            r.stage === "open" &&
            r.offers.some((o) => o.providerId === user.id),
        );
        r.offers = r.offers.filter((o) => o.providerId !== user.id);
        break;
      case "select":
        require(
          owner &&
            r.stage === "open" &&
            r.offers.some((o) => o.id === input.offerId),
        );
        r.selectedId = input.offerId;
        r.stage = "payment";
        break;
      case "pay":
        require(owner && r.stage === "payment");
        r.stage = "active";
        break;
      case "complete":
        require(selected(r)?.providerId === user.id && r.stage === "active");
        r.proof = text(input.proof, 8, 2000);
        r.stage = "confirmation";
        break;
      case "confirm":
        require(owner && r.stage === "confirmation");
        r.stage = "completed";
        break;
      case "cancel":
        require(owner && ["draft", "open", "payment"].includes(r.stage));
        r.stage = "cancelled";
        break;
      case "dispute":
        require(
          participant(r, user) && ["active", "confirmation"].includes(r.stage),
        );
        r.dispute = text(input.reason, 10, 2000);
        r.stage = "disputed";
        break;
      case "review":
        require(owner && r.stage === "completed" && r.rating === 0);
        r.rating = integer(input.rating, 1, 5);
        r.review = text(input.text ?? "", 0, 2000);
        break;
      case "send":
        require(participant(r, user) && selected(r));
        r.messages.push({
          text: text(input.text, 1, 2000),
          provider,
          at: new Date().toISOString(),
        });
        break;
      default:
        fail("invalid_input");
    }
    if (eventText[action]) r.timeline.push(eventText[action]);
    r.operations.push(operation);
    const result = await stmt(
      env.DB,
      "UPDATE requests SET data=?,stage=?,selected_provider=?,version=version+1,updated_at=? WHERE id=? AND version=?",
      JSON.stringify(r),
      r.stage,
      selected(r)?.providerId ?? null,
      now(),
      id,
      row.version,
    ).run();
    if (result.meta.changes === 1) return;
  }
  fail("conflict", 409);
}

async function api(request, env, path) {
  if (path === "/health") return json({ ok: true });
  if (path.startsWith("/auth/")) return authRoutes(request, env, path);
  const user = await authorize(request, env.DB);
  if (path === "/marketplace" && request.method === "GET")
    return json(await snapshot(env, user));
  if (path === "/profile" && request.method === "PUT") {
    const input = await body(request);
    const data = {
      darkMode: input.darkMode === true,
      english: input.english === true,
      notificationsEnabled: input.notificationsEnabled !== false,
    };
    await stmt(
      env.DB,
      "INSERT INTO profiles(user_id,data) VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET data=excluded.data",
      user.id,
      JSON.stringify(data),
    ).run();
    return json({});
  }
  if (path === "/withdraw" && request.method === "POST") {
    require(user.role === "provider");
    const input = await body(request),
      amount = integer(input.amount, 1, 100000000);
    const operation = text(input.operation, 10, 100);
    const previous = await stmt(
      env.DB,
      "SELECT id FROM withdrawals WHERE id=? AND user_id=?",
      operation,
      user.id,
    ).first();
    if (previous) return json(await snapshot(env, user));
    await stmt(
      env.DB,
      "INSERT INTO profiles(user_id) VALUES(?) ON CONFLICT(user_id) DO NOTHING",
      user.id,
    ).run();
    // The balance and withdrawal are checked in one SQL statement.
    const results = await env.DB.batch([
      stmt(
        env.DB,
        `UPDATE profiles SET withdrawn=withdrawn+?,version=version+1 WHERE user_id=? AND version=? AND withdrawn+? <= COALESCE((SELECT SUM(ROUND(json_extract(o.value,'$.amount')*0.9)) FROM requests r,json_each(r.data,'$.offers') o WHERE r.stage='completed' AND r.selected_provider=? AND json_extract(o.value,'$.id')=json_extract(r.data,'$.selectedId')),0)`,
        amount,
        user.id,
        integer(input.version, 1, 100000000),
        amount,
        user.id,
      ),
      stmt(
        env.DB,
        "INSERT INTO withdrawals(id,user_id,amount) SELECT ?,?,? WHERE changes()=1",
        operation,
        user.id,
        amount,
      ),
    ]);
    if (results[0].meta.changes !== 1) fail("conflict", 409);
    return json(await snapshot(env, user));
  }
  if (path === "/uploads" && request.method === "POST") {
    await rateLimit(env.DB, "upload:" + user.id, 40, 3600000);
    if (Number(request.headers.get("content-length")) > MAX_FILE + 100000)
      fail("invalid_document", 413);
    const form = await request.formData(),
      file = form.get("file");
    if (!(file instanceof File) || file.size > MAX_FILE || file.size === 0)
      fail("invalid_document", 413);
    const name = text(file.name, 1, 200);
    if (!/\.(pdf|jpg|jpeg|png|docx|xlsx|zip)$/i.test(name))
      fail("invalid_document");
    const id = crypto.randomUUID();
    await env.BUCKET.put(id, file.stream(), {
      httpMetadata: { contentType: "application/octet-stream" },
    });
    try {
      await stmt(
        env.DB,
        "INSERT INTO uploads(id,owner_id,name,size,created_at) VALUES(?,?,?,?,?)",
        id,
        user.id,
        name,
        file.size,
        now(),
      ).run();
    } catch (error) {
      await env.BUCKET.delete(id);
      throw error;
    }
    return json({ document: { name, path: "cloud:" + id, size: file.size } });
  }
  if (path.startsWith("/uploads/") && request.method === "GET") {
    const id = path.slice(9),
      file = await stmt(env.DB, "SELECT * FROM uploads WHERE id=?", id).first();
    if (!file) fail("not_found", 404);
    if (file.owner_id !== user.id) {
      const rows = await stmt(
        env.DB,
        "SELECT data FROM requests WHERE selected_provider=?",
        user.id,
      ).all();
      require(
        rows.results.some((row) =>
          JSON.parse(row.data).documents.some((d) => d.path === "cloud:" + id),
        ),
      );
    }
    const object = await env.BUCKET.get(id);
    if (!object) fail("not_found", 404);
    return new Response(object.body, {
      headers: {
        "Content-Type": "application/octet-stream",
        "Cache-Control": "no-store",
        "Content-Disposition":
          "attachment; filename*=UTF-8''" + encodeURIComponent(file.name),
      },
    });
  }
  const match = path.match(/^\/requests\/([a-zA-Z0-9-]+)\/actions$/);
  if (match && request.method === "POST") {
    await rateLimit(env.DB, "write:" + user.id, 120, 60000);
    await mutateRequest(env, user, match[1], await body(request));
    return json(await snapshot(env, user));
  }
  fail("not_found", 404);
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);
    let response;
    try {
      if (request.method === "OPTIONS")
        response = new Response(null, { status: 204 });
      else response = await api(request, env, url.pathname.slice(4));
    } catch (error) {
      response = json(
        { error: error.status ? error.message : "server_error" },
        error.status ?? 500,
      );
    }
    const headers = new Headers(response.headers);
    headers.set("Access-Control-Allow-Origin", url.origin);
    headers.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
    headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS");
    headers.set("X-Content-Type-Options", "nosniff");
    return new Response(response.body, { status: response.status, headers });
  },
};
