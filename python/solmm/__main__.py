"""Replay camera and range data through the SOLMM controller."""

import argparse
from dataclasses import asdict
import json
from pathlib import Path

import cv2
import numpy as np

from ..sift_check.run_check import FIGURE, read_panel
from .memory import EpisodicMemory, SiftVision, Thresholds
from .navigation import ArchivedFallback, NavigationController
from .spatial import SpatialEncoder


def build_controller(model_dir, settings):
    centers = [(x, y) for x in range(6) for y in range(6)]
    spatial = {"centers_m": centers, **settings.get("spatial", {})}
    thresholds = Thresholds(**settings.get("thresholds", {}))
    memory = EpisodicMemory(SiftVision(), thresholds, **settings.get("memory", {}))
    return NavigationController(SpatialEncoder(**spatial), memory,
                               ArchivedFallback(model_dir))


def replay(controller, episodes, image_at):
    for index, episode in enumerate(episodes, 1):
        controller.begin_episode(episode["start_m"], episode.get("heading_rad", 0.0))
        learn = episode.get("learn", False)
        for frame_index, sample in enumerate(episode["frames"], 1):
            decision = controller.step(
                image_at(sample["image"]), sample["velocity_body_m_s"],
                sample["angular_rad_s"], sample["dt_s"], episode["goal_m"],
                sample["lidar_body_m"], sample.get("arrival_action"), learn)
            print(json.dumps({"episode": index, "frame": frame_index, **asdict(decision)},
                             allow_nan=False))
        kept, removed = controller.finish_episode(episode.get("reorganize", True))
        print(json.dumps({"episode": index, "kept": kept, "removed": removed,
                          "fragments": len(controller.memory.fragments),
                          "state_neurons": len(controller.memory.neurons)}))


def demo(controller):
    pdf = FIGURE.read_bytes()
    frames = {panel: read_panel(pdf, object_id) for panel, object_id in zip("abc", (10, 11, 12))}
    frames["blank"] = np.zeros_like(frames["a"])
    episode = {"start_m": [0, 0], "goal_m": [1, 1]}
    samples = [
        {"image": name, "velocity_body_m_s": velocity, "angular_rad_s": 0,
         "dt_s": 1, "lidar_body_m": [[0.7, 0.15]], "arrival_action": action}
        for name, velocity, action in (("a", [0, 0], None), ("b", [0.03, 0], 0),
                                      ("c", [0, 0.03], 9))
    ]
    episodes = [{**episode, "learn": True, "frames": samples},
                {**episode, "frames": [*samples[:2], {**samples[2], "image": "blank"}]}]
    replay(controller, episodes, frames.__getitem__)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--demo", action="store_true", help="Use packaged camera panels with sample motion")
    mode.add_argument("--input", type=Path, help="JSON experiment and references to grayscale image files")
    parser.add_argument("--model-dir", type=Path, default=Path(__file__).resolve().parents[2] / "models")
    args = parser.parse_args()
    if args.demo:
        demo(build_controller(args.model_dir, {}))
        return

    manifest = json.loads(args.input.read_text(encoding="utf-8"))

    def read_image(value):
        path = args.input.parent / value
        image = cv2.imdecode(np.frombuffer(path.read_bytes(), dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
        if image is None:
            raise ValueError(f"Cannot decode image {path}")
        return image

    replay(build_controller(args.model_dir, manifest), manifest["episodes"], read_image)


if __name__ == "__main__":
    main()
