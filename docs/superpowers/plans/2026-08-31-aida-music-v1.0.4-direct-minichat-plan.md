# AIDA Music Orders v1.0.4 Direct MiniChat Implementation Plan

**Goal:** `AIDA MUSIC` из VK Video Live идёт напрямую `MiniChat → AIDA Music Orders → OBS` без Streamer.bot.

**Важно:** автоматический возврат баллов не входит в v1.0.4. При отказе Bridge пишет причину в VK-чат, но баллы автоматически не возвращает.

## Task 1 — Реальный формат награды

PASS: реальный `captured_reward.json` получен.

Подтверждены поля:
- `Type = Live`
- `Data.Type = Reward`
- `Data.Name = AIDA MUSIC`
- `Data.Service = VKVideoLive`
- `Data.GUID`
- `Data.UserID`
- `Data.UserName`
- URL: `Data.MessageKit[].Data.URL`

Реальный fixture сохранён в `tests/bridge/fixtures/reward_youtube_real.json`.

## Task 2 — Config + parser (TDD)

Создать:
- `bridge/config.py`
- `bridge/models.py`
- `bridge/parser.py`
- `bridge/bridge_config.json`
- `tests/bridge/test_parser.py`

Проверить:
- реальный YouTube reward;
- VK Video;
- Яндекс Музыка;
- нет ссылки;
- другая награда;
- дедупликационный GUID.

## Task 3 — AIDA API client (TDD)

Создать:
- `bridge/aida_client.py`
- `tests/bridge/test_aida_client.py`

POST:
`http://127.0.0.1:18765/api/order`

Payload:
```json
{
  "nick": "<UserName>",
  "message": "<URL>",
  "source": "VK Video Live — AIDA MUSIC Direct"
}
```

## Task 4 — Deduplication (TDD)

Создать:
- `bridge/dedupe.py`
- `tests/bridge/test_dedupe.py`

Ключ: GUID, fallback SHA-256. TTL 600 секунд.

## Task 5 — MiniChat client (TDD)

Создать:
- `bridge/minichat_client.py`
- `tests/bridge/test_minichat_client.py`

Функции:
- одно WebSocket соединение;
- reconnect 1/2/5 секунд;
- принимать JSON frames;
- отправлять сообщение:
```json
{
  "Type": "Message",
  "Data": {
    "Service": "VKVideoLive",
    "Message": "...",
    "Hide": false
  }
}
```

## Task 6 — Bridge service (TDD)

Создать:
- `bridge/service.py`
- `bridge/main.py`
- `tests/bridge/test_service.py`

Flow:
1. Получить reward.
2. Отфильтровать `AIDA MUSIC`.
3. Проверить duplicate.
4. Если URL нет — ответить отказом, AIDA не вызывать.
5. Если URL есть — POST в AIDA.
6. Accepted → написать «заказ принят».
7. Rejected/offline → написать причину.

Никакого refund вызова.

## Task 7 — Windows EXE + launcher

Создать:
- `bridge/requirements.txt`
- `bridge/AIDA_MiniChat_Bridge.spec`
- `packaging/START_AIDA_OWNER.cmd`
- `packaging/START_AIDA_CUSTOMER.cmd`
- `packaging/README_v1.0.4.txt`

Launcher:
- запускает AIDA;
- ждёт порт 18765;
- запускает один Bridge;
- без красной PowerShell ошибки старого START_OWNER.

## Task 8 — Реальная приёмка

Streamer.bot полностью закрыт.

Проверить:
1. YouTube reward → один заказ в AIDA.
2. Один ответ «заказ принят» в VK.
3. Плохая ссылка → заказа нет, есть сообщение об отказе.
4. VK Video.
5. Яндекс Музыка.
6. MiniChat reconnect.
7. OBS URL и fallback v1.0.3 работают как раньше.

Refund баллов не проверяется и не обещается.

## Task 9 — Release / Store

Только после PASS Task 8:
- OWNER/CUSTOMER/UPDATE v1.0.4;
- SHA-256;
- GitHub Release;
- update manifest;
- README;
- магазин v1.0.4;
- убрать обязательность Streamer.bot;
- не писать про автоматический возврат баллов.
