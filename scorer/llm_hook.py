"""Optional language-model note. Disabled unless a caller opts in.

The default scorer never imports a network client. Tests monkeypatch the socket
opener below and fail if a default score touches it.
"""

from __future__ import annotations

import json
import urllib.request


def llm_note(summary: str, *, enabled: bool = False, url: str | None = None, timeout: float = 2.0) -> str | None:
    """Return None when disabled. A URL is required before any request is attempted."""
    if not enabled:
        return None
    if not url:
        return "llm-hook-skipped-no-url"
    body = json.dumps({"summary": summary}).encode()
    request = urllib.request.Request(
        url,
        data=body,
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode()
