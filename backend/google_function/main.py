"""HTTP Cloud Function: translate Finnish subtitle frames via Vertex AI.

Contract:
    POST /
    Headers:  Content-Type: application/json
              x-api-key: <BACKEND_API_KEY>
    Body:     {"images": ["<base64 jpeg>", ...]}
    Response: {"pairs": [{"finnish": "...", "russian": "..."}, ...]}

Deployed with the env vars GCP_PROJECT, VERTEX_LOCATION, BACKEND_API_KEY
(see the deployment command in this folder's README section of the repo).
"""

import base64
import json
import os

import functions_framework
from google import genai
from google.genai import types

MODEL = "gemini-2.5-flash"

PROMPT = """These images are consecutive frames captured from a Finnish TV show, each with a burned-in subtitle. For each frame:
- Extract the Finnish subtitle text exactly as shown.
- Skip frames with no readable subtitle.
- Merge duplicate or near-duplicate consecutive subtitles into a single entry.
- Translate each into Russian.

Respond with ONLY a JSON array, no markdown fences, no commentary, in this exact shape:
[{"finnish": "...", "russian": "..."}, ...]
in capture order. If no subtitles are found at all, respond with []."""


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

    client = genai.Client(
        vertexai=True,
        project=os.environ["GCP_PROJECT"],
        location=os.environ.get("VERTEX_LOCATION", "global"),
    )
    response = client.models.generate_content(
        model=MODEL,
        contents=[types.Content(role="user", parts=parts)],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
        ),
    )

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
    return ({"pairs": cleaned}, 200)
