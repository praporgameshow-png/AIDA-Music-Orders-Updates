from bridge.tools.capture_minichat import classify_frame


def test_classify_live_reward():
    frame = {"Type": "Live", "Data": {"Type": "Reward", "Service": "VKVideoLive"}}
    assert classify_frame(frame) == "reward"
