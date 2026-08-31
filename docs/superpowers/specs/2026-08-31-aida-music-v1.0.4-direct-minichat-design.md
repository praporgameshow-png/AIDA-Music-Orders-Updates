# AIDA Music Orders v1.0.4 — Direct MiniChat Integration Design

**Дата:** 31.08.2026  
**Статус:** утверждено пользователем, реализация без автоматического возврата баллов

## 1. Цель

Выпустить AIDA Music Orders v1.0.4, где награда `AIDA MUSIC` из VK Video Live обрабатывается напрямую через MiniChat без обязательного Streamer.bot.

Цепочка:

`VK Video Live reward → MiniChat → AIDA MiniChat Bridge → AIDA Music Orders API → очередь → OBS`

AIDA/Bridge должны:

- получать событие награды из MiniChat;
- извлекать ник, GUID и музыкальную ссылку;
- отправлять заказ в существующий API `http://127.0.0.1:18765/api/order`;
- отправлять в VK через MiniChat сообщение о принятии или отказе;
- работать без Streamer.bot для музыкальной награды.

**Автоматический возврат баллов не входит в v1.0.4.** При отказе зрителю отправляется причина, но потраченные баллы автоматически не возвращаются. Магазин и README не должны обещать возврат.

## 2. Что сохраняем из v1.0.3

Основной рабочий EXE v1.0.3 на первом этапе не переписываем и не патчим. Сохраняются:

- очередь заказов;
- AIDA API `POST /api/order`;
- OBS-плеер `http://127.0.0.1:18765/player?client=obs`;
- YouTube / YouTube Music;
- VK Video;
- Яндекс Музыка;
- YouTube LOCAL FALLBACK;
- VK FAST/FALLBACK;
- ограничения очереди;
- повторные заказы;
- один активный заказ на зрителя;
- чёрный список;
- история;
- CUSTOMER trial 48 часов и лицензирование;
- OWNER без trial/license gate.

v1.0.3 остаётся резервной стабильной версией.

## 3. Реальный формат MiniChat Reward

Подтверждено реальным захватом VK Video Live:

```json
{
  "Type": "Live",
  "Data": {
    "Type": "Reward",
    "CurrencyType": "ChannelPoints",
    "Name": "AIDA MUSIC",
    "Price": 3000,
    "MessageKit": [
      {
        "Type": "URL",
        "Data": {
          "URL": "https://youtu.be/..."
        }
      }
    ],
    "Service": "VKVideoLive",
    "GUID": "...",
    "UserID": "...",
    "UserName": "..."
  }
}
```

Ключевые поля:

- `Data.Name` — название награды;
- `Data.MessageKit[].Data.URL` — ссылка;
- `Data.Service` — сервис;
- `Data.GUID` — уникальный ID активации;
- `Data.UserID` — ID зрителя;
- `Data.UserName` — ник.

Bridge должен сначала использовать эти точные поля, а fallback-поиск URL применять только если `MessageKit` не дал ссылку.

## 4. Поддерживаемые ссылки

- `youtube.com`;
- `youtu.be`;
- `music.youtube.com`;
- `vkvideo.ru`;
- `vk.com/video`;
- `vk.ru/video`;
- `music.yandex.ru`;
- `music.yandex.com`.

## 5. Поток успешного заказа

1. MiniChat присылает `Live/Reward`.
2. Bridge проверяет `Data.Name == AIDA MUSIC` после нормализации.
3. Извлекает `GUID`, `UserID`, `UserName`, `Service`, URL.
4. Проверяет дедупликацию.
5. POST в AIDA:

```json
{
  "nick": "PrapoR_ShoW",
  "message": "https://youtu.be/...",
  "source": "VK Video Live — AIDA MUSIC Direct"
}
```

6. Если AIDA отвечает `ok=true` или `accepted=true`, Bridge отправляет через MiniChat:

`🎵 @<ник>, заказ принят и добавлен в очередь.`

## 6. Поток отказа

Если URL отсутствует или AIDA отклоняет заказ, Bridge отправляет в чат понятную причину. Баллы автоматически не возвращаются.

Примеры причин:

- нет поддерживаемой ссылки;
- заказы закрыты;
- чёрный список;
- повторный заказ;
- лимит очереди;
- один активный заказ на зрителя;
- AIDA недоступна;
- иной ответ API.

## 7. Дедупликация

Одно событие не должно создать два заказа.

Ключ:

1. `Data.GUID`, если есть;
2. иначе SHA-256 от `service|user_id|reward_name|url|date`.

TTL: 10 минут. Повтор игнорируется без второго сообщения.

## 8. Соединение и нагрузка

- одно WebSocket-соединение с `ws://127.0.0.1:4848/Chat`;
- reconnect 1 → 2 → 5 секунд, максимум 5;
- HTTP к AIDA только при награде;
- никаких OCR/скриншотов/частого polling;
- минимальная нагрузка в idle.

## 9. Настройки

```json
{
  "enabled": true,
  "minichat_ws": "ws://127.0.0.1:4848/Chat",
  "aida_order_api": "http://127.0.0.1:18765/api/order",
  "reward_name": "AIDA MUSIC",
  "reply_on_accept": true,
  "reply_on_reject": true,
  "dedupe_ttl_seconds": 600
}
```

## 10. Обратная совместимость

- старый trigger `AIDA MUSIC — Заказ из VK` в Streamer.bot пользователь отключает вручную;
- OBS URL не меняется;
- ручной заказ в AIDA работает как раньше;
- v1.0.3 остаётся резервом.

## 11. Приёмка v1.0.4

1. Streamer.bot полностью закрыт.
2. MiniChat запущен.
3. AIDA + Bridge запущены.
4. YouTube-награда создаёт ровно один заказ.
5. В чат приходит ровно одно сообщение о принятии.
6. Пустая/плохая ссылка не создаёт заказ и даёт сообщение об отказе.
7. VK Video работает.
8. Яндекс Музыка работает.
9. MiniChat reconnect работает.
10. OBS и существующие fallback-механизмы v1.0.3 не ломаются.

Возврат баллов не является критерием приёмки v1.0.4.

## 12. Сборки и магазин

После PASS приёмки:

- `AIDA_Music_Orders_v1.0.4_OWNER.zip`;
- `AIDA_Music_Orders_v1.0.4_CUSTOMER.zip`;
- `AIDA_Music_Orders_v1.0.4_UPDATE.zip`;
- SHA-256.

Магазин обновляется на v1.0.4 только после реального теста Direct MiniChat. Из обязательных зависимостей убирается Streamer.bot. В описании явно не обещается автоматический возврат баллов при отклонении заказа.

Цена остаётся 1490 ₽. Trial остаётся 48 часов.
