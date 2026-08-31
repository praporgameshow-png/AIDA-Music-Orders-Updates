# AIDA Music Orders v1.0.4 Direct MiniChat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate `AIDA MiniChat Bridge` so `AIDA MUSIC` rewards from VK Video Live go directly from MiniChat to the existing AIDA Music Orders API, with chat replies, deduplication, and a release-gated refund path, without requiring Streamer.bot for music ordering.

**Architecture:** Keep the proven v1.0.3 AIDA Music Orders EXE untouched. Add a separate lightweight Windows bridge process that connects to MiniChat WebSocket `ws://127.0.0.1:4848/Chat`, parses only the configured reward, posts accepted requests to `http://127.0.0.1:18765/api/order`, replies through MiniChat, and uses a verified refund protocol captured in Task 1. The bridge is packaged as a standalone EXE and launched beside AIDA.

**Tech Stack:** Python 3.11, stdlib (`json`, `sqlite3`, `hashlib`, `logging`, `threading`, `time`, `pathlib`), `websocket-client`, `requests`, `pytest`, `PyInstaller`.

**Spec:** `docs/superpowers/specs/2026-08-31-aida-music-v1.0.4-direct-minichat-design.md`

## Global Constraints

- Do not modify or patch the proven v1.0.3 AIDA Music Orders EXE.
- Keep AIDA order API at `http://127.0.0.1:18765/api/order`.
- Keep OBS player URL unchanged: `http://127.0.0.1:18765/player?client=obs`.
- MiniChat default socket is `ws://127.0.0.1:4848/Chat`, but config must allow changing it.
- Reward name defaults to `AIDA MUSIC` and is matched case-insensitively after whitespace normalization.
- CUSTOMER keeps 48-hour trial and existing licensing.
- OWNER never uses CUSTOMER trial/license enforcement.
- Release v1.0.4 only if a real VK Video Live test proves refund of rejected reward points without Streamer.bot.
- Idle implementation must use one WebSocket connection and no polling loops except reconnect/backoff.
- Old Streamer.bot trigger is not deleted automatically; release instructions tell users to disable it.

---

## File Structure

Create these focused units:

```text
bridge/
  __init__.py
  config.py              # config schema/load
  models.py              # RewardEvent, OrderResult
  parser.py              # MiniChat reward/url parser
  dedupe.py              # SQLite TTL cache
  aida_client.py         # local AIDA HTTP client
  minichat_client.py     # WebSocket receive/send/reconnect
  refund.py              # verified refund protocol adapter
  service.py             # orchestration only
  main.py                # CLI entrypoint
  bridge_config.json
  requirements.txt
  AIDA_MiniChat_Bridge.spec
  tools/
    capture_minichat.py   # protocol diagnostic tool
    probe_refund.py       # controlled refund probe using captured protocol

tests/
  bridge/
    fixtures/
      reward_youtube.json
      reward_vkvideo.json
      reward_yandex.json
      reward_no_link.json
    test_config.py
    test_parser.py
    test_dedupe.py
    test_aida_client.py
    test_minichat_client.py
    test_refund.py
    test_service.py

docs/protocols/
  minichat-vkvideolive-reward.md
  minichat-vkvideolive-refund.json

packaging/
  START_AIDA_OWNER.cmd
  START_AIDA_CUSTOMER.cmd
  README_v1.0.4.txt
```

The refund JSON file is not a placeholder: Task 1 must populate it from a verified real protocol before Task 6 is allowed to start.

---

### Task 1: Prove the VK reward/refund protocol

**Files:**
- Create: `bridge/tools/capture_minichat.py`
- Create: `bridge/tools/probe_refund.py`
- Create: `docs/protocols/minichat-vkvideolive-reward.md`
- Create: `docs/protocols/minichat-vkvideolive-refund.json`
- Test: `tests/bridge/test_minichat_client.py`

**Interfaces:**
- Produces: a redacted real reward fixture and an exact verified refund payload template in `docs/protocols/minichat-vkvideolive-refund.json`.
- Release gate: if no direct MiniChat refund path can be proven with Streamer.bot closed, STOP this plan after Task 1 and keep v1.0.3 as the store version.

- [ ] **Step 1: Write a failing frame-capture test**

```python
# tests/bridge/test_minichat_client.py
from bridge.tools.capture_minichat import classify_frame

def test_classify_live_reward():
    frame = {"Type": "Live", "Data": {"Type": "Reward", "Service": "VKVideoLive"}}
    assert classify_frame(frame) == "reward"
```

- [ ] **Step 2: Run the test and verify failure**

Run: `python -m pytest tests/bridge/test_minichat_client.py::test_classify_live_reward -v`

Expected: FAIL because `classify_frame` does not exist.

- [ ] **Step 3: Implement the capture tool**

`capture_minichat.py` must connect to `ws://127.0.0.1:4848/Chat`, JSON-decode each frame, print only `State` and `Live/Reward` frames, and optionally save them with `--out <path>`. It must redact cookies/tokens if keys contain `token`, `cookie`, `authorization`, or `secret`.

Core classifier:

```python
def classify_frame(frame: dict) -> str:
    if frame.get("Type") == "State":
        return "state"
    data = frame.get("Data") or {}
    if frame.get("Type") == "Live" and str(data.get("Type", "")).lower() == "reward":
        return "reward"
    return "other"
```

- [ ] **Step 4: Run the unit test**

Run: `python -m pytest tests/bridge/test_minichat_client.py -v`

Expected: PASS.

- [ ] **Step 5: Perform the real capture with Streamer.bot closed**

Run:

```powershell
python -m bridge.tools.capture_minichat --url ws://127.0.0.1:4848/Chat --out captured_reward.json
```

Then redeem `AIDA MUSIC` once with a valid YouTube URL and once with an invalid/empty input. Record the exact reward event fields: service, GUID/event id, user id, user name, reward title/name, date, text/MessageKit, and any reward-specific identifiers.

- [ ] **Step 6: Document the reward schema**

Write `docs/protocols/minichat-vkvideolive-reward.md` with the actual field paths observed, e.g. `Data.GUID`, `Data.UserName`, and the actual path holding reward title/input. Do not invent fields not present in the capture.

- [ ] **Step 7: Probe refund capability**

Inspect the captured `State` frame for callable methods and compare behavior with the existing MiniChat integration. Use `probe_refund.py` to send only the exact candidate MiniChat request discovered from real evidence. The script must require `--confirm-refund` before sending any refund request.

- [ ] **Step 8: Verify points actually return**

Before the test, note the viewer's point balance. Redeem one intentionally rejected `AIDA MUSIC` reward. With Streamer.bot still closed, send the candidate direct refund request and verify the VK balance increases by the reward cost exactly once.

- [ ] **Step 9: Record PASS or stop**

If refund works, write `docs/protocols/minichat-vkvideolive-refund.json` as the exact request template with token fields represented by deterministic template keys, for example:

```json
{
  "transport": "websocket",
  "request_template": {
    "Type": "VERIFIED_TYPE_FROM_CAPTURE",
    "Data": {
      "Service": "${service}",
      "GUID": "${event_id}"
    }
  }
}
```

Replace `VERIFIED_TYPE_FROM_CAPTURE` with the real verified value before committing. If there is no working direct refund request, do not create a release implementation: document the failed evidence in the markdown, commit the spike, and stop.

- [ ] **Step 10: Commit the protocol evidence**

```bash
git add bridge/tools tests/bridge/test_minichat_client.py docs/protocols
git commit -m "test: prove direct MiniChat reward refund protocol"
```

---

### Task 2: Add config and reward parsing

**Files:**
- Create: `bridge/config.py`
- Create: `bridge/models.py`
- Create: `bridge/parser.py`
- Create: `bridge/bridge_config.json`
- Test: `tests/bridge/test_config.py`
- Test: `tests/bridge/test_parser.py`
- Test fixtures: `tests/bridge/fixtures/*.json`

**Interfaces:**
- Produces: `BridgeConfig`, `RewardEvent`, `parse_reward_frame(frame, config) -> RewardEvent | None`.

- [ ] **Step 1: Write failing parser tests**

Cover: reward-name normalization, YouTube short URL, MessageKit URL, VK Video URL, Yandex Music URL, unsupported URL, unrelated reward, service alias, missing GUID.

Example:

```python
def test_parse_youtube_reward(fixture, config):
    event = parse_reward_frame(fixture("reward_youtube.json"), config)
    assert event.user_name == "PrapoR_ShoW"
    assert event.url.startswith("https://youtu.be/")
    assert event.reward_name == "AIDA MUSIC"
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `python -m pytest tests/bridge/test_config.py tests/bridge/test_parser.py -v`

- [ ] **Step 3: Implement config**

`BridgeConfig` fields:

```python
@dataclass(frozen=True)
class BridgeConfig:
    enabled: bool = True
    minichat_ws: str = "ws://127.0.0.1:4848/Chat"
    aida_order_api: str = "http://127.0.0.1:18765/api/order"
    reward_name: str = "AIDA MUSIC"
    service_aliases: tuple[str, ...] = ("VKVideoLive", "VKPlay", "VKVideo")
    reply_on_accept: bool = True
    reply_on_reject: bool = True
    refund_on_reject: bool = True
    dedupe_ttl_seconds: int = 600
```

- [ ] **Step 4: Implement reward model**

```python
@dataclass(frozen=True)
class RewardEvent:
    event_id: str
    service: str
    user_id: str
    user_name: str
    reward_name: str
    url: str
    occurred_at: str
    raw: dict
```

- [ ] **Step 5: Implement parser from the real Task 1 schema**

Use explicit field paths from `minichat-vkvideolive-reward.md`, then MessageKit traversal, then recursive string URL fallback. `parse_reward_frame` returns `None` for unrelated rewards/services.

- [ ] **Step 6: Run tests**

Run: `python -m pytest tests/bridge/test_config.py tests/bridge/test_parser.py -v`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add bridge/config.py bridge/models.py bridge/parser.py bridge/bridge_config.json tests/bridge
git commit -m "feat: parse AIDA MUSIC rewards from MiniChat"
```

---

### Task 3: Add AIDA HTTP client

**Files:**
- Create: `bridge/aida_client.py`
- Test: `tests/bridge/test_aida_client.py`

**Interfaces:**
- Consumes: `RewardEvent`.
- Produces: `OrderResult` and `AidaClient.submit_order(event) -> OrderResult`.

- [ ] **Step 1: Write failing accepted/rejected/offline tests**

```python
def test_accepts_ok_response(fake_session, event):
    fake_session.post_result(200, {"ok": True, "accepted": True})
    result = AidaClient("http://127.0.0.1:18765/api/order", fake_session).submit_order(event)
    assert result.accepted is True
```

Also assert request JSON is exactly:

```json
{"nick":"<user>","message":"<url>","source":"VK Video Live — AIDA MUSIC Direct"}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `python -m pytest tests/bridge/test_aida_client.py -v`

- [ ] **Step 3: Implement client with 10-second connect/read timeout**

Do not retry rejected orders. Network failures return `OrderResult(accepted=False, error="api_unavailable", message="AIDA Music Orders не ответила")`.

- [ ] **Step 4: Run tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add bridge/aida_client.py bridge/models.py tests/bridge/test_aida_client.py
git commit -m "feat: submit direct MiniChat orders to AIDA"
```

---

### Task 4: Add durable deduplication

**Files:**
- Create: `bridge/dedupe.py`
- Test: `tests/bridge/test_dedupe.py`

**Interfaces:**
- Produces: `DedupeStore.seen_or_mark(event) -> bool` where `True` means duplicate.

- [ ] **Step 1: Write failing GUID and fallback-hash tests**

Test same GUID twice, different GUIDs, missing GUID hash, TTL expiry, and database reopen.

- [ ] **Step 2: Implement SQLite store**

Schema:

```sql
CREATE TABLE IF NOT EXISTS seen_events (
  event_key TEXT PRIMARY KEY,
  seen_at INTEGER NOT NULL
)
```

Key priority: non-empty event id; otherwise SHA-256 of `service|user_id|reward_name|url|occurred_at`.

- [ ] **Step 3: Run tests**

Run: `python -m pytest tests/bridge/test_dedupe.py -v`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add bridge/dedupe.py tests/bridge/test_dedupe.py
git commit -m "feat: deduplicate MiniChat reward events"
```

---

### Task 5: Add MiniChat WebSocket client and direct chat replies

**Files:**
- Create: `bridge/minichat_client.py`
- Test: `tests/bridge/test_minichat_client.py`

**Interfaces:**
- Produces: `MiniChatClient.iter_frames()`, `send_message(service, message)`, reconnect backoff 1/2/5 seconds.

- [ ] **Step 1: Write failing outbound-message test**

Expected outbound payload:

```json
{"Type":"Message","Data":{"Service":"VKVideoLive","Message":"🎵 @PrapoR_ShoW, заказ принят и добавлен в очередь.","Hide":false}}
```

- [ ] **Step 2: Write reconnect-backoff test**

Inject a fake connector that fails three times and assert sleep sequence `[1, 2, 5]`.

- [ ] **Step 3: Implement one synchronous WebSocket connection**

Do not create polling threads. Receive frames blocking; reconnect only after socket failure. JSON decode errors are logged and skipped.

- [ ] **Step 4: Run tests**

Run: `python -m pytest tests/bridge/test_minichat_client.py -v`

- [ ] **Step 5: Commit**

```bash
git add bridge/minichat_client.py tests/bridge/test_minichat_client.py
git commit -m "feat: connect bridge directly to MiniChat"
```

---

### Task 6: Implement verified refund adapter

**Files:**
- Create: `bridge/refund.py`
- Modify: `docs/protocols/minichat-vkvideolive-refund.json`
- Test: `tests/bridge/test_refund.py`

**Interfaces:**
- Consumes: verified protocol JSON from Task 1 and `RewardEvent`.
- Produces: `RefundClient.refund(event) -> bool`.

- [ ] **Step 1: Write failing template-substitution test**

The test loads the checked-in verified protocol JSON and asserts `${service}`, `${event_id}`, `${user_id}` and any other recorded template keys are replaced by actual event values, with no `${...}` left in serialized output.

- [ ] **Step 2: Write one-shot protection test**

Calling `refund(event)` twice for the same event must send exactly one refund frame. Reuse `DedupeStore` namespace `refund:<event-key>`.

- [ ] **Step 3: Implement refund adapter**

Load only the verified Task 1 protocol. If file is missing, invalid, contains unreplaced template keys, or `refund_on_reject` is true while the protocol is unavailable, startup must fail with a clear RC-only error instead of silently pretending refunds work.

- [ ] **Step 4: Run tests**

Run: `python -m pytest tests/bridge/test_refund.py -v`

- [ ] **Step 5: Commit**

```bash
git add bridge/refund.py tests/bridge/test_refund.py docs/protocols/minichat-vkvideolive-refund.json
git commit -m "feat: refund rejected VK rewards directly through MiniChat"
```

---

### Task 7: Orchestrate the full reward flow

**Files:**
- Create: `bridge/service.py`
- Create: `bridge/main.py`
- Create: `bridge/__init__.py`
- Test: `tests/bridge/test_service.py`

**Interfaces:**
- `BridgeService.handle_frame(frame: dict) -> str` returns one of `ignored`, `duplicate`, `accepted`, `rejected`, `error` for diagnostics.

- [ ] **Step 1: Write failing success-flow test**

Assert one valid reward causes: parse → mark dedupe → AIDA submit → one accepted chat reply → no refund.

- [ ] **Step 2: Write failing rejection-flow test**

Assert rejected AIDA response causes: one rejection chat reply → one refund → result `rejected`.

- [ ] **Step 3: Write missing-link rejection test**

A real AIDA MUSIC reward with no supported URL must never call AIDA API; it replies with missing-link text and refunds once.

- [ ] **Step 4: Implement orchestration**

Keep business sequencing only in `service.py`; no socket internals or HTTP details there.

- [ ] **Step 5: Add `main.py` lifecycle**

Load config relative to executable, create `%LOCALAPPDATA%/AIDA Music Orders/bridge/bridge.db`, configure rotating log capped at 2 MB × 3 files, then run the MiniChat receive loop.

- [ ] **Step 6: Run complete bridge test suite**

Run: `python -m pytest tests/bridge -v`

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add bridge tests/bridge
git commit -m "feat: complete direct AIDA Music reward bridge"
```

---

### Task 8: Build standalone Windows Bridge EXE

**Files:**
- Create: `bridge/requirements.txt`
- Create: `bridge/AIDA_MiniChat_Bridge.spec`
- Create: `packaging/START_AIDA_OWNER.cmd`
- Create: `packaging/START_AIDA_CUSTOMER.cmd`
- Create: `packaging/README_v1.0.4.txt`

**Interfaces:**
- Produces: `dist/AIDA MiniChat Bridge.exe` and launchers that start existing AIDA first, wait for port 18765, then start one Bridge instance.

- [ ] **Step 1: Pin runtime/build dependencies**

`bridge/requirements.txt`:

```text
requests==2.32.5
websocket-client==1.8.0
pytest==8.4.2
pyinstaller==6.15.0
```

- [ ] **Step 2: Build PyInstaller spec**

Use one-file, console disabled for final build, embed no secrets, include default `bridge_config.json` and verified refund protocol as data files.

- [ ] **Step 3: Write launchers without PowerShell escaping hacks**

Use plain CMD + `powershell -NoProfile -Command` only for the health probe, with commands quoted normally. Check for existing bridge process by exact image name before launching. Wait up to 30 seconds for `http://127.0.0.1:18765/` or the existing AIDA API health behavior, then start Bridge.

- [ ] **Step 4: Build**

```powershell
pyinstaller bridge\AIDA_MiniChat_Bridge.spec --clean --noconfirm
```

- [ ] **Step 5: Smoke-test EXE**

With MiniChat closed, Bridge must stay alive and reconnect at 1/2/5-second capped intervals without high CPU. With MiniChat open, log must show one connection.

- [ ] **Step 6: Commit build scripts, not generated EXE**

```bash
git add bridge/requirements.txt bridge/AIDA_MiniChat_Bridge.spec packaging
git commit -m "build: package AIDA MiniChat Bridge for Windows"
```

---

### Task 9: Real stream-PC acceptance gate

**Files:**
- Create: `docs/acceptance/v1.0.4-direct-minichat-checklist.md`

**Interfaces:**
- Produces: signed-off PASS evidence required by the release/store plan.

- [ ] **Step 1: Prepare clean runtime**

Close Streamer.bot completely. Start MiniChat, AIDA v1.0.3 OWNER base plus new v1.0.4 launcher/Bridge, and OBS using the unchanged player URL.

- [ ] **Step 2: Valid YouTube reward**

Redeem once. Verify AIDA receives exactly one row, chat gets exactly one accepted reply, points are not refunded, and OBS plays the item or the existing LOCAL fallback.

- [ ] **Step 3: Invalid/empty reward**

Redeem once. Verify AIDA queue does not gain an item, chat gets one rejection reply, and VK points return exactly once.

- [ ] **Step 4: VK Video and Yandex Music**

Redeem one supported URL from each service and verify queue + playback paths remain functional.

- [ ] **Step 5: Reconnect**

Close MiniChat for 15 seconds and reopen it. Verify Bridge reconnects automatically and the next reward works without restarting AIDA.

- [ ] **Step 6: Duplicate protection**

Replay the same captured reward GUID to Bridge and verify no second AIDA order, reply, or refund occurs.

- [ ] **Step 7: Record PASS**

Write date, machine, MiniChat version, Bridge build hash, result for every check, and explicit line `RELEASE_GATE=PASS`. If any refund test fails, write `RELEASE_GATE=FAIL` and do not execute the release/store plan.

- [ ] **Step 8: Commit acceptance evidence**

```bash
git add docs/acceptance/v1.0.4-direct-minichat-checklist.md
git commit -m "test: accept AIDA Music v1.0.4 direct MiniChat flow"
```

---

## Self-review results

- Spec coverage: direct MiniChat input, URL parsing, AIDA API, chat replies, dedupe, reconnect, low load, packaging, Streamer.bot-free test, and refund release gate are all mapped to Tasks 1–9.
- Placeholder scan: implementation may only proceed past Task 1 after the verified refund JSON contains the actual captured protocol value; the plan explicitly stops otherwise rather than inventing it.
- Type consistency: `RewardEvent`, `OrderResult`, `BridgeConfig`, `DedupeStore`, `AidaClient`, `MiniChatClient`, `RefundClient`, and `BridgeService` names are consistent across tasks.

## Handoff to release

Only after Task 9 produces `RELEASE_GATE=PASS`, execute:

`docs/superpowers/plans/2026-08-31-aida-music-v1.0.4-release-store-plan.md`
