"""Run paired static sensitivity trials in a simulated SIFT/replay adapter."""

import argparse
import csv
from dataclasses import dataclass, asdict
from datetime import datetime
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np

from legacy_policies import DIRECTIONS, LegacyPolicies, direction


HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parents[1] / "models"
BASE_OBSTACLES = np.array([
    [55, 190], [85, 282], [111, 365], [123, 57], [136, 342], [146, 150],
    [154, 394], [203, 270], [214, 95], [226, 218], [244, 350], [249, 107],
    [254, 270], [283, 228], [285, 293], [304, 232], [318, 289], [338, 408],
    [343, 110], [381, 231], [418, 389], [422, 330], [432, 251],
], dtype=float)
START = np.array([50, 50])
GOAL = np.array([450, 450])
WORLD_SIZE_CM = 500
STEP_CM = 10
GOAL_CM = 15
COLLISION_CM = 14
TRAIN_COLLISION_BUFFER_CM = 3
MAX_STEPS = 150
VIEW_RADIUS_CM = 72
MATCH_RADIUS_CM = 25
MATCH_CANDIDATES = 4
SIFT_RATIO = 0.75


@dataclass(frozen=True)
class Setting:
    setting: str
    mu_e: float = 0.60
    mu_dir_deg: float = 10.0
    mu_dis_m: float = 0.40


SETTINGS = (
    Setting("baseline"),
    Setting("familiarity_050", mu_e=0.50),
    Setting("familiarity_070", mu_e=0.70),
    Setting("angle_05deg", mu_dir_deg=5.0),
    Setting("angle_15deg", mu_dir_deg=15.0),
    Setting("distance_030m", mu_dis_m=0.30),
    Setting("distance_050m", mu_dis_m=0.50),
)


def compress_route(route, setting):
    """Keep endpoints and drop intermediate positions that pass both tests."""
    keep = [0]
    for i in range(1, len(route) - 1):
        before, middle, after = route[keep[-1]], route[i], route[i + 1]
        first, second = middle - before, after - middle
        cross = first[0] * second[1] - first[1] * second[0]
        turn = abs(np.rad2deg(np.arctan2(cross, first @ second)))
        if (not first.any() or not second.any() or turn >= setting.mu_dir_deg
                or np.linalg.norm(after - before) >= 100 * setting.mu_dis_m):
            keep.append(i)
    keep.append(len(route) - 1)
    return route[keep]


class Scene:
    def __init__(self, floor, obstacles, sift):
        self.obstacles = obstacles
        self.sift = sift
        image = floor.copy()
        for x, y in np.floor(obstacles + 0.5).astype(int):
            cv2.circle(image, (int(x), int(y)), 6, 35, -1, cv2.LINE_AA)
            cv2.circle(image, (int(x), int(y)), 3, 220, -1, cv2.LINE_AA)
        self.image = cv2.copyMakeBorder(image, VIEW_RADIUS_CM, VIEW_RADIUS_CM,
                                        VIEW_RADIUS_CM, VIEW_RADIUS_CM,
                                        cv2.BORDER_CONSTANT, value=20)
        self.descriptors = {}

    def features(self, position):
        x, y = map(int, position)
        if (x, y) not in self.descriptors:
            width = 2 * VIEW_RADIUS_CM + 1
            view = self.image[y:y + width, x:x + width]
            self.descriptors[x, y] = self.sift.detectAndCompute(view, None)[1]
        return self.descriptors[x, y]


def ratio_matches(matcher, first, second):
    return {(a.queryIdx, a.trainIdx) for a, b in matcher.knnMatch(first, second, k=2)
            if a.distance < SIFT_RATIO * b.distance}


def similarity(matcher, first, second):
    if first is None or second is None or min(len(first), len(second)) < 2:
        return 0.0
    forward = ratio_matches(matcher, first, second)
    reverse = ratio_matches(matcher, second, first)
    return sum((j, i) in reverse for i, j in forward) / max(len(first), len(second))


class ReplayMemory:
    def __init__(self, routes, scene, setting):
        entries = {}
        self.removed = 0
        for route in routes:
            retained = compress_route(route, setting)
            self.removed += len(route) - len(retained)
            for point, target in zip(retained, retained[1:]):
                entries.setdefault((tuple(point), tuple(target)), None)
        self.positions = np.array([point for point, _ in entries]).reshape(-1, 2)
        self.targets = np.array([target for _, target in entries]).reshape(-1, 2)
        self.features = [scene.features(point) for point in self.positions]
        self.threshold = setting.mu_e

    def lookup(self, position, scene, matcher, cache):
        distances = np.sum((self.positions - position) ** 2, axis=1)
        indices = np.flatnonzero(distances <= MATCH_RADIUS_CM ** 2)
        if not len(indices):
            return None
        indices = indices[np.argsort(distances[indices], kind="stable")[:MATCH_CANDIDATES]]
        query = scene.features(position)
        best_index, best_score = None, 0.0
        for index in indices:
            # Key by positions rather than setting: descriptors for this
            # paired scenario are identical wherever routes share a node.
            key = (tuple(position), tuple(self.positions[index]))
            if key not in cache:
                cache[key] = similarity(matcher, query, self.features[index])
            score = cache[key]
            if score > best_score:
                best_index, best_score = index, score
        if best_score < self.threshold or best_index is None:
            return None
        vector = self.targets[best_index] - position
        return direction(vector) if vector.any() else None


def run_episode(start, goal, obstacles, noise, action_at):
    position = start.copy()
    path = [position]
    memory_steps = 0
    status = "timeout"
    for step in range(MAX_STEPS):
        observed = obstacles + noise[step] - position
        action, replay = action_at(position, goal - position, observed)
        memory_steps += replay
        position = np.floor(position + STEP_CM * DIRECTIONS[action] + 0.5).astype(int)
        path.append(position)
        if (np.linalg.norm(obstacles - position, axis=1) < COLLISION_CM).any():
            status = "collision"
            break
        if (position < 0).any() or (position > WORLD_SIZE_CM).any():
            status = "out_of_bounds"
            break
        if np.linalg.norm(goal - position) < GOAL_CM:
            status = "success"
            break
    return status, np.asarray(path), memory_steps


def child_rng(seed, stage, episode=0):
    return np.random.default_rng(np.random.SeedSequence([seed, stage, episode]))


def make_floor(seed):
    rng = child_rng(seed, 0)
    noise = rng.integers(0, 256, (WORLD_SIZE_CM + 1,) * 2, dtype=np.uint8)
    smooth = cv2.GaussianBlur(noise, (0, 0), 1.4)
    return cv2.normalize(smooth, None, 45, 205, cv2.NORM_MINMAX)


def collect_action(position, goal_vector, observed, policies):
    """Use the archived policy with its optional training safety guard."""
    action = policies.training_action(goal_vector, observed)
    positions = np.floor(position + STEP_CM * DIRECTIONS + 0.5)
    moves = positions - position
    clearance = np.linalg.norm(observed[None, :, :] - moves[:, None, :], axis=2).min(axis=1)
    threshold = COLLISION_CM + TRAIN_COLLISION_BUFFER_CM
    inside = np.all((positions >= 0) & (positions <= WORLD_SIZE_CM), axis=1)
    safe = inside & (clearance > threshold)
    if safe[action] or not np.any(safe):
        return action, False
    indices = np.flatnonzero(safe)
    progress = np.linalg.norm(goal_vector) - np.linalg.norm(goal_vector - moves[indices], axis=1)
    score = 0.65 * progress + 0.35 * np.minimum(clearance[indices], 3 * threshold)
    return int(indices[np.argmax(score)]), False


def trials(seed, n_train, n_eval, policies, sift, matcher):
    floor = make_floor(seed)
    training_scene = Scene(floor, BASE_OBSTACLES, sift)
    routes = []
    for episode in range(n_train):
        rng = child_rng(seed, 1, episode)
        noise = rng.normal(0, 0.5, (MAX_STEPS, len(BASE_OBSTACLES), 2))
        status, path, _ = run_episode(
            START, GOAL, BASE_OBSTACLES, noise,
            lambda position, goal, obs: collect_action(position, goal, obs, policies),
        )
        if status == "success":
            routes.append(path)
    if not routes:
        raise RuntimeError(f"Seed {seed} collected no successful training routes; "
                           "the replay controller cannot be evaluated for this seed.")

    memories = {s.setting: ReplayMemory(routes, training_scene, s) for s in SETTINGS}
    for episode in range(n_eval):
        rng = child_rng(seed, 2, episode)
        obstacles = BASE_OBSTACLES + rng.uniform(-4, 4, BASE_OBSTACLES.shape)
        start = START + rng.integers(-8, 9, 2)
        goal = GOAL + rng.integers(-8, 9, 2)
        noise = rng.normal(0, 0.5, (MAX_STEPS, len(BASE_OBSTACLES), 2))
        scene = Scene(floor, obstacles, sift)
        scores = {}
        for setting in SETTINGS:
            memory = memories[setting.setting]

            def choose(position, goal_vector, observed):
                action = memory.lookup(position, scene, matcher, scores)
                if action is not None:
                    return action, True
                return policies.fallback_action(goal_vector, observed), False

            status, path, replay_steps = run_episode(start, goal, obstacles, noise, choose)
            yield {**asdict(setting), "seed": seed, "episode": episode + 1,
                   "scenario_id": f"{seed}-static-{episode + 1:02}",
                   "start_x_cm": int(start[0]), "start_y_cm": int(start[1]),
                   "goal_x_cm": int(goal[0]), "goal_y_cm": int(goal[1]),
                   "success": int(status == "success"), "status": status,
                   "steps": len(path) - 1, "memory_steps": replay_steps,
                   "stored_nodes": len(memory.positions), "removed_nodes": memory.removed,
                   "successful_training_routes": len(routes)}


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, default=MODEL_DIR)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--smoke", action="store_true", help="One seed, three training routes and two paired tests")
    args = parser.parse_args()
    n_seeds, n_train, n_eval = (1, 3, 2) if args.smoke else (10, 30, 10)
    seeds = list(range(20261120, 20261120 + n_seeds))
    out = args.output or HERE / "results" / (
        datetime.now().strftime("%Y%m%d_%H%M%S_%f") + ("_smoke" if args.smoke else "_main")
    )
    out.mkdir(parents=True, exist_ok=False)
    cv2.setNumThreads(1)
    policies = LegacyPolicies(args.model_dir)
    sift = cv2.SIFT_create(nfeatures=100)
    matcher = cv2.BFMatcher(cv2.NORM_L2)
    rows = []
    for seed in seeds:
        rows.extend(trials(seed, n_train, n_eval, policies, sift, matcher))
        write_csv(out / "episode_results.csv", rows)
        print(f"Finished seed {seed} ({len(rows)} evaluation records)", flush=True)
    expected = {f"{seed}-static-{episode:02}" for seed in seeds
                for episode in range(1, n_eval + 1)}
    summary = []
    for setting in SETTINGS:
        group = [r for r in rows if r["setting"] == setting.setting]
        assert len(group) == len(expected) and {r["scenario_id"] for r in group} == expected
        count = sum(r["success"] for r in group)
        summary.append({**asdict(setting), "successes": count, "trials": len(group),
                        "success_pct": round(100 * count / len(group), 4)})
        print(f"{setting.setting:18} {count:3}/{len(group)} ({count / len(group):.1%})")
    write_csv(out / "success_summary.csv", summary)
    manifest = {"protocol": "synthetic_top_down_sift_replay_adapter_v1",
                "seeds": seeds, "shared_route_collection_episodes_per_seed": n_train,
                "test_episodes_per_seed_per_setting": n_eval, "opencv": cv2.__version__,
                "settings": [asdict(s) for s in SETTINGS],
                "world_size_cm": WORLD_SIZE_CM, "step_cm": STEP_CM,
                "goal_cm": GOAL_CM, "collision_cm": COLLISION_CM,
                "collection_safety_buffer_cm": TRAIN_COLLISION_BUFFER_CM,
                "view_radius_cm": VIEW_RADIUS_CM, "spatial_shortlist_radius_cm": MATCH_RADIUS_CM,
                "spatial_shortlist_size": MATCH_CANDIDATES, "sift_ratio": SIFT_RATIO,
                "model_sha256": {name: hashlib.sha256((args.model_dir / name).read_bytes()).hexdigest()
                                 for name in ("goodmodel.mat", "nice_mdn2_model.mat")}}
    (out / "protocol.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Results: {out.resolve()}")


if __name__ == "__main__":
    main()
