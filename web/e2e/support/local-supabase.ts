const approvedLocalHosts = new Set(["127.0.0.1", "localhost", "::1"]);

export function requireLocalSupabaseUrl(value: string | undefined) {
  let url: URL;

  try {
    url = new URL(value ?? "");
  } catch {
    throw new Error("Authenticated E2E requires a valid local Supabase URL");
  }

  const hostname = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (!approvedLocalHosts.has(hostname)) {
    throw new Error("Authenticated E2E requires a local Supabase URL");
  }

  return url;
}
