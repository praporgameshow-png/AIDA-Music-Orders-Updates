# AIDA Music Orders v1.0.4 Release and Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the already-accepted AIDA Music Orders v1.0.4 builds, update the GitHub update channel, and switch Prapor Software Store from v1.0.3 to v1.0.4 only after the direct MiniChat refund acceptance gate passes.

**Architecture:** Treat the release as a gated deployment. Build OWNER/CUSTOMER/UPDATE archives from the accepted runtime, compute hashes from final bytes, publish GitHub release assets, update `update_manifest.json` only after asset URLs and hashes are known, then update README and the Telegram/Cloudflare store copy. No store or manifest switch occurs before `RELEASE_GATE=PASS` exists in the acceptance checklist.

**Tech Stack:** Windows ZIP/PowerShell SHA-256 tooling, GitHub Releases, JSON update manifest, existing Cloudflare Worker/Telegram Mini App store source.

**Spec:** `docs/superpowers/specs/2026-08-31-aida-music-v1.0.4-direct-minichat-design.md`

## Global Constraints

- Require `docs/acceptance/v1.0.4-direct-minichat-checklist.md` to contain `RELEASE_GATE=PASS`.
- Price remains `1490 ₽`.
- CUSTOMER trial remains `48 hours`.
- OWNER remains license/trial-free.
- Existing OBS player URL remains unchanged.
- Keep v1.0.3 release intact as rollback.
- Do not advertise Streamer.bot-free refund until the real refund test passed.
- Upload release assets before changing `update_manifest.json`.
- SHA-256 must be computed from the exact uploaded archive bytes.

---

### Task 1: Verify the release gate and freeze accepted inputs

**Files:**
- Read: `docs/acceptance/v1.0.4-direct-minichat-checklist.md`
- Create: `release/v1.0.4/RELEASE_INPUTS.txt`

**Interfaces:**
- Produces: a frozen list of source/base hashes used for all archives.

- [ ] **Step 1: Check gate**

Run:

```powershell
Select-String -Path docs\acceptance\v1.0.4-direct-minichat-checklist.md -Pattern '^RELEASE_GATE=PASS$'
```

Expected: exactly one matching line. If absent, STOP.

- [ ] **Step 2: Hash accepted binaries**

Record SHA-256 for base OWNER/CUSTOMER AIDA EXEs and `AIDA MiniChat Bridge.exe`.

```powershell
Get-FileHash '.\accepted\OWNER\AIDA Music Orders.exe' -Algorithm SHA256
Get-FileHash '.\accepted\CUSTOMER\AIDA Music Orders.exe' -Algorithm SHA256
Get-FileHash '.\accepted\AIDA MiniChat Bridge.exe' -Algorithm SHA256
```

- [ ] **Step 3: Write `RELEASE_INPUTS.txt`**

Include exact filenames, hashes, acceptance checklist commit SHA, and the refund protocol file SHA.

- [ ] **Step 4: Commit**

```bash
git add release/v1.0.4/RELEASE_INPUTS.txt
git commit -m "chore: freeze AIDA Music v1.0.4 release inputs"
```

---

### Task 2: Assemble OWNER, CUSTOMER, and UPDATE archives

**Files:**
- Create output: `AIDA_Music_Orders_v1.0.4_OWNER.zip`
- Create output: `AIDA_Music_Orders_v1.0.4_CUSTOMER.zip`
- Create output: `AIDA_Music_Orders_v1.0.4_UPDATE.zip`
- Include: `AIDA MiniChat Bridge.exe`, `bridge_config.json`, verified refund protocol, launchers, README.

**Interfaces:**
- Produces: three deterministic final ZIP archives.

- [ ] **Step 1: Stage OWNER**

OWNER package contains the accepted OWNER AIDA base, Bridge, OWNER launcher, config, protocol file, and README. It must not contain CUSTOMER license/trial data.

- [ ] **Step 2: Stage CUSTOMER**

CUSTOMER package contains the accepted CUSTOMER AIDA base, Bridge, CUSTOMER launcher, config, protocol file, and README. Confirm the existing 48-hour trial is preserved.

- [ ] **Step 3: Stage UPDATE**

UPDATE package contains only update-safe application files and Bridge additions; exclude mutable user data, license files, order history, blacklist, and settings that the current updater preserves.

- [ ] **Step 4: Create archives**

Use a clean staging directory and PowerShell `Compress-Archive` or the established v1.0.3 packaging method.

- [ ] **Step 5: Inspect archive contents**

```powershell
Expand-Archive AIDA_Music_Orders_v1.0.4_UPDATE.zip .\verify-update -Force
Get-ChildItem .\verify-update -Recurse
```

Verify no user data or secrets are included.

- [ ] **Step 6: Compute hashes**

```powershell
Get-FileHash AIDA_Music_Orders_v1.0.4_OWNER.zip -Algorithm SHA256
Get-FileHash AIDA_Music_Orders_v1.0.4_CUSTOMER.zip -Algorithm SHA256
Get-FileHash AIDA_Music_Orders_v1.0.4_UPDATE.zip -Algorithm SHA256
```

Write all three values to `release/v1.0.4/SHA256SUMS.txt`.

---

### Task 3: Smoke-test the final archives, not staging folders

**Files:**
- Read: final ZIP archives
- Modify: `docs/acceptance/v1.0.4-direct-minichat-checklist.md`

**Interfaces:**
- Produces: final-archive verification evidence.

- [ ] **Step 1: Extract OWNER to a new folder**

Run launcher and verify no trial/license dialog appears.

- [ ] **Step 2: Extract CUSTOMER to a new folder**

Verify CUSTOMER starts with the existing licensing/trial behavior and reports a 48-hour trial on an unlicensed fresh install.

- [ ] **Step 3: Direct MiniChat smoke test from extracted archive**

With Streamer.bot closed, redeem one valid reward and one invalid reward. Verify accept/reject reply and refund again.

- [ ] **Step 4: UPDATE preservation test**

Create representative user config/history files in a v1.0.3 CUSTOMER copy, apply the UPDATE archive through the same update path, and verify those mutable files survive.

- [ ] **Step 5: Append evidence**

Add `FINAL_ARCHIVES=PASS` and the three SHA-256 values to the acceptance checklist.

- [ ] **Step 6: Commit evidence**

```bash
git add docs/acceptance/v1.0.4-direct-minichat-checklist.md release/v1.0.4/SHA256SUMS.txt
git commit -m "test: verify final AIDA Music v1.0.4 archives"
```

---

### Task 4: Publish GitHub release v1.0.4

**Files:**
- Release assets: CUSTOMER and UPDATE ZIPs; OWNER may remain private/local unless owner distribution requires upload.
- Release notes text.

**Interfaces:**
- Produces: stable GitHub release asset URLs.

- [ ] **Step 1: Create release `v1.0.4` as draft**

Title: `AIDA Music Orders v1.0.4 FINAL`

Release body must state:

```text
AIDA Music Orders v1.0.4 FINAL

• AIDA MUSIC rewards can be handled directly through MiniChat without Streamer.bot.
• Direct VK Video Live accept/reject chat replies.
• Automatic point refund on rejected rewards, verified on the release test setup.
• Duplicate reward protection and MiniChat auto-reconnect.
• Existing YouTube LOCAL fallback, VK FAST/FALLBACK, OBS player, queue, blacklist and CUSTOMER 48-hour trial are preserved.

Before enabling the new bridge, disable the old Streamer.bot trigger “AIDA MUSIC — Заказ из VK” to avoid duplicate processing.
```

- [ ] **Step 2: Upload final CUSTOMER and UPDATE assets**

Names must be exactly:

```text
AIDA_Music_Orders_v1.0.4_CUSTOMER.zip
AIDA_Music_Orders_v1.0.4_UPDATE.zip
```

- [ ] **Step 3: Verify uploaded asset digest/size**

Compare GitHub's reported digest when available with `release/v1.0.4/SHA256SUMS.txt`.

- [ ] **Step 4: Publish release**

Do not delete or modify v1.0.3.

---

### Task 5: Update the public update channel

**Files:**
- Modify: `update_manifest.json`
- Modify: `README.md`

**Interfaces:**
- Produces: v1.0.3 clients discover v1.0.4 only after the release asset exists.

- [ ] **Step 1: Write failing manifest validation test/script**

Validate fields `version`, `download_url`, `sha256`, `notes`; require semantic version `1.0.4`, URL basename `AIDA_Music_Orders_v1.0.4_UPDATE.zip`, and 64 lowercase hex SHA.

- [ ] **Step 2: Update manifest from final hash**

Exact shape:

```json
{
  "version": "1.0.4",
  "download_url": "https://github.com/praporgameshow-png/AIDA-Music-Orders-Updates/releases/download/v1.0.4/AIDA_Music_Orders_v1.0.4_UPDATE.zip",
  "sha256": "<EXACT_FINAL_UPDATE_SHA256>",
  "notes": "AIDA Music Orders 1.0.4 FINAL — прямая обработка AIDA MUSIC через MiniChat без обязательного Streamer.bot, ответы в VK Video Live, проверенный возврат баллов при отказе, защита от дублей и автопереподключение MiniChat. Существующие YouTube/VK fallback, OBS-плеер, очередь, чёрный список и CUSTOMER trial 48 часов сохранены."
}
```

Replace `<EXACT_FINAL_UPDATE_SHA256>` with the final recorded value before commit.

- [ ] **Step 3: Update README**

Set current stable version to `v1.0.4 FINAL` and summarize the direct MiniChat bridge while noting that the old Streamer.bot music trigger must be disabled.

- [ ] **Step 4: Verify URL and hash independently**

Download the release UPDATE ZIP to a clean temp folder and run `Get-FileHash`; it must match the manifest.

- [ ] **Step 5: Commit**

```bash
git add update_manifest.json README.md
git commit -m "release: publish AIDA Music Orders v1.0.4 update channel"
```

---

### Task 6: Update Prapor Software Store source

**Files:**
- Modify: the deployed store Worker source containing `PRODUCT`, `STORE_HTML`, `/storepost`, and `/api/trial`.
- Preserve: payment amount `1490`, trial `48`, bank/payment fields, order/license flow.

**Interfaces:**
- Produces: store UI and bot post that advertise v1.0.4 accurately.

- [ ] **Step 1: Make a backup/export of the currently deployed Worker source**

Save it as a dated local backup before edits.

- [ ] **Step 2: Update product constant**

Change:

```javascript
name: "AIDA Music Orders v1.0.3"
```

to:

```javascript
name: "AIDA Music Orders v1.0.4"
```

Keep `price: 1490` and `trialHours: 48`.

- [ ] **Step 3: Update catalog badges and features**

Remove the required `Streamer.bot` badge. Add/retain `MiniChat`. Replace `VK Video Live + MiniChat + Streamer.bot` with `VK Video Live + MiniChat напрямую` and add `автоматический возврат баллов при отклонённом заказе` only because the release gate passed.

- [ ] **Step 4: Update `/storepost` copy**

Change v1.0.3 to v1.0.4 and mention direct MiniChat integration. Keep price/trial/license wording unchanged.

- [ ] **Step 5: Update trial download target**

Point `TRIAL_DOWNLOAD_URL` to the final v1.0.4 CUSTOMER/trial distribution mechanism used by the store. Do not expose OWNER package.

- [ ] **Step 6: Deploy Worker**

Use the existing Cloudflare deployment method for this Worker. Do not create a replacement store unless deployment of the existing Worker is impossible.

- [ ] **Step 7: Verify live store**

Open the Telegram Mini App and confirm:

```text
AIDA Music Orders v1.0.4
Windows / OBS / MiniChat
1490 ₽
48 часов
VK Video Live + MiniChat напрямую
```

Confirm no required Streamer.bot badge remains.

- [ ] **Step 8: Send a fresh `/storepost`**

Verify the published Telegram post says v1.0.4 and opens the existing store Mini App.

---

### Task 7: End-to-end buyer-path verification

**Files:**
- Modify: `docs/acceptance/v1.0.4-direct-minichat-checklist.md`

**Interfaces:**
- Produces: final `STORE_RELEASE=PASS` evidence.

- [ ] **Step 1: Trial download test**

From Telegram store, invoke the trial download path and verify the file/version is v1.0.4 CUSTOMER distribution, not v1.0.3.

- [ ] **Step 2: Existing license/update test**

On a licensed v1.0.3 CUSTOMER copy, run update check, download v1.0.4 UPDATE, verify SHA validation succeeds, and confirm license/user data survive.

- [ ] **Step 3: Post-update direct reward test**

With Streamer.bot closed and old music trigger disabled, verify a valid reward and rejected reward after auto-update.

- [ ] **Step 4: Rollback reference**

Confirm v1.0.3 release URLs still exist for emergency manual rollback.

- [ ] **Step 5: Record final status**

Append:

```text
FINAL_ARCHIVES=PASS
UPDATE_CHANNEL=PASS
STORE_RELEASE=PASS
```

- [ ] **Step 6: Commit**

```bash
git add docs/acceptance/v1.0.4-direct-minichat-checklist.md
git commit -m "test: complete AIDA Music v1.0.4 store release acceptance"
```

---

## Self-review results

- Spec coverage: packaging, OWNER/CUSTOMER distinctions, 48-hour trial, GitHub release, exact SHA manifest, README, store card, `/storepost`, trial download, update preservation, and rollback are all represented.
- Release ordering prevents v1.0.3 clients or buyers from seeing v1.0.4 until final archive verification is complete.
- No manifest hash or refund capability is guessed; both are sourced from verified final evidence.

## Completion condition

This release plan is complete only when the acceptance checklist contains all four lines:

```text
RELEASE_GATE=PASS
FINAL_ARCHIVES=PASS
UPDATE_CHANNEL=PASS
STORE_RELEASE=PASS
```
