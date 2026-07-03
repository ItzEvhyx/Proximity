// Supabase Edge Function: reset-user-password
//
// Updates a user's password by email using the Admin API. This MUST run
// server-side because it uses the service-role key, which bypasses RLS and
// must never ship inside the Flutter app.
//
// Deploy:
//   supabase functions deploy reset-user-password
// The SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY secrets are provided
// automatically by the platform for deployed functions.
//
// SECURITY NOTE: The OTP is currently verified on the client, so this function
// will reset the password for any email it is given. For production, move the
// OTP generation/verification into this function (or a companion function) so
// the server is the source of truth before allowing a password change.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, new_password } = await req.json();

    if (!email || !new_password) {
      return json({ error: "email and new_password are required" }, 400);
    }
    if (typeof new_password !== "string" || new_password.length < 8) {
      return json({ error: "Password must be at least 8 characters" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Find the user by email. listUsers is paginated; for large user bases
    // you'd filter server-side, but this is fine for typical volumes.
    const { data: list, error: listError } = await admin.auth.admin.listUsers();
    if (listError) {
      return json({ error: listError.message }, 500);
    }

    const normalized = String(email).trim().toLowerCase();
    const user = list.users.find(
      (u) => (u.email ?? "").toLowerCase() === normalized,
    );
    if (!user) {
      // Don't reveal whether the account exists.
      return json({ ok: true }, 200);
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      user.id,
      { password: new_password },
    );
    if (updateError) {
      return json({ error: updateError.message }, 500);
    }

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
