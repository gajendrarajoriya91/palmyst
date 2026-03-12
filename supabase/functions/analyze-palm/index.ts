import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js";
import { handleCors } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";

const SOLUTION_UNLOCK_COST = 5;

const ANALYSIS_SYSTEM_PROMPT = `You are an expert palm reader and holistic life coach.
Analyze the provided palm image(s) and return a structured JSON response.
Base your reading on palmistry traditions combined with psychological insights.
Be specific, thoughtful, and constructive.

Return ONLY valid JSON matching this exact schema:
{
  "overall_score": <integer 0-100>,
  "summary_text": "<2-3 sentence personal overview>",
  "metrics": [
    {"metric_name": "Relationship", "score": <0-100>, "unit": "%", "display_order": 1},
    {"metric_name": "Finance",      "score": <0-100>, "unit": "%", "display_order": 2},
    {"metric_name": "Career",       "score": <0-100>, "unit": "%", "display_order": 3},
    {"metric_name": "Health",       "score": <0-100>, "unit": "%", "display_order": 4},
    {"metric_name": "Growth",       "score": <0-100>, "unit": "%", "display_order": 5},
    {"metric_name": "Personal Life","score": <0-100>, "unit": "%", "display_order": 6}
  ],
  "key_lines": {
    "heart_line": "<observation>",
    "head_line":  "<observation>",
    "life_line":  "<observation>",
    "fate_line":  "<observation or null>"
  },
  "mounts": {
    "venus":   "<observation>",
    "jupiter": "<observation>",
    "saturn":  "<observation>",
    "apollo":  "<observation>",
    "mercury": "<observation>"
  },
  "detailed_analysis": "<3-4 paragraphs of deep personal insight>",
  "traditional_advice": "<2-3 paragraphs of traditional palmistry guidance>",
  "science_backed_advice": "<2-3 paragraphs grounded in psychology and research>"
}`;

interface AnalysisResult {
  overall_score: number;
  summary_text: string;
  metrics: Array<{
    metric_name: string;
    score: number;
    unit: string;
    display_order: number;
  }>;
  key_lines: Record<string, string | null>;
  mounts: Record<string, string>;
  detailed_analysis: string;
  traditional_advice: string;
  science_backed_advice: string;
}

const VALID_IMAGE_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];

async function fetchImageAsBase64(
  url: string,
): Promise<{ data: string; mediaType: string }> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch image: ${res.status}`);

  const contentType = res.headers.get("content-type") ?? "";
  const mediaType = contentType.split(";")[0].trim();

  if (!VALID_IMAGE_TYPES.includes(mediaType)) {
    throw new Error(
      `palm_image_url must be a direct image link (got content-type: "${mediaType}"). ` +
      `URL "${url}" appears to be a webpage, not an image.`,
    );
  }

  const buffer = await res.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunkSize = 8192;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return { data: btoa(binary), mediaType };
}

Deno.serve(async (req: Request) => {
  const corsResult = handleCors(req);
  if (corsResult) return corsResult;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");

  if (!anthropicKey) {
    return errorResponse("AI service not configured", 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return errorResponse("Missing authorization header", 401);
  }

  // User-scoped client to verify ownership
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });

  // Admin client for write-back (bypasses RLS)
  const adminClient = createClient(supabaseUrl, serviceKey);

  let sessionId: string;
  try {
    const body = await req.json();
    sessionId = body.session_id;
    if (!sessionId) throw new Error("missing session_id");
  } catch {
    return errorResponse("Invalid request body");
  }

  // Verify session ownership and state
  const { data: session, error: sessErr } = await userClient
    .from("tool_sessions")
    .select("id, user_id, tool_id, palm1_id, palm2_id, status, credits_used")
    .eq("id", sessionId)
    .single();

  if (sessErr || !session) {
    return errorResponse("Session not found", 404);
  }

  if (!["pending", "processing"].includes(session.status)) {
    return errorResponse(`Session already in state: ${session.status}`, 409);
  }

  // Mark as processing
  await adminClient
    .from("tool_sessions")
    .update({ status: "processing" })
    .eq("id", sessionId);

  try {
    // Fetch palm image URLs
    const palmIds = [session.palm1_id, session.palm2_id].filter(Boolean);
    const { data: palms } = await adminClient
      .from("palms")
      .select("id, palm_image_url, name")
      .in("id", palmIds);

    if (!palms?.length) {
      throw new Error("No palm images found");
    }

    // Fetch tool context for focused analysis
    const { data: tool } = await adminClient
      .from("tools")
      .select("name, description")
      .eq("id", session.tool_id)
      .single();

    // Build image content blocks
    const imageBlocks: Anthropic.ImageBlockParam[] = [];
    for (const palm of palms) {
      if (!palm.palm_image_url) continue;
      const { data, mediaType } = await fetchImageAsBase64(palm.palm_image_url);
      imageBlocks.push({
        type: "image",
        source: {
          type: "base64",
          media_type: mediaType as "image/jpeg" | "image/png" | "image/webp",
          data,
        },
      });
    }

    if (imageBlocks.length === 0) {
      throw new Error("No valid palm images to analyse");
    }

    const contextNote = tool
      ? `Tool focus: "${tool.name}" — ${tool.description}.`
      : "";

    const userPrompt = palms.length === 2
      ? `Analyse both palms shown. Palm 1 belongs to ${palms[0].name}, Palm 2 belongs to ${palms[1].name}. ${contextNote} Provide a combined comparative reading.`
      : `Analyse the palm shown (${palms[0].name}). ${contextNote}`;

    const anthropic = new Anthropic({ apiKey: anthropicKey });

    const aiResponse = await anthropic.messages.create({
      model: "claude-opus-4-6",
      max_tokens: 4096,
      system: ANALYSIS_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            ...imageBlocks,
            { type: "text", text: userPrompt },
          ],
        },
      ],
    });

    const rawText = aiResponse.content
      .filter((b): b is Anthropic.TextBlock => b.type === "text")
      .map((b) => b.text)
      .join("");

    // Extract JSON from response
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("AI returned invalid response format");

    const result: AnalysisResult = JSON.parse(jsonMatch[0]);

    // Validate required fields
    if (
      typeof result.overall_score !== "number" ||
      !result.summary_text ||
      !Array.isArray(result.metrics)
    ) {
      throw new Error("AI response missing required fields");
    }

    // Write results atomically
    await adminClient.from("tool_sessions").update({
      status: "completed",
      overall_score: Math.min(100, Math.max(0, Math.round(result.overall_score))),
      summary_text: result.summary_text,
      result_data: {
        key_lines: result.key_lines,
        mounts: result.mounts,
        detailed_analysis: result.detailed_analysis,
      },
    }).eq("id", sessionId);

    // Insert per-category metrics
    const metrics = result.metrics.map((m) => ({
      session_id: sessionId,
      metric_name: m.metric_name,
      score: Math.min(100, Math.max(0, Math.round(m.score))),
      unit: m.unit ?? "%",
      display_order: m.display_order,
    }));
    await adminClient.from("tool_session_metrics").insert(metrics);

    // Insert locked solutions
    await adminClient.from("session_solutions").insert([
      {
        session_id: sessionId,
        solution_type: "traditional",
        content: result.traditional_advice,
        is_unlocked: false,
        credits_to_unlock: SOLUTION_UNLOCK_COST,
      },
      {
        session_id: sessionId,
        solution_type: "science_backed",
        content: result.science_backed_advice,
        is_unlocked: false,
        credits_to_unlock: SOLUTION_UNLOCK_COST,
      },
    ]);

    return jsonResponse({ session_id: sessionId, status: "completed" });
  } catch (err) {
    console.error("analyze-palm error:", err);

    // Mark session as failed — trigger will refund credits
    await adminClient
      .from("tool_sessions")
      .update({ status: "failed" })
      .eq("id", sessionId);

    return errorResponse("Analysis failed. Credits have been refunded.", 500);
  }
});
