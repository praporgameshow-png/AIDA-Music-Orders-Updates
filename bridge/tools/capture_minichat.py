from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import websocket

SENSITIVE_PARTS = ("token", "cookie", "authorization", "secret")


def classify_frame(frame: dict) -> str:
    if frame.get("Type") == "State":
        return "state"
    data = frame.get("Data") or {}
    if frame.get("Type") == "Live" and str(data.get("Type", "")).lower() == "reward":
        return "reward"
    return "other"


def redact(value: Any) -> Any:
    if isinstance(value, dict):
        clean = {}
        for key, item in value.items():
            key_text = str(key)
            if any(part in key_text.lower() for part in SENSITIVE_PARTS):
                clean[key] = "<REDACTED>"
            else:
                clean[key] = redact(item)
        return clean
    if isinstance(value, list):
        return [redact(item) for item in value]
    return value


def append_frame(path: Path, frame: dict) -> None:
    records = []
    if path.exists():
        try:
            existing = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(existing, list):
                records = existing
        except Exception:
            records = []
    records.append(redact(frame))
    path.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")


def run(url: str, out: Path | None) -> None:
    print("[AIDA] Подключаюсь к MiniChat:", url)
    print("[AIDA] Сохраняю только State и Live/Reward. Для остановки нажми Ctrl+C.")
    ws = websocket.create_connection(url, timeout=10)
    print("[AIDA] MiniChat подключён. Теперь активируй награду AIDA MUSIC в VK.")
    try:
        while True:
            raw = ws.recv()
            if not raw:
                continue
            try:
                frame = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if not isinstance(frame, dict):
                continue
            kind = classify_frame(frame)
            if kind == "other":
                continue
            safe = redact(frame)
            print("\n===", kind.upper(), "===")
            print(json.dumps(safe, ensure_ascii=False, indent=2))
            if out is not None:
                append_frame(out, frame)
                print("[AIDA] Записано в:", out)
    except KeyboardInterrupt:
        print("\n[AIDA] Захват остановлен.")
    finally:
        try:
            ws.close()
        except Exception:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description="AIDA MiniChat reward capture")
    parser.add_argument("--url", default="ws://127.0.0.1:4848/Chat")
    parser.add_argument("--out", default="captured_reward.json")
    args = parser.parse_args()
    out = Path(args.out).resolve() if args.out else None
    try:
        run(args.url, out)
        return 0
    except Exception as exc:
        print("[AIDA] Ошибка подключения к MiniChat:", exc)
        print("[AIDA] Проверь, что MiniChat запущен и WebSocket использует порт 4848.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
