"""HTTP Cloud Function: translate Finnish subtitle frames via Vertex AI.

Contract:
    POST /
    Headers:  Content-Type: application/json
              x-api-key: <BACKEND_API_KEY>
    Body:     {"images": ["<base64 jpeg>", ...]}
    Response: {"pairs": [{"finnish": "...", "russian": "..."}, ...]}

Deployed with the env vars GCP_PROJECT, BACKEND_API_KEY (see the deployment
command in this folder's README section of the repo).
"""

import base64
import json
import logging
import os
import time

import functions_framework
from google import genai
from google.genai import types

MODEL = "gemini-3.6-flash"

# Models confirmed (by testing against this function) to accept the
# "legacy" thinking_budget=0 knob that fully disables thinking. Newer
# generations replace it with a thinking_level enum (minimal/low/medium/
# high) and 3.6 Flash's own docs say mixing the two params 400s — so this
# is an explicit allowlist rather than a substring match on "flash", which
# would incorrectly sweep in models using the new parameter.
_SUPPORTS_THINKING_BUDGET_ZERO = {"gemini-2.5-flash", "gemini-3-flash-preview"}

# Hardcoded rather than an env var: this was previously VERTEX_LOCATION,
# but the Console's runtime-env-var value and this file's fallback default
# silently drifted apart, so a "fix" here didn't actually take effect on
# the next deploy. Region is an infrastructure choice (nearest Vertex
# region to where this function runs, europe-north1), not something that
# should vary independently of the code — so it lives here instead.
#
# Staying on "global" for now: keeping the region fixed while swapping
# models isolates the variable actually being tested. Worth trying
# europe-west4 again separately once a model is confirmed working here —
# GA models are more likely to have broader regional availability than
# the preview tier did.
VERTEX_LOCATION = "global"

PROMPT = """These images are consecutive frames captured from a Finnish TV show, each with a burned-in subtitle. For each frame:
- Extract the Finnish subtitle text exactly as shown.
- Skip frames with no readable subtitle.
- Merge duplicate or near-duplicate consecutive subtitles into a single entry.
- Translate each into Russian.

Respond with ONLY a JSON array, no markdown fences, no commentary, in this exact shape:
[{"finnish": "...", "russian": "..."}, ...]
in capture order. If no subtitles are found at all, respond with []."""

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("subtitle-translator")

# Built once per container, reused across warm invocations — constructing
# it per-request threw away that reuse and added latency to every call.
_client = genai.Client(
    vertexai=True,
    project=os.environ["GCP_PROJECT"],
    location=VERTEX_LOCATION,
)


def _strip_markdown_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        first_newline = text.find("\n")
        text = text[first_newline + 1 :] if first_newline != -1 else ""
        if text.endswith("```"):
            text = text[:-3]
    return text.strip()


@functions_framework.http
def translate(request):
    request_start = time.monotonic()

    expected_key = os.environ.get("BACKEND_API_KEY", "")
    if not expected_key or request.headers.get("x-api-key", "") != expected_key:
        return ({"error": "unauthorized"}, 401)

    if request.method != "POST":
        return ({"error": "use POST"}, 405)

    body = request.get_json(silent=True) or {}
    images = body.get("images", [])
    if not isinstance(images, list):
        return ({"error": "'images' must be a list of base64 strings"}, 400)
    if not images:
        return ({"pairs": []}, 200)

    try:
        parts = [
            types.Part.from_bytes(
                data=base64.b64decode(image), mime_type="image/jpeg"
            )
            for image in images
        ]
    except (ValueError, TypeError):
        return ({"error": "images must be valid base64"}, 400)
    parts.append(types.Part.from_text(text=PROMPT))

    config_kwargs = {
        "response_mime_type": "application/json",
        # Reading subtitle text off a photo has one correct answer.
        # Non-zero temperature lets the model "guess" a plausible but
        # wrong character (especially costly for ä/ö/å) instead of
        # reporting its most literal read — zero it out for OCR-style
        # accuracy rather than creative sampling.
        "temperature": 0,
    }
    # Disabling thinking is a pure latency win on models that support it
    # (this is deterministic extraction, not a reasoning task) — but not
    # every model accepts thinking_budget=0 (2.5 Pro 400s on it; 3.6 Flash
    # uses a different thinking_level param and 400s if both are sent), so
    # only apply it where we've confirmed it works and leave everything
    # else on its own default rather than guess.
    if MODEL in _SUPPORTS_THINKING_BUDGET_ZERO:
        config_kwargs["thinking_config"] = types.ThinkingConfig(
            thinking_budget=0
        )

    model_start = time.monotonic()
    response = _client.models.generate_content(
        model=MODEL,
        contents=[types.Content(role="user", parts=parts)],
        config=types.GenerateContentConfig(**config_kwargs),
    )
    model_elapsed = time.monotonic() - model_start

    try:
        pairs = json.loads(_strip_markdown_fences(response.text or "[]"))
    except json.JSONDecodeError:
        return ({"error": "model returned unparseable output"}, 502)
    if not isinstance(pairs, list):
        return ({"error": "model returned unexpected shape"}, 502)

    cleaned = [
        {
            "finnish": str(pair.get("finnish", "")),
            "russian": str(pair.get("russian", "")),
        }
        for pair in pairs
        if isinstance(pair, dict)
    ]

    total_elapsed = time.monotonic() - request_start
    usage = getattr(response, "usage_metadata", None)
    logger.info(
        "translate: images=%d pairs=%d model_s=%.2f total_s=%.2f "
        "prompt_tokens=%s output_tokens=%s",
        len(images),
        len(cleaned),
        model_elapsed,
        total_elapsed,
        getattr(usage, "prompt_token_count", "?"),
        getattr(usage, "candidates_token_count", "?"),
    )
    return ({"pairs": cleaned}, 200)
