/**
 * process-payment — Payment webhook handler
 *
 * Supports two providers detected by request headers:
 *   • Stripe   — stripe-signature header
 *   • RevenueCat — X-RevenueCat-Signature header (HMAC-SHA256)
 *
 * ENV vars required:
 *   STRIPE_WEBHOOK_SECRET      — Stripe signing secret
 *   REVENUECAT_WEBHOOK_SECRET  — RevenueCat webhook auth key
 */

import { createClient } from "npm:@supabase/supabase-js";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";

type Provider = "stripe" | "revenuecat";

interface NormalisedEvent {
  provider: Provider;
  externalRef: string;
  userId: string | null;
  userEmail: string | null;
  planSlug: string | null;
  amountUsd: number;
  currency: string;
  creditsGranted: number | null;
  status: "completed" | "failed" | "refunded";
  rawPayload: unknown;
}

// ── Stripe helpers ────────────────────────────────────────────────────────────

async function verifyStripeSignature(
  rawBody: string,
  sigHeader: string,
  secret: string,
): Promise<boolean> {
  const parts = Object.fromEntries(
    sigHeader.split(",").map((p) => p.split("=")),
  ) as Record<string, string>;

  const timestamp = parts["t"];
  const signature = parts["v1"];
  if (!timestamp || !signature) return false;

  const payload = `${timestamp}.${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return expected === signature;
}

function normaliseStripe(payload: Record<string, unknown>): NormalisedEvent | null {
  const type = payload.type as string;
  const obj = (payload.data as Record<string, unknown>)?.object as Record<string, unknown>;
  if (!obj) return null;

  const status: "completed" | "failed" | "refunded" =
    type === "payment_intent.succeeded"
      ? "completed"
      : type === "charge.refunded"
      ? "refunded"
      : "failed";

  return {
    provider: "stripe",
    externalRef: (obj.id ?? obj.payment_intent) as string,
    userId: (obj.metadata as Record<string, string>)?.supabase_user_id ?? null,
    userEmail: (obj.receipt_email ?? (obj.billing_details as Record<string, string>)?.email) as string ?? null,
    planSlug: (obj.metadata as Record<string, string>)?.plan_slug ?? null,
    amountUsd: Math.round(((obj.amount ?? obj.amount_received ?? 0) as number) / 100),
    currency: ((obj.currency as string) ?? "usd").toUpperCase(),
    creditsGranted: null,
    status,
    rawPayload: payload,
  };
}

// ── RevenueCat helpers ────────────────────────────────────────────────────────

async function verifyRevenueCatSignature(
  rawBody: string,
  sigHeader: string,
  secret: string,
): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = btoa(String.fromCharCode(...new Uint8Array(mac)));
  return expected === sigHeader;
}

const REVENUECAT_COMPLETED_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "NON_SUBSCRIPTION_PURCHASE",
]);

const REVENUECAT_REFUND_TYPES = new Set(["CANCELLATION", "EXPIRATION"]);

function normaliseRevenueCat(payload: Record<string, unknown>): NormalisedEvent | null {
  const event = payload.event as Record<string, unknown>;
  if (!event) return null;

  const eventType = event.type as string;

  const status: "completed" | "failed" | "refunded" = REVENUECAT_COMPLETED_TYPES.has(
    eventType,
  )
    ? "completed"
    : REVENUECAT_REFUND_TYPES.has(eventType)
    ? "refunded"
    : "failed";

  return {
    provider: "revenuecat",
    externalRef: event.id as string,
    userId: (event.app_user_id as string) ?? null,
    userEmail: null,
    planSlug: (event.product_id as string) ?? null,
    amountUsd: Math.round(((event.price ?? 0) as number)),
    currency: ((event.currency as string) ?? "USD").toUpperCase(),
    creditsGranted: null,
    status,
    rawPayload: payload,
  };
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const stripeSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const rcSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

  const rawBody = await req.text();

  let event: NormalisedEvent | null = null;
  let provider: Provider | null = null;

  const stripeSig = req.headers.get("stripe-signature");
  const rcSig = req.headers.get("x-revenuecat-signature");

  if (stripeSig && stripeSecret) {
    const valid = await verifyStripeSignature(rawBody, stripeSig, stripeSecret);
    if (!valid) return errorResponse("Invalid Stripe signature", 401);
    provider = "stripe";
    event = normaliseStripe(JSON.parse(rawBody));
  } else if (rcSig && rcSecret) {
    const valid = await verifyRevenueCatSignature(rawBody, rcSig, rcSecret);
    if (!valid) return errorResponse("Invalid RevenueCat signature", 401);
    provider = "revenuecat";
    event = normaliseRevenueCat(JSON.parse(rawBody));
  } else {
    return errorResponse("Unknown payment provider", 400);
  }

  if (!event) {
    return jsonResponse({ received: true, processed: false, reason: "unhandled_event_type" });
  }

  const admin = createClient(supabaseUrl, serviceKey);

  // Resolve user_id from external ref or email
  let resolvedUserId = event.userId;

  if (!resolvedUserId && event.userEmail) {
    const { data } = await admin.auth.admin.listUsers();
    const found = data?.users?.find((u) => u.email === event.userEmail);
    resolvedUserId = found?.id ?? null;
  }

  if (!resolvedUserId) {
    console.warn("process-payment: could not resolve user for event", event.externalRef);
    return jsonResponse({ received: true, processed: false, reason: "user_not_found" });
  }

  // Look up the subscription plan by slug
  let planId: string | null = null;
  let planCredits = 0;

  if (event.planSlug) {
    const { data: plan } = await admin
      .from("subscription_plans")
      .select("id, credits_included")
      .eq("slug", event.planSlug)
      .single();

    if (plan) {
      planId = plan.id;
      planCredits = plan.credits_included;
    }
  }

  const creditsToGrant = event.creditsGranted ?? planCredits;

  // Check for duplicate event (idempotent)
  const { data: existing } = await admin
    .from("user_purchases")
    .select("id, payment_status")
    .eq("payment_provider_ref", event.externalRef)
    .maybeSingle();

  if (existing) {
    if (existing.payment_status === event.status) {
      return jsonResponse({ received: true, processed: false, reason: "duplicate_event" });
    }

    // Update status only
    await admin
      .from("user_purchases")
      .update({ payment_status: event.status })
      .eq("id", existing.id);

    return jsonResponse({ received: true, processed: true, purchase_id: existing.id });
  }

  // Insert new purchase record
  const { data: purchase, error: purchaseErr } = await admin
    .from("user_purchases")
    .insert({
      user_id: resolvedUserId,
      plan_id: planId,
      amount_paid: event.amountUsd,
      currency: event.currency,
      discount_amount: 0,
      payment_status: event.status,
      payment_provider: provider,
      payment_provider_ref: event.externalRef,
      billing_email: event.userEmail,
      credits_granted: creditsToGrant,
    })
    .select("id")
    .single();

  if (purchaseErr) {
    console.error("process-payment insert error:", purchaseErr);
    return errorResponse("Failed to record purchase", 500);
  }

  // Credits are granted automatically via fn_grant_credits_on_purchase trigger
  // when payment_status = 'completed'.

  return jsonResponse({ received: true, processed: true, purchase_id: purchase?.id });
});
