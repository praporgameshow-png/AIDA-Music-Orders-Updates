from dataclasses import dataclass

@dataclass(frozen=True)
class BridgeConfig:
    enabled: bool = True
    minichat_ws: str = "ws://127.0.0.1:4848/Chat"
    aida_order_api: str = "http://127.0.0.1:18765/api/order"
    reward_name: str = "AIDA MUSIC"
    service_aliases: tuple[str, ...] = ("VKVideoLive", "VKPlay", "VKVideo")
    reply_on_accept: bool = True
    reply_on_reject: bool = True
    dedupe_ttl_seconds: int = 600
