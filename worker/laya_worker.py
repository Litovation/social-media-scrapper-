"""Laya tagging worker.

Pulls untagged posts (and new accounts) from Supabase, asks Laya a fixed set of
questions about each one, and writes the answers back. Laya is free and runs on
CPU, so this can run in GitHub Actions, on a laptop, or on any spare machine.

Environment:
  SUPABASE_URL        e.g. https://xxxx.supabase.co
  SUPABASE_KEY        the project's publishable (or legacy anon) key
  LAYA_WORKER_TOKEN   the worker token stored in the database (private.config)
  MAX_MINUTES         stop after this long (default 40)
  BATCH               posts per round trip (default 32)
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

POST_QUESTIONS = {
    "relevant": {
        "type": "noul",
        "instructions": "Is `post` written by a designer, design studio, creative agency, freelancer or small "
                        "business owner talking about their work, clients, craft or business?",
    },
    "purpose": {
        "type": "choice",
        "instructions": "What is `post` mainly doing?",
        "criteria": {
            "showcase": "shows finished work, a project or a portfolio piece",
            "case_study": "walks through a client problem, the process and the result",
            "process": "shows behind the scenes or how something was made",
            "tip": "teaches a lesson, tips or a how-to",
            "opinion": "shares an opinion or hot take about the industry",
            "story": "tells a personal story or journey",
            "proof": "shares results, numbers, testimonials or client wins",
            "offer": "sells a service, announces availability, pricing or a launch",
            "other": "none of these",
        },
    },
    "hook": {
        "type": "choice",
        "instructions": "How does the first line of `post` grab attention?",
        "criteria": {
            "number_list": "promises a numbered list, like 5 tips or 3 mistakes",
            "question": "opens with a question",
            "bold_claim": "opens with a bold or surprising claim",
            "contrarian": "goes against common advice",
            "result_first": "leads with a result, number or money figure",
            "story": "opens a personal story",
            "before_after": "shows a before and after",
            "how_to": "promises to show how to do something",
            "announcement": "announces something new",
            "plain": "no clear hook, just a caption",
        },
    },
    "subject": {
        "type": "choice",
        "instructions": "What is `post` about?",
        "criteria": {
            "branding": "brand identity, logos or brand strategy",
            "ui_ux": "app or product UI and UX",
            "web": "websites and landing pages",
            "motion": "motion design, animation or video",
            "illustration": "illustration, graphics or typography",
            "ai": "AI tools in design",
            "business": "pricing, clients, sales or running a studio",
            "tools": "design tools and workflow",
            "other": "something else",
        },
    },
    "has_cta": {
        "type": "noul",
        "instructions": "Does `post` ask the reader to act, like DM, book a call, visit a link, comment or follow?",
    },
    "specificity": {
        "type": "score",
        "instructions": "How specific and concrete is `post`?",
        "criteria": [
            "vague and generic",
            "a little specific",
            "specific with real details",
            "very specific with numbers, names or examples",
        ],
    },
    "slop": {
        "type": "noul",
        "instructions": "Does `post` read like generic AI-written filler with no real specifics or personal voice?",
    },
}

ACCOUNT_QUESTIONS = {
    "relevant": {
        "type": "noul",
        "instructions": "Is `profile` a design agency, design studio, freelance designer, creative consultant "
                        "or business owner who sells creative or design services?",
    },
    "kind": {
        "type": "choice",
        "instructions": "Which best describes `profile`?",
        "criteria": {
            "agency": "a design or creative agency or studio with a team",
            "freelancer": "a solo designer or freelancer",
            "creator": "a design educator or content creator",
            "business": "a founder or business owner outside design",
            "other": "none of these",
        },
    },
}


class Supabase:
    def __init__(self, url: str, key: str, token: str):
        self.base = url.rstrip("/") + "/rest/v1/rpc/"
        self.headers = {"apikey": key, "Content-Type": "application/json"}
        if not key.startswith("sb_"):
            self.headers["Authorization"] = f"Bearer {key}"  # legacy JWT anon key
        self.token = token

    def rpc(self, name: str, payload: dict):
        body = json.dumps({"p_token": self.token, **payload}).encode()
        req = urllib.request.Request(self.base + name, data=body, headers=self.headers, method="POST")
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as res:
                    return json.loads(res.read() or b"null")
            except urllib.error.HTTPError as e:
                detail = e.read().decode(errors="replace")[:300]
                if e.code < 500 or attempt == 3:
                    raise RuntimeError(f"{name} failed ({e.code}): {detail}") from None
            except urllib.error.URLError:
                if attempt == 3:
                    raise
            time.sleep(2 ** attempt)


def answer(ans: dict, q: str):
    a = (ans or {}).get(q) or {}
    t = a.get("type")
    if t == "noul":
        return a.get("noul")
    if t == "choice":
        return a.get("choice")
    if t == "score":
        return a.get("score")
    return None


def slim(ans: dict) -> dict:
    """Keep answers and confidences, drop bulky extras."""
    out = {}
    for k, a in (ans or {}).items():
        out[k] = {x: a.get(x) for x in ("choice", "noul", "score", "answer_confidence", "probabilities") if x in a}
    return out


def main() -> int:
    url, key, token = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_KEY"), os.environ.get("LAYA_WORKER_TOKEN")
    if not (url and key and token):
        print("Set SUPABASE_URL, SUPABASE_KEY and LAYA_WORKER_TOKEN first.", file=sys.stderr)
        return 2
    max_seconds = float(os.environ.get("MAX_MINUTES", "40")) * 60
    batch = int(os.environ.get("BATCH", "32"))
    started = time.time()
    db = Supabase(url, key, token)

    print("Loading Laya (first run downloads the model, ~1-3 minutes)...", flush=True)
    from laya import Router  # imported late so config errors show up fast

    router = Router()
    model_name = "laya"
    tagged = accounts = 0

    # Reserve time for discovered profiles before a large post backlog.
    profile_budget = max_seconds if os.environ.get("LAYA_MODE") == "accounts" else min(max_seconds * 0.2, 300)
    while time.time() - started < profile_budget:
        rows = db.rpc("laya_next_accounts", {"p_limit": batch}) or []
        if not rows:
            break
        reqs = [{"state": {"profile": r["profile"]}, "questions": ACCOUNT_QUESTIONS} for r in rows]
        results = router.predict_batch(reqs, batch_size=8, sort_by_length=True)
        out = []
        for r, res in zip(rows, results):
            ans = (res or {}).get("answers", {})
            out.append({"id": r["id"], "relevance": answer(ans, "relevant"), "kind": answer(ans, "kind")})
        accounts += db.rpc("laya_save_accounts", {"p_rows": out}) or 0
        print(f"classified {accounts} accounts", flush=True)

    # Posts use the remaining budget.
    while os.environ.get("LAYA_MODE") != "accounts" and time.time() - started < max_seconds:
        rows = db.rpc("laya_next_posts", {"p_limit": batch}) or []
        if not rows:
            break
        reqs = [{"state": {"post": r["text"]}, "questions": POST_QUESTIONS} for r in rows]
        results = router.predict_batch(reqs, batch_size=8, sort_by_length=True)
        out = []
        for r, res in zip(rows, results):
            ans = (res or {}).get("answers", {})
            model_name = ((res or {}).get("routing") or {}).get("model", model_name)
            out.append({
                "post_id": r["id"],
                "relevant": answer(ans, "relevant"),
                "purpose": answer(ans, "purpose"),
                "hook": answer(ans, "hook"),
                "subject": answer(ans, "subject"),
                "has_cta": answer(ans, "has_cta"),
                "specificity": answer(ans, "specificity"),
                "slop": answer(ans, "slop"),
                "answers": slim(ans),
                "model": f"laya:{model_name}",
            })
        tagged += db.rpc("laya_save_tags", {"p_rows": out}) or 0
        print(f"tagged {tagged} posts ({time.time() - started:.0f}s)", flush=True)

    print(f"Done: {tagged} posts tagged, {accounts} accounts classified in {time.time() - started:.0f}s.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
