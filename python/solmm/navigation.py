"""Navigation decisions for synchronized camera, odometry and LiDAR samples."""

from dataclasses import dataclass
from numbers import Integral

import numpy as np

from ..static_threshold_sensitivity.legacy_policies import LegacyPolicies, direction
from .memory import Retrieval
from .spatial import SpatialReading


class ArchivedFallback:
    """Use the fixed fallback policy packaged with the sensitivity experiment."""

    def __init__(self, models):
        self.policies = LegacyPolicies(models)

    def __call__(self, goal_vector_m, obstacles_m):
        if not len(obstacles_m):
            return direction(goal_vector_m)
        return self.policies.fallback_action(100 * goal_vector_m, 100 * obstacles_m)


@dataclass(frozen=True)
class Decision:
    action: int | None
    source: str
    spatial: SpatialReading
    retrieval: Retrieval


class NavigationController:
    def __init__(self, encoder, memory, fallback, goal_radius_m=0.15):
        if not np.isfinite(goal_radius_m) or goal_radius_m <= 0:
            raise ValueError("Goal radius must be positive")
        self.encoder = encoder
        self.memory = memory
        self.fallback = fallback
        self.goal_radius_m = goal_radius_m

    def begin_episode(self, start_m, heading_rad=0.0):
        if self.memory.pending:
            raise RuntimeError("Finish the learning episode before starting another")
        self.encoder.reset_pose(start_m, heading_rad)
        self.memory.reset_context()

    def step(self, gray_image, velocity_body_m_s, angular_rad_s, dt_s, goal_m,
             lidar_body_m, arrival_action=None, learn=False):
        goal = np.asarray(goal_m, dtype=float)
        points = np.asarray(lidar_body_m, dtype=float)
        if points.shape == (0,):
            points = points.reshape(0, 2)
        if (goal.shape != (2,) or not np.isfinite(goal).all() or points.ndim != 2
                or points.shape[1] != 2 or not np.isfinite(points).all()):
            raise ValueError("Provide a finite 2-D goal and finite LiDAR XY points")
        if arrival_action is not None:
            self._validate_action(arrival_action)

        self.encoder.advance(velocity_body_m_s, angular_rad_s, dt_s)
        spatial = self.encoder.read(learn)
        descriptors = self.memory.vision.describe(gray_image)
        retrieval = self.memory.observe(descriptors, spatial, arrival_action, learn)
        goal_vector = goal - spatial.position_m
        if np.linalg.norm(goal_vector) < self.goal_radius_m:
            return Decision(None, "goal", spatial, retrieval)
        if retrieval.action is not None:
            return Decision(retrieval.action, "memory", spatial, retrieval)

        cosine, sine = np.cos(spatial.heading_rad), np.sin(spatial.heading_rad)
        rotation = np.array([[cosine, -sine], [sine, cosine]])
        obstacles = points @ rotation.T
        obstacles = obstacles[np.any(obstacles != 0, axis=1)]
        action = self.fallback(goal_vector, obstacles)
        self._validate_action(action)
        return Decision(int(action), "fallback", spatial, retrieval)

    @staticmethod
    def _validate_action(action):
        if isinstance(action, bool) or not isinstance(action, Integral) or not 0 <= action < 36:
            raise ValueError("Expected a discrete action index between 0 and 35")

    def finish_episode(self, reorganize=True):
        return self.memory.finish_episode(reorganize)
