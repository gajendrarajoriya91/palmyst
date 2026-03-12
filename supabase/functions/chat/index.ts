import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js";
import { handleCors } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";

const MAX_HISTORY_MESSAGES = 20;

const BASE_SYSTEM_PROMPT = `You are a warm, insightful palm reading assistant for the Palmyst app.
You specialize in palmistry, self-discovery, and personal growth coaching.
Keep responses concise (2-4 sentences unless a detailed question warrants more).
Be encouraging, specific, and grounded.`;

Deno.serve(async (req: Request) => {
  const corsResult = handleCors(req);
  if (corsResult) return corsResult;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");

  if (!anthropicKey) {
    return errorResponse("AI service not configured", 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return errorResponse("Missing authorization header", 401);
  }

  const userClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authHeader } },
    },
  );
  const adminClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let chatSessionId: string;
  let userMessage: string;

  try {
    const body = await req.json();
    chatSessionId = body.chat_session_id;
    userMessage = (body.message ?? "").trim();
    if (!chatSessionId || !userMessage) throw new Error("missing fields");
    if (userMessage.length > 2000) throw new Error("message too long");
  } catch (e) {
    return errorResponse((e as Error).message || "Invalid request body");
  }

  // Verify chat session ownership
  const { data: chatSession, error: csErr } = await userClient
    .from("chat_sessions")
    .select("id, user_id, tool_session_id, tool_id")
    .eq("id", chatSessionId)
    .single();

  if (csErr || !chatSession) {
    return errorResponse("Chat session not found", 404);
  }

  // Fetch recent message history
  const { data: history } = await adminClient
    .from("chat_messages")
    .select("role, content")
    .eq("chat_session_id", chatSessionId)
    .order("created_at", { ascending: true })
    .limit(MAX_HISTORY_MESSAGES);

  // Build system prompt enriched with tool session context
  let systemPrompt = BASE_SYSTEM_PROMPT;

  if (chatSession.tool_session_id) {
    const { data: toolSession } = await adminClient
      .from("tool_sessions")
      .select("summary_text, overall_score, result_data, status")
      .eq("id", chatSession.tool_session_id)
      .single();

    if (toolSession?.status === "completed") {
      systemPrompt += `

The user has received a palm reading with the following results:
- Overall score: ${toolSession.overall_score}/100
- Summary: ${toolSession.summary_text}
- Detailed data: ${JSON.stringify(toolSession.result_data)}

Answer questions about their specific reading. Reference these insights when relevant.`;
    }
  }

  // Store the user message
  const { data: savedUserMsg } = await adminClient
    .from("chat_messages")
    .insert({
      chat_session_id: chatSessionId,
      role: "user",
      content: userMessage,
    })
    .select("id")
    .single();

  // Build messages array for Claude
  const messages: Anthropic.MessageParam[] = (history ?? []).map((m) => ({
    role: m.role as "user" | "assistant",
    content: m.content,
  }));

  // Append current user message
  messages.push({ role: "user", content: userMessage });

  try {
    const anthropic = new Anthropic({ apiKey: anthropicKey });

    const aiResponse = await anthropic.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system: systemPrompt,
      messages,
    });

    const assistantContent = aiResponse.content
      .filter((b): b is Anthropic.TextBlock => b.type === "text")
      .map((b) => b.text)
      .join("")
      .trim();

    // Store assistant reply
    const { data: savedAiMsg } = await adminClient
      .from("chat_messages")
      .insert({
        chat_session_id: chatSessionId,
        role: "assistant",
        content: assistantContent,
      })
      .select("id, created_at")
      .single();

    // Update chat session updated_at
    await adminClient
      .from("chat_sessions")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", chatSessionId);

    return jsonResponse({
      message_id: savedAiMsg?.id,
      content: assistantContent,
      created_at: savedAiMsg?.created_at,
    });
  } catch (err) {
    console.error("chat error:", err);

    // Remove the user message we pre-saved if AI call failed
    if (savedUserMsg?.id) {
      await adminClient
        .from("chat_messages")
        .delete()
        .eq("id", savedUserMsg.id);
    }

    return errorResponse("AI response failed. Please try again.", 500);
  }
});
