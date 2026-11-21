from math import radians
from unittest import TestCase

import numpy as np

from .memory import EpisodicMemory, retained_indices
from .spatial import SpatialEncoder, SpatialReading


class SolmmTests(TestCase):
    def test_constant_twist_and_grid_activation(self):
        encoder = SpatialEncoder([(0, 0)])
        encoder.advance([1, 0], np.pi / 2, 1)
        reading = encoder.read()
        np.testing.assert_allclose(reading.position_m, [2 / np.pi, 2 / np.pi])
        self.assertAlmostEqual(reading.heading_rad, np.pi / 2)
        self.assertAlmostEqual(reading.place_activation, np.prod(reading.grid_activity))
        self.assertAlmostEqual(reading.place_firing_rate, np.exp(-4 / np.pi ** 2 / 0.45 ** 2))

    def test_shortcut_turn_wrap_and_strict_span(self):
        headings = np.array([radians(179), radians(-179)])
        displacements = 0.1 * np.column_stack((np.cos(headings), np.sin(headings)))
        positions = np.vstack(([0, 0], np.cumsum(displacements, axis=0)))
        self.assertEqual(retained_indices(positions, 10, 0.4), [0, 2])
        at_distance_limit = np.array([[0, 0], [0.2, 0], [0.4, 0]])
        self.assertEqual(retained_indices(at_distance_limit, 10, 0.4), [0, 1, 2])

    def test_context_disambiguates_the_same_state_and_reads_successor_action(self):
        class ExactVision:
            @staticmethod
            def score(first, second):
                return float(np.array_equal(first, second))

        memory = EpisodicMemory(ExactVision())
        spatial = SpatialReading((0, 0), 0, (1, 1), 1, 0, 1, 1)
        previous_a, previous_b, current, following = [np.full((2, 1), i) for i in range(4)]
        for previous, action in ((previous_a, 3), (previous_b, 17)):
            memory.observe(previous, spatial, learn=True)
            memory.observe(current, spatial, 0, learn=True)
            memory.observe(following, spatial, action, learn=True)
            self.assertEqual(memory.finish_episode(reorganize=False), (3, 0))
        for previous, action in ((previous_a, 3), (previous_b, 17)):
            memory.observe(previous, spatial)
            decision = memory.observe(current, spatial)
            self.assertEqual(decision.action, action)
            self.assertEqual(decision.context_error, 0)
            memory.reset_context()
        memory.observe(following, spatial)
        self.assertIsNone(memory.observe(current, spatial).action)
        memory.reset_context()
        self.assertIsNone(memory.observe(current, spatial).action)
