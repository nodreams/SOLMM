"""Spatial activity and path integration for SOLMM."""

from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class SpatialReading:
    position_m: tuple[float, float]
    heading_rad: float
    grid_activity: tuple[float, ...]
    place_activation: float
    place_index: int
    place_input: float
    place_firing_rate: float


class SpatialEncoder:
    def __init__(self, centers_m, wavelengths_m=(1.2, 1.8),
                 orientations_rad=(0.0, np.pi / 9), rho_m=0.45,
                 learning_rate=0.01, inhibition=0.2):
        self.centers = np.asarray(centers_m, dtype=float)
        wavelengths = np.asarray(wavelengths_m, dtype=float)
        orientations = np.asarray(orientations_rad, dtype=float)
        if (self.centers.ndim != 2 or self.centers.shape[1] != 2
                or not len(self.centers) or not np.isfinite(self.centers).all()
                or wavelengths.ndim != 1 or not len(wavelengths)
                or wavelengths.shape != orientations.shape
                or not np.isfinite(wavelengths).all() or np.any(wavelengths <= 0)
                or not np.isfinite(orientations).all()):
            raise ValueError("Provide finite 2-D place centers and paired grid scales/orientations")
        if not (np.isfinite(rho_m) and rho_m > 0 and 0 <= inhibition <= 1
                and np.isfinite(learning_rate) and learning_rate >= 0):
            raise ValueError("Invalid place field or learning parameters")
        self.rho = rho_m
        self.learning_rate = learning_rate
        self.wave_number = 4 * np.pi / (np.sqrt(3) * wavelengths)
        spatial_angles = orientations[:, None] + (2 * np.pi / 3) * np.arange(3)
        temporal_angles = orientations[:, None] + (np.pi / 3) * np.arange(2)
        self.spatial_axes = np.stack((np.cos(spatial_angles), np.sin(spatial_angles)), axis=-1)
        self.temporal_axes = np.stack((np.cos(temporal_angles), np.sin(temporal_angles)), axis=-1)
        prototypes = self.grid_field(self.centers)
        self.weights = self._normalize(np.maximum(prototypes, np.finfo(float).eps))
        self.inhibitory_weights = inhibition * self._normalize(
            np.maximum(1 - prototypes, np.finfo(float).eps))
        self.mean_activity = np.zeros(len(wavelengths))
        self.samples = 0
        self.reset_pose((0.0, 0.0), 0.0)

    @staticmethod
    def _normalize(weights):
        return weights / np.linalg.norm(weights, axis=-1, keepdims=True)

    def grid_field(self, positions_m):
        """Three preferred directions give the spatial firing pattern E(r)."""
        phase = np.einsum("...d,gsd->...gs", positions_m, self.spatial_axes)
        phase *= self.wave_number[:, None]
        return np.clip((2 / 3) * (np.cos(phase).mean(axis=-1) + 0.5), 0, 1)

    def reset_pose(self, position_m, heading_rad):
        position = np.asarray(position_m, dtype=float)
        if position.shape != (2,) or not np.isfinite(position).all() or not np.isfinite(heading_rad):
            raise ValueError("Provide a finite 2-D starting position and heading")
        self.position = position.copy()
        self.heading = float(heading_rad)
        self.phase = np.einsum("gsd,d->gs", self.temporal_axes, self.position)
        self.phase *= self.wave_number[:, None]

    def advance(self, velocity_body_m_s, angular_rad_s, dt_s):
        """Integrate a constant body-frame planar twist over one interval."""
        velocity = np.asarray(velocity_body_m_s, dtype=float)
        if (velocity.shape != (2,) or not np.isfinite(velocity).all()
                or not np.isfinite(angular_rad_s) or not np.isfinite(dt_s) or dt_s < 0):
            raise ValueError("Provide a finite planar twist and nonnegative elapsed time")
        turn = angular_rad_s * dt_s
        midpoint = self.heading + turn / 2
        cosine, sine = np.cos(midpoint), np.sin(midpoint)
        rotation = np.array([[cosine, -sine], [sine, cosine]])
        displacement = dt_s * np.sinc(turn / (2 * np.pi)) * (rotation @ velocity)
        self.position += displacement
        self.heading = float((self.heading + turn + np.pi) % (2 * np.pi) - np.pi)
        phase_change = np.einsum("gsd,d->gs", self.temporal_axes, displacement)
        self.phase = (self.phase + self.wave_number[:, None] * phase_change) % (2 * np.pi)

    def read(self, learn=False):
        activity = np.prod((1 + np.cos(self.phase)) / 2, axis=1)
        field = self.grid_field(self.position)
        synaptic_input = self.weights @ field - self.inhibitory_weights @ (1 - field)
        winner = int(np.argmax(synaptic_input))
        offset = self.position - self.centers[winner]
        firing = np.exp(-(offset @ offset) / (2 * self.rho ** 2))
        if learn:
            update = self.learning_rate * synaptic_input[winner] * (field - self.mean_activity)
            weights = np.maximum(self.weights[winner] + update, np.finfo(float).eps)
            self.weights[winner] = self._normalize(weights)
            self.samples += 1
            self.mean_activity += (field - self.mean_activity) / self.samples
        return SpatialReading(tuple(map(float, self.position)), self.heading,
                              tuple(map(float, activity)), float(np.prod(activity)),
                              winner, float(synaptic_input[winner]), float(firing))
