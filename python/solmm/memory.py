"""Visual state neurons, episodic memory, and offline route reorganization."""

from collections import deque
from dataclasses import dataclass, field
from math import atan2, log, radians

import cv2
import numpy as np

from ..sift_check.run_check import ratio_matches
from .spatial import SpatialReading


class SiftVision:
    def __init__(self):
        self.sift = cv2.SIFT_create()
        self.matcher = cv2.BFMatcher(cv2.NORM_L2)

    def describe(self, gray_image):
        if gray_image.ndim != 2 or gray_image.dtype != np.uint8 or not gray_image.size:
            raise ValueError("Expected a nonempty 8-bit grayscale image")
        return self.sift.detectAndCompute(gray_image, None)[1]

    def score(self, first, second):
        if first is None or second is None or min(len(first), len(second)) < 2:
            return 0.0
        forward = ratio_matches(self.matcher, first, second)
        reverse = ratio_matches(self.matcher, second, first)
        return sum((j, i) in reverse for i, j in forward) / max(len(first), len(second))


@dataclass(frozen=True)
class Thresholds:
    grid: float = 0.60
    place: float = 0.30
    familiarity: float = 0.60
    turn_deg: float = 10.0
    span_m: float = 0.40
    state_activity: float = 0.10
    context_error: float = 0.40

    def __post_init__(self):
        for value in (self.grid, self.place, self.familiarity,
                      self.state_activity, self.context_error):
            if not 0 < value <= 1:
                raise ValueError("Activity, familiarity and context thresholds belong to (0, 1]")
        if not (0 < self.turn_deg <= 180 and np.isfinite(self.span_m) and self.span_m > 0):
            raise ValueError("Invalid offline angle or distance threshold")


@dataclass
class StateNeuron:
    descriptors: np.ndarray
    level: float = 0.0
    age: int = 0
    transitions: dict[int, float] = field(default_factory=dict)


@dataclass(frozen=True)
class MemoryItem:
    descriptors: np.ndarray
    state_index: int
    spatial: SpatialReading
    arrival_action: int | None


@dataclass(frozen=True)
class Retrieval:
    state_index: int | None
    familiarity: float
    margin: float
    context_error: float | None
    action: int | None


def retained_indices(positions, turn_deg, span_m):
    """Greedy replay with wrapped angle and distance between shortcut endpoints."""
    keep = [0] if len(positions) else []
    for index in range(1, len(positions) - 1):
        before, middle, after = positions[keep[-1]], positions[index], positions[index + 1]
        first, second = middle - before, after - middle
        cross = first[0] * second[1] - first[1] * second[0]
        turn = abs(atan2(cross, first @ second))
        if (not first.any() or not second.any() or turn >= radians(turn_deg)
                or np.linalg.norm(after - before) >= span_m):
            keep.append(index)
    if len(positions) > 1:
        keep.append(len(positions) - 1)
    return keep


class EpisodicMemory:
    def __init__(self, vision, thresholds=Thresholds(), context_frames=1,
                 decay_a=3.0, decay_mu=0.0):
        if (not isinstance(context_frames, int) or context_frames < 1
                or not np.isfinite(decay_a) or decay_a <= 0
                or not np.isfinite(decay_mu) or log(1 + decay_a) - decay_mu <= 1):
            raise ValueError("Provide a positive context length and an attenuating state decay")
        self.vision = vision
        self.thresholds = thresholds
        self.decay_a = decay_a
        self.decay_mu = decay_mu
        self.context = deque(maxlen=context_frames)
        self.neurons = []
        self.fragments = []
        self.pending = []
        self.candidates = {}

    def _familiarity(self, descriptors):
        scores = [self.vision.score(descriptors, neuron.descriptors) for neuron in self.neurons]
        if not scores:
            return None, 0.0
        index = int(np.argmax(scores))
        return index, scores[index]

    def _decay(self):
        for neuron in self.neurons:
            if neuron.level <= self.thresholds.state_activity:
                neuron.level = 0.0
            else:
                neuron.age += 1
                neuron.level /= log(neuron.age + self.decay_a) - self.decay_mu

    def reset_context(self):
        self.context.clear()
        for neuron in self.neurons:
            neuron.level = 0.0
            neuron.age = 0

    def observe(self, descriptors, spatial, arrival_action=None, learn=False):
        """Retrieve from completed fragments, then optionally record the current item."""
        state_index, score = self._familiarity(descriptors)
        margin = score - self.thresholds.familiarity
        error, action = (None, None)
        if margin >= 0:
            error, action = self._retrieve(state_index, descriptors)

        at_memory_node = (max(spatial.grid_activity) > self.thresholds.grid
                          and spatial.place_activation > self.thresholds.place)
        if learn:
            self._decay()
            if at_memory_node and descriptors is not None and len(descriptors) >= 2:
                if margin < 0:
                    state_index = len(self.neurons)
                    self.neurons.append(StateNeuron(descriptors))
                for index, neuron in enumerate(self.neurons):
                    if index != state_index and neuron.level > 0:
                        old = neuron.transitions.get(state_index, 0.0)
                        neuron.transitions[state_index] = old + neuron.level
                neuron = self.neurons[state_index]
                neuron.level, neuron.age = 1.0, 0
                self.pending.append(MemoryItem(descriptors, state_index, spatial, arrival_action))
        if at_memory_node:
            self.context.append(descriptors)
        return Retrieval(state_index, score, margin, error, action)

    def _retrieve(self, state_index, descriptors):
        required = self.context.maxlen
        if len(self.context) < required:
            return None, None
        observations = (*self.context, descriptors)
        best_error, best_action = None, None
        for fragment, index in self.candidates.get(state_index, ()):
            following = fragment[index + 1].arrival_action
            if following is None:
                continue
            stored = fragment[index - required:index + 1]
            similarity = min(self.vision.score(query, item.descriptors)
                             for query, item in zip(observations, stored))
            error = 1.0 - similarity
            if best_error is None or error < best_error:
                best_error, best_action = error, following
        if best_error is None or best_error >= self.thresholds.context_error:
            return best_error, None
        return best_error, best_action

    def finish_episode(self, reorganize=True):
        """Archive the completed fragment and index states with a successor."""
        positions = np.array([item.spatial.position_m for item in self.pending])
        indices = (retained_indices(positions, self.thresholds.turn_deg, self.thresholds.span_m)
                   if reorganize else range(len(self.pending)))
        fragment = tuple(self.pending[index] for index in indices)
        removed = len(self.pending) - len(fragment)
        self.pending.clear()
        if fragment:
            self.fragments.append(fragment)
            for index in range(self.context.maxlen, len(fragment) - 1):
                state = fragment[index].state_index
                self.candidates.setdefault(state, []).append((fragment, index))
        self.reset_context()
        return len(fragment), removed
