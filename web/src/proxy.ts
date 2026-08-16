import { createServerClient as createSupabaseServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { publicEnv } from "@/lib/env/public";

const publicRoutes = new Set(["/design-system", "/login"]);

export function isDatabaseIndependentPublicRoute(pathname: string) {
  return pathname === "/design-system";
}

function redirectWithCookies(
  request: NextRequest,
  pathname: string,
  source: NextResponse,
) {
  const response = NextResponse.redirect(new URL(pathname, request.url));
  source.cookies.getAll().forEach((cookie) => response.cookies.set(cookie));

  for (const header of ["cache-control", "expires", "pragma"] as const) {
    const value = source.headers.get(header);
    if (value) response.headers.set(header, value);
  }

  return response;
}

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  const pathname = request.nextUrl.pathname;

  // The public Design System is intentionally sample-only and must remain
  // available even before a production Supabase project is configured.
  if (isDatabaseIndependentPublicRoute(pathname)) {
    return response;
  }

  const { supabaseUrl, supabaseAnonKey } = publicEnv();
  const supabase = createSupabaseServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
        Object.entries(headers).forEach(([name, value]) => {
          response.headers.set(name, value);
        });
      },
    },
  });

  const { data } = await supabase.auth.getClaims();
  const isAuthenticated = Boolean(data?.claims);
  if (!isAuthenticated && !publicRoutes.has(pathname)) {
    return redirectWithCookies(request, "/login", response);
  }

  if (isAuthenticated && pathname === "/login") {
    return redirectWithCookies(request, "/", response);
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
