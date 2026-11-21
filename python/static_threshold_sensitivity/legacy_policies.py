"""Inference from the archived MDN2 and dh_test model weights."""

import numpy as np
from scipy.io import loadmat


ANGLES = np.deg2rad(np.arange(0, 360, 10))
DIRECTIONS = np.column_stack((np.cos(ANGLES), np.sin(ANGLES)))


def angle(vector):
    return float(np.arctan2(vector[1], vector[0]))


def direction(vector):
    """Nearest motion direction, with circular comparison for replay."""
    return int(np.argmax(DIRECTIONS @ vector))


def legacy_direction(heading):
    return int(np.argmin(np.abs(ANGLES - heading)))


def weights(neurons, field, normalize=False):
    matrix = np.column_stack([np.ravel(getattr(n, field)) for n in neurons])
    if normalize:
        matrix = matrix / np.maximum(np.linalg.norm(matrix, axis=0), 1e-12)
    return matrix


def polar_input(goal_heading, obstacle_heading, goal_range, obstacle_range):
    span = goal_range + obstacle_range
    features = np.array([np.cos(goal_heading), np.sin(goal_heading),
                         np.cos(obstacle_heading), np.sin(obstacle_heading),
                         goal_range / span, obstacle_range / span])
    return features / np.linalg.norm(features)


class LegacyPolicies:
    def __init__(self, model_dir):
        mdn = loadmat(model_dir / "nice_mdn2_model.mat", simplify_cells=False,
                      squeeze_me=True, struct_as_record=False)["network"]
        fallback = loadmat(model_dir / "goodmodel.mat", simplify_cells=False,
                           squeeze_me=True, struct_as_record=False)["network"]
        self.mdn = {
            k: (weights(getattr(mdn.Y, f"y_100_{k}_neuron"), f"X_Y_100_{k}_weight", True),
                weights(getattr(mdn.Y, f"y_011_{k}_neuron"), f"Y_100_{k}_Y_011_{k}_weight", True),
                weights(getattr(mdn.Z, f"z_{k}_neuron"), f"Y_011_{k}_Z_weight"))
            for k in "ups"
        }
        self.fallback = {
            k: (weights(getattr(fallback.Y, f"y_{k}_neuron"), "X_Y_weight", True),
                weights(getattr(fallback.Z, f"z_{k}_neuron"), "Y_Z_weight"))
            for k in "ups"
        }

    def fallback_action(self, goal_vector, obstacles):
        goal_range = np.linalg.norm(goal_vector)
        goal_heading = angle(goal_vector)
        ranges = np.linalg.norm(obstacles, axis=1)
        order = np.argsort(ranges, kind="stable")
        closest = order[0]
        if ranges[closest] >= 110:
            return legacy_direction(goal_heading)
        if ranges[closest] > 65:
            # dh_test uses positive-quadrant candidates and stops after a
            # candidate occurs at the fourth (or later) sorted obstacle.
            candidates = []
            for rank, i in enumerate(order):
                if np.all(obstacles[i] > 0) and ranges[i] < 150:
                    candidates.append(i)
                    if rank >= 3:
                        break
            if not candidates:
                return legacy_direction(goal_heading)
            headings = np.arctan2(obstacles[candidates, 1], obstacles[candidates, 0])
            gaps = np.maximum(np.abs(headings - goal_heading), 1e-12)
            cost = 0.78 * ranges[candidates] / 110 + 0.22 * (np.pi / 2) / gaps
            closest = candidates[int(np.argmin(cost))]
        obstacle_range = ranges[closest]
        obs = polar_input(goal_heading, angle(obstacles[closest]), goal_range, obstacle_range)
        responses = {}
        for k in "ups":
            if (k == "p" and obstacle_range > 0.65) or (k == "s" and goal_range <= 0.25):
                responses[k] = 0.0
                continue
            model, actions = self.fallback[k]
            responses[k] = actions[int(np.argmax(obs @ model))]
        score = responses["u"] * (1 + 3 * responses["s"] - 8 * responses["p"])
        return int(np.argmax(np.maximum(score, 0)))

    def mdn_action(self, goal_vector, obstacles):
        goal_range = np.linalg.norm(goal_vector)
        goal_heading = angle(goal_vector) % (2 * np.pi)
        ranges = np.linalg.norm(obstacles, axis=1)
        closest = int(np.argmin(ranges))
        obstacle_range = ranges[closest]
        obstacle_heading = angle(obstacles[closest]) % (2 * np.pi)
        if obstacle_range >= 300 or abs(goal_heading - obstacle_heading) > np.pi / 2:
            return legacy_direction(goal_heading)
        obs = polar_input(goal_heading, obstacle_heading, goal_range, obstacle_range)
        responses = {}
        for k in "ups":
            if (k == "p" and obstacle_range > 65) or (k == "s" and goal_range < 45):
                responses[k] = 0.0
                continue
            model, states, actions = self.mdn[k]
            winners = np.argsort(-(obs @ model), kind="stable")[:6]
            state = int(np.argmax(states[winners].sum(axis=0)))
            responses[k] = actions[state]
        score = responses["u"] * (1 + 3 * responses["s"] - 10 * responses["p"])
        return int(np.argmax(np.maximum(score, 0)))

    def training_action(self, goal_vector, obstacles):
        """Archived progress/clearance rule for collecting shared routes."""
        memory = self.mdn_action(goal_vector, obstacles)
        fallback = self.fallback_action(goal_vector, obstacles)
        moves = 10 * DIRECTIONS[[memory, fallback]]
        clearance = np.linalg.norm(obstacles[None, :, :] - moves[:, None, :], axis=2).min(axis=1)
        unsafe = clearance <= 22
        if unsafe.any():
            return memory if clearance[0] > clearance[1] else fallback
        score = -0.60 * np.linalg.norm(goal_vector - moves, axis=1) + 0.40 * clearance
        return memory if score[0] > score[1] else fallback
