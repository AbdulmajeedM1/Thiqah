import { pbkdf2Async } from "@noble/hashes/pbkdf2.js";
import { sha256 } from "@noble/hashes/sha2.js";

export function decodeBase64Url(value) {
  return Uint8Array.from(
    atob(value.replace(/-/g, "+").replace(/_/g, "/")),
    (c) => c.charCodeAt(0),
  );
}

export async function verifyLegacyPassword(password, account) {
  const rounds = account.legacy_iterations;
  if (!Number.isInteger(rounds) || rounds < 1 || rounds > 2000000) return false;
  const expected = decodeBase64Url(account.password_hash);
  const actual = await pbkdf2Async(
    sha256,
    new TextEncoder().encode(password),
    decodeBase64Url(account.salt),
    { c: rounds, dkLen: 32 },
  );
  let difference = actual.length ^ expected.length;
  for (let i = 0; i < actual.length; i++) difference |= actual[i] ^ expected[i];
  return difference === 0;
}
