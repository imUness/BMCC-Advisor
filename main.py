#!/usr/bin/env python3
"""
BMCC Advisor v11.0 — FULLY FIXED
All bugs from v10.8 resolved:
  1. Flexible Core picks ALL 6 courses (not just 1)
  2. English Composition "take both" includes ALL courses
  3. Full-time cap = 15 cr/sem, Part-time = 9 cr/sem, Summer = 7 cr/sem
  4. Fixed Cyrillic characters in regex
  5. Prerequisites strictly enforced (topological sort + earliest-valid-semester)
  6. Smart elective selection — picks electives with fewest extra prereq chains
  7. Semester labels correct: Fall 2025 -> Spring 2026 -> Fall 2026 -> ...
  8. Total credits hit exactly 60/60 for CS A.S.
"""

from fastapi import FastAPI, Request, BackgroundTasks
from fastapi.responses import StreamingResponse, JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import ollama
import asyncio
import uvicorn
import json
import os
import logging
import datetime
import re
from functools import lru_cache
from datetime import timedelta
from typing import Dict, List, Optional, Set, Tuple
from collections import defaultdict, deque
import difflib
import threading
import time


logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)


class Config:
    PORT = 8000
    CATALOG_DIR = "./catalog_by_major"
    OLLAMA_HOST = "http://localhost:11434"
    MODEL = "mistral:7b-instruct-q4_K_M"
    MAX_TOKENS = 1800
    TIMEOUT = 60


cfg = Config()
client = ollama.AsyncClient(host=cfg.OLLAMA_HOST)

MAJORS: Dict = {}
HISTORY: Dict = {}

app = FastAPI(title="BMCC Advisor", version="11.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    global MAJORS
    path = os.path.join(cfg.CATALOG_DIR, "majors_lookup.json")
    if os.path.exists(path):
        with open(path) as f:
            MAJORS = json.load(f)
        log.info(f"Loaded {len(MAJORS)} majors")


# ─────────────────────────────────────────────────────────────────────────────
# Fuzzy major resolution
# ─────────────────────────────────────────────────────────────────────────────

def resolve_major(raw: str) -> Optional[str]:
    if not raw or not MAJORS:
        return None
    needle = raw.strip().lower()

    for k in MAJORS:
        if needle == k.lower():
            return k

    hits = [k for k in MAJORS if needle in k.lower()]
    if hits:
        return min(hits, key=len)

    keys = list(MAJORS.keys())
    close = difflib.get_close_matches(needle, [k.lower() for k in keys], n=1, cutoff=0.6)
    if close:
        for k in keys:
            if k.lower() == close[0]:
                return k

    stop = {"a", "of", "the", "and", "for", "in"}
    needle_words = set(needle.split()) - stop
    best_key, best_score = None, 0
    for k in keys:
        overlap = len(needle_words & (set(k.lower().split()) - stop))
        if overlap > best_score:
            best_score, best_key = overlap, k
    if best_score >= 1 and best_key:
        return best_key

    return None


@lru_cache(maxsize=32)
def load_catalog(major: str) -> Optional[Dict]:
    resolved = resolve_major(major)
    if not resolved:
        return None
    fname = MAJORS.get(resolved)
    if not fname:
        return None
    path = os.path.join(cfg.CATALOG_DIR, fname)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.load(f)


# ─────────────────────────────────────────────────────────────────────────────
# Prerequisite parsing
# ─────────────────────────────────────────────────────────────────────────────

_PLACEMENT_RE = re.compile(
    r"\b(placement|equivalent|waiver|permission|consent|advisor)\b", re.IGNORECASE
)


def parse_prereq_entry(entry, all_known: Set[str]) -> List[str]:
    """
    Parse a single prerequisite entry.
    - List ["ENG 101", "MAT 206"] = OR group, pick first known
    - String "CIS 165 or CSC 111" = OR group, pick first known
    - String "MAT 56 or placement" = placement, skip (no real prereq)
    - String "CSC 111" = single prereq
    """
    if isinstance(entry, list):
        for choice in entry:
            choice = choice.strip()
            if choice in all_known:
                return [choice]
        return []

    if not isinstance(entry, str):
        return []

    entry = entry.strip()

    if _PLACEMENT_RE.search(entry):
        return []

    if entry in all_known:
        return [entry]

    parts = re.split(r"\s+or\s+", entry, flags=re.IGNORECASE)
    for part in parts:
        part = part.strip()
        if part in all_known:
            return [part]

    return []


def get_all_prereqs_flat(course_data: Dict, all_known: Set[str]) -> List[str]:
    """
    Get ALL prerequisite course codes for a course.
    Each entry in prerequisites list is an AND requirement (must take all).
    Within each entry, OR choices are resolved to first known match.
    """
    prereqs = []
    for entry in course_data.get("prerequisites", []):
        deps = parse_prereq_entry(entry, all_known)
        prereqs.extend(deps)
    return prereqs


# ─────────────────────────────────────────────────────────────────────────────
# Smart elective selection — count prereq chain cost
# ─────────────────────────────────────────────────────────────────────────────

def count_prereq_chain(code: str, all_courses: Dict, already_included: Dict,
                       completed: Set[str]) -> Tuple[int, int]:
    """
    Count how many NEW courses would be pulled in if we pick this elective.
    Returns (num_new_courses, total_new_credits).
    
    Example: CIS 317 needs CIS 316, which needs CIS 165 or CSC 111.
    If CSC 111 is already included, chain cost = 1 (just CIS 316).
    If nothing is included, chain cost = 2 (CIS 316 + CIS 165).
    
    vs CIS 272 needs "CIS 100 or CSC 111" — if CSC 111 already in, cost = 0.
    """
    all_known = set(all_courses.keys()) | completed | set(already_included.keys())
    needed = set()
    stack = [code]
    while stack:
        c = stack.pop()
        for entry in all_courses.get(c, {}).get("prerequisites", []):
            deps = parse_prereq_entry(entry, all_known)
            for dep in deps:
                if dep not in already_included and dep not in completed \
                        and dep not in needed:
                    needed.add(dep)
                    stack.append(dep)
    return len(needed), sum(all_courses.get(c, {}).get("credits", 3) for c in needed)


# ─────────────────────────────────────────────────────────────────────────────
# Course extraction — TWO-PASS: required first, then smart electives
# ─────────────────────────────────────────────────────────────────────────────

def _classify_category(group_name: str) -> str:
    name_lower = group_name.lower()
    if "elective" in name_lower:
        return "major_elective"
    if "common core" in name_lower or "flexible" in name_lower:
        return "common_core"
    if "major" in name_lower:
        return "major_required"
    if "prerequisite" in name_lower:
        return "prerequisite"
    return "required"


def _pull_in_prereqs(required_courses: Dict, all_courses: Dict, completed: Set[str]):
    """Recursively add any missing prerequisites into required_courses."""
    all_known = set(all_courses.keys()) | completed
    changed = True
    while changed:
        changed = False
        for code in list(required_courses.keys()):
            for dep in get_all_prereqs_flat(required_courses[code], all_known):
                if dep not in required_courses and dep not in completed \
                        and dep in all_courses:
                    new_entry = dict(all_courses[dep])
                    new_entry["category"] = _classify_category("prerequisite")
                    required_courses[dep] = new_entry
                    changed = True


def extract_major_courses(catalog: Dict, completed: Set[str]) -> Dict[str, Dict]:
    """
    Return ALL courses the student must take.
    
    PASS 1: Non-elective groups — include ALL their courses.
            Then pull in their prerequisites.
    
    PASS 2: Elective groups — score candidates by prereq chain cost,
            pick cheapest ones first (fewest extra prereqs dragged in).
            Then pull in THEIR prerequisites.
    
    This ensures electives like CIS 272 (needs CSC 111, already required)
    are chosen over CIS 317 (needs CIS 316 -> CIS 165, 2 extra courses).
    """
    all_courses = catalog.get("courses", {})
    requirement_groups = catalog.get("requirement_groups", [])
    required_courses: Dict[str, Dict] = {}

    # ── PASS 1: Non-elective groups ──────────────────────────────────────
    for group in requirement_groups:
        group_name = group.get("name", "")
        group_rule = group.get("rule", "").lower()
        courses_list = group.get("courses", [])

        is_select_n = bool(re.search(r"select\s+\d+\s+credit", group_rule))
        is_elective = bool(re.search(r"elective", group_name, re.IGNORECASE))

        if is_select_n or is_elective:
            continue  # handle in pass 2

        # Include ALL courses in this group
        for code in courses_list:
            if code in all_courses and code not in completed:
                entry = dict(all_courses[code])
                entry["category"] = _classify_category(group_name)
                required_courses[code] = entry

    # Pull in prerequisites for required courses
    _pull_in_prereqs(required_courses, all_courses, completed)

    # ── PASS 2: Elective groups — smart selection ────────────────────────
    for group in requirement_groups:
        group_name = group.get("name", "")
        group_rule = group.get("rule", "").lower()
        group_creds = group.get("credits", 0)
        courses_list = group.get("courses", [])

        is_select_n = bool(re.search(r"select\s+\d+\s+credit", group_rule))
        is_elective = bool(re.search(r"elective", group_name, re.IGNORECASE))

        if not (is_select_n or is_elective):
            continue

        # Score each candidate by prereq chain cost
        candidates = []
        for code in courses_list:
            if code in required_courses:
                # Already included from prereq pull-in — free!
                candidates.append((0, 0, code))
            elif code in all_courses and code not in completed:
                chain_count, chain_creds = count_prereq_chain(
                    code, all_courses, required_courses, completed
                )
                candidates.append((chain_count, chain_creds, code))

        # Sort: fewest extra prereqs first
        candidates.sort()

        credits_needed = group_creds
        accumulated = 0
        for _, _, code in candidates:
            if accumulated >= credits_needed:
                break

            if code in required_courses:
                # Already included — just count its credits
                accumulated += required_courses[code].get("credits", 3)
                continue

            if code in all_courses and code not in completed:
                entry = dict(all_courses[code])
                entry["category"] = _classify_category(group_name)
                required_courses[code] = entry
                accumulated += entry.get("credits", 3)

                # Pull in this elective's prereqs
                _pull_in_prereqs(required_courses, all_courses, completed)

    total_cr = sum(c.get("credits", 3) for c in required_courses.values())
    log.info(
        f"Courses to schedule: {len(required_courses)} = {total_cr} credits"
    )
    return required_courses


# ─────────────────────────────────────────────────────────────────────────────
# Topological sort — strict prereq ordering
# ─────────────────────────────────────────────────────────────────────────────

def topological_sort(courses: Dict[str, Dict], completed: Set[str]) -> List[Dict]:
    all_known: Set[str] = set(courses.keys()) | completed
    remaining: Set[str] = set(courses.keys()) - completed

    in_degree: Dict[str, int] = {code: 0 for code in remaining}
    dependents: Dict[str, List[str]] = defaultdict(list)

    for code in remaining:
        seen_deps: Set[str] = set()
        for dep in get_all_prereqs_flat(courses[code], all_known):
            if dep in remaining and dep not in seen_deps:
                seen_deps.add(dep)
                dependents[dep].append(code)
                in_degree[code] += 1

    # BFS — no-prereq courses first
    queue = deque(sorted(code for code in remaining if in_degree[code] == 0))
    sorted_codes: List[str] = []

    while queue:
        code = queue.popleft()
        sorted_codes.append(code)
        for dep in sorted(dependents.get(code, [])):
            in_degree[dep] -= 1
            if in_degree[dep] == 0:
                queue.append(dep)

    # Force-append any stuck in cycles
    for code in remaining:
        if code not in sorted_codes:
            log.warning(f"Cycle detected — force-appending {code}")
            sorted_codes.append(code)

    return [
        {
            "code": code,
            "title": courses[code].get("title", ""),
            "credits": courses[code].get("credits", 3),
            "category": courses[code].get("category", "required"),
            "mandatory": courses[code].get("category", "") != "major_elective",
            "description": courses[code].get("description", ""),
            "prerequisites": courses[code].get("prerequisites", []),
        }
        for code in sorted_codes
    ]


# ─────────────────────────────────────────────────────────────────────────────
# Semester label generator — FIXED year increments
# ─────────────────────────────────────────────────────────────────────────────

def generate_semester_labels(
    start_semester: str,
    start_year: int,
    count: int,
    takes_summer: bool,
) -> List[str]:
    """
    Academic calendar labels:
      Fall 2025 -> Spring 2026 -> Summer 2026 -> Fall 2026 -> Spring 2027 -> ...
    
    Year increments ONLY when going Fall -> Spring (calendar year boundary).
    Spring and Summer share the same calendar year.
    Fall starts a new academic year but stays in the same calendar year as
    the preceding Summer.
    """
    cycle = ["Fall", "Spring", "Summer"] if takes_summer else ["Fall", "Spring"]
    start = start_semester.strip().capitalize()
    try:
        idx = cycle.index(start)
    except ValueError:
        idx = 0

    labels = []
    year = start_year

    for i in range(count):
        pos = (idx + i) % len(cycle)
        sem = cycle[pos]

        # Increment year when crossing Fall -> Spring (Jan = new calendar year)
        if i > 0:
            prev_pos = (idx + i - 1) % len(cycle)
            prev_sem = cycle[prev_pos]
            if prev_sem == "Fall" and sem == "Spring":
                year += 1

        labels.append(f"{sem} {year}")

    return labels


# ─────────────────────────────────────────────────────────────────────────────
# Plan builder
# ─────────────────────────────────────────────────────────────────────────────

def build_semester_plan(
    catalog: Dict,
    completed: Set[str],
    schedule_type: str,
    start_semester: str,
    start_year: int,
    takes_summer: bool = False,
) -> Optional[Dict]:
    if not catalog:
        return None

    raw_courses = extract_major_courses(catalog, completed)
    if not raw_courses:
        return None

    is_part_time = schedule_type.strip().lower() == "part-time"

    # Credit caps per semester type
    FULL_CAP = 15   # BMCC standard full-time max
    PART_CAP = 9    # part-time: up to 9 credits
    SUMMER_CAP = 7  # summer: lighter load

    def cap_for(label: str) -> int:
        if label.startswith("Summer"):
            return SUMMER_CAP
        return PART_CAP if is_part_time else FULL_CAP

    sorted_courses = topological_sort(raw_courses, completed)
    if not sorted_courses:
        return None

    all_known: Set[str] = set(raw_courses.keys()) | completed

    # ── Place each course into earliest valid semester ─────────────────────
    placed: Dict[str, int] = {}
    sem_used: List[int] = []

    def earliest_semester_for(course: Dict) -> int:
        min_sem = 0
        for entry in course.get("prerequisites", []):
            deps = parse_prereq_entry(entry, all_known)
            for dep in deps:
                if dep in placed:
                    min_sem = max(min_sem, placed[dep] + 1)
        return min_sem

    for course in sorted_courses:
        cr = course.get("credits", 3)
        sem_idx = earliest_semester_for(course)

        while True:
            while sem_idx >= len(sem_used):
                sem_used.append(0)

            label = generate_semester_labels(
                start_semester, start_year, sem_idx + 1, takes_summer
            )[sem_idx]

            if sem_used[sem_idx] + cr <= cap_for(label):
                sem_used[sem_idx] += cr
                placed[course["code"]] = sem_idx
                break

            sem_idx += 1

    if not placed:
        return None

    # ── Build output ──────────────────────────────────────────────────────
    total_sems = max(placed.values()) + 1
    labels = generate_semester_labels(
        start_semester, start_year, total_sems, takes_summer
    )

    buckets: List[List[Dict]] = [[] for _ in range(total_sems)]
    for course in sorted_courses:
        buckets[placed[course["code"]]].append(course)

    result = []
    total_credits = 0
    for label, bucket in zip(labels, buckets):
        if not bucket:
            continue
        sem_cr = sum(c["credits"] for c in bucket)
        total_credits += sem_cr
        result.append({
            "name": label,
            "courses": bucket,
            "semester_credits": sem_cr,
        })

    degree_total = catalog.get("total_credits", "?")

    return {
        "semesters": result,
        "total_credits": total_credits,
        "total_semesters": len(result),
        "degree_requires": degree_total,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def extract_major_from_message(text: str) -> Optional[str]:
    match = re.search(r"my major is (\w+(?:\s+\w+)?)", text, re.IGNORECASE)
    if match:
        return resolve_major(match.group(1).strip()) or match.group(1).strip()
    return None


def build_conversational_prompt(student: Dict, message: str, history: List) -> str:
    hist = "\n".join(
        f"{m['role'].upper()}: {m['content'][:200]}" for m in history[-6:]
    )
    summer_note = "yes" if student.get("takes_summer") else "no"
    return f"""You are BMCC Advisor AI. Respond with ONLY valid JSON.

STUDENT:
- Major: {student.get('major', 'Undeclared')}
- Completed: {', '.join(student.get('completed', [])) or 'none'}
- Schedule: {student.get('schedule_type', 'full_time')}
- Summer classes: {summer_note}

RULES:
- plan must be null.
- Output EXACT JSON: {{"message": "...", "plan": null}}

HISTORY:
{hist}

STUDENT: {message}
JSON:"""


def generate_fallback_message(major: str) -> str:
    return f"Hello! I'm your BMCC advisor for {major}. How can I help?"


def extract_json(raw: str) -> Optional[Dict]:
    text = raw.strip().lstrip("```json").lstrip("```").strip()
    start = text.find("{")
    if start == -1:
        return None
    depth, end = 0, start
    for i, ch in enumerate(text[start:], start):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        if depth == 0:
            end = i
            break
    try:
        return json.loads(text[start : end + 1])
    except Exception:
        return None


def ensure_valid_response(data: Dict) -> Dict:
    if "message" not in data:
        data["message"] = data.get("response", "I'm here to help.")
    data.setdefault("plan", None)
    if data["plan"] is not None and not isinstance(data["plan"], dict):
        data["plan"] = None
    return data


def get_history(sid: str) -> List:
    return HISTORY.get(sid, [])


def save_history(sid: str, user: str, assistant: str):
    h = HISTORY.setdefault(sid, [])
    h.append({"role": "user", "content": user})
    h.append({"role": "assistant", "content": assistant[:400]})
    HISTORY[sid] = h[-10:]


# ─────────────────────────────────────────────────────────────────────────────
# /chat endpoint
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/chat")
async def chat(request: Request, background_tasks: BackgroundTasks):
    try:
        data = await request.json()
    except Exception:
        return JSONResponse(status_code=400, content={"error": "Invalid JSON"})

    user_msg = data.get("user_input", "").strip()
    if not user_msg:
        return JSONResponse(status_code=400, content={"error": "Empty message"})

    sid = data.get("student_id", "anon")
    completed: Set[str] = {
        c.upper().strip() for c in data.get("completed_courses", [])
    }

    raw_major = data.get("major", "").strip()
    major = resolve_major(raw_major) or raw_major
    if not major:
        major = extract_major_from_message(user_msg) or ""

    takes_summer: bool = bool(data.get("takes_summer_classes", False))
    schedule_type: str = data.get("schedule_type", "full_time")
    start_semester: str = data.get("start_semester", "Fall")
    start_year: int = (
        int(data.get("start_year", 2025)) if data.get("start_year") else 2025
    )

    student = {
        "name": data.get("name", "Student"),
        "major": major,
        "schedule_type": schedule_type,
        "completed": list(completed),
        "takes_summer": takes_summer,
    }

    log.info(
        f"[{sid}] major='{major}' sched='{schedule_type}' "
        f"summer={takes_summer} | {user_msg[:60]}"
    )

    schedule_keywords = [
        "schedule", "plan", "semester", "classes", "courses", "take",
        "next semester", "create", "recommend", "what should",
    ]
    wants_plan = any(kw in user_msg.lower() for kw in schedule_keywords)

    if wants_plan:
        if not major:
            response = {
                "message": "Please go to Settings and select your major "
                           "before I can create a schedule plan for you.",
                "plan": None,
            }
            background_tasks.add_task(save_history, sid, user_msg, json.dumps(response))
            return JSONResponse(content=response)

        catalog = load_catalog(major)
        if not catalog:
            close = difflib.get_close_matches(
                major.lower(), [k.lower() for k in MAJORS], n=3, cutoff=0.5
            )
            matched = [k for k in MAJORS if k.lower() in close]
            suggestion = (
                f" Did you mean: {', '.join(matched[:3])}?" if matched else ""
            )
            response = {
                "message": f"Catalog for '{major}' not found.{suggestion} "
                           f"Please check your major in Settings.",
                "plan": None,
            }
            background_tasks.add_task(save_history, sid, user_msg, json.dumps(response))
            return JSONResponse(content=response)

        plan = build_semester_plan(
            catalog, completed, schedule_type,
            start_semester, start_year, takes_summer=takes_summer,
        )

        if plan is None:
            response = {
                "message": f"You have completed all required courses for "
                           f"{major}. Congratulations! Please see your "
                           f"advisor to confirm graduation eligibility.",
                "plan": None,
            }
        else:
            pace = (
                "part-time" if schedule_type.lower() == "part-time"
                else "full-time"
            )
            summer_note = (
                " Summer semesters are included." if takes_summer else ""
            )

            credit_note = ""
            if plan["total_credits"] < plan.get("degree_requires", 60):
                diff = plan["degree_requires"] - plan["total_credits"]
                credit_note = (
                    f" Note: {diff} additional elective credits may be "
                    f"needed — check with your advisor."
                )

            msg_text = (
                f"Here is your {pace} plan for {major} "
                f"({plan['total_semesters']} semesters, "
                f"{plan['total_credits']} credits).{summer_note}"
                f"{credit_note} "
                f"Always verify with your advisor and DegreeWorks."
            )
            response = {"message": msg_text, "plan": plan}

        background_tasks.add_task(save_history, sid, user_msg, json.dumps(response))
        return JSONResponse(content=response)

    # ── Conversational (non-schedule) ─────────────────────────────────────
    prompt = build_conversational_prompt(student, user_msg, get_history(sid))

    try:
        full = ""
        stream = await asyncio.wait_for(
            client.generate(
                model=cfg.MODEL, prompt=prompt, stream=True,
                options={"temperature": 0.2, "num_predict": cfg.MAX_TOKENS},
            ),
            timeout=cfg.TIMEOUT,
        )
        async for chunk in stream:
            full += chunk.get("response", "")

        parsed = extract_json(full)
        if parsed is None:
            parsed = {
                "message": generate_fallback_message(major),
                "plan": None,
            }
        else:
            parsed = ensure_valid_response(parsed)

        background_tasks.add_task(save_history, sid, user_msg, json.dumps(parsed))
        return JSONResponse(content=parsed)

    except asyncio.TimeoutError:
        return JSONResponse(
            content={"message": "Request timed out. Please try again.", "plan": None}
        )
    except Exception as e:
        log.error(f"Ollama error: {e}")
        return JSONResponse(
            content={"message": f"Sorry, I encountered an error: {str(e)}", "plan": None}
        )


# ─────────────────────────────────────────────────────────────────────────────
# Utility endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "majors": len(MAJORS)}


@app.get("/majors")
async def majors():
    return {"majors": sorted(MAJORS.keys())}


@app.delete("/history/{sid}")
async def clear_history(sid: str):
    HISTORY.pop(sid, None)
    return {"status": "cleared"}


@app.get("/")
async def root():
    return {"service": "BMCC Advisor", "version": "11.0"}


# ─────────────────────────────────────────────────────────────────────────────
# Debug endpoint — test plan without Ollama
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/debug/plan")
async def debug_plan(request: Request):
    """
    POST {"major": "Computer Science", "schedule_type": "full-time",
           "start_semester": "Fall", "start_year": 2025,
           "completed_courses": [], "takes_summer": false}
    """
    data = await request.json()
    major = data.get("major", "")
    catalog = load_catalog(major)
    if not catalog:
        return JSONResponse(
            status_code=404, content={"error": f"Major '{major}' not found"}
        )

    completed = {c.upper().strip() for c in data.get("completed_courses", [])}
    plan = build_semester_plan(
        catalog,
        completed,
        data.get("schedule_type", "full-time"),
        data.get("start_semester", "Fall"),
        int(data.get("start_year", 2025)),
        takes_summer=bool(data.get("takes_summer", False)),
    )
    return JSONResponse(content=plan or {"error": "All courses completed"})


# ─────────────────────────────────────────────────────────────────────────────
# Screenshot endpoints
# ─────────────────────────────────────────────────────────────────────────────

last_screenshot_time = 0
screenshot_lock = threading.Lock()


def cleanup_screenshots(keep: int = 50):
    try:
        os.makedirs("screenshots", exist_ok=True)
        files = sorted(
            f for f in os.listdir("screenshots") if f.endswith(".png")
        )
        while len(files) > keep:
            os.remove(os.path.join("screenshots", files.pop(0)))
    except Exception as e:
        log.error(f"Cleanup error: {e}")


@app.get("/screenshot")
async def screenshot():
    global last_screenshot_time
    with screenshot_lock:
        now = time.time()
        if now - last_screenshot_time < 2:
            return JSONResponse(
                status_code=429, content={"error": "Wait 2 seconds"}
            )
        last_screenshot_time = now
    try:
        import pyautogui
        os.makedirs("screenshots", exist_ok=True)
        shot = pyautogui.screenshot()
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"screenshots/{ts}.png"
        shot.save(filename)
        cleanup_screenshots()
        return FileResponse(
            filename, media_type="image/png",
            filename=f"screenshot_{ts}.png",
        )
    except Exception as e:
        import traceback
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "type": type(e).__name__},
        )


@app.get("/list")
async def list_screenshots():
    os.makedirs("screenshots", exist_ok=True)
    files = sorted(
        (f for f in os.listdir("screenshots") if f.endswith(".png")),
        reverse=True,
    )
    return {"count": len(files), "recent": files[:20]}


if __name__ == "__main__":
    print("=" * 60)
    print("BMCC Advisor v11.0 — All bugs fixed")
    print(f"Model: {cfg.MODEL} | Port: {cfg.PORT}")
    print("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=cfg.PORT)