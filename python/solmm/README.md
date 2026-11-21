# SOLMM navigation

The SOLMM module implements spatial encoding, episodic memory, and navigation control as described in Sections 3–4. Use the replay entry point to run it on synchronized camera, odometry and LiDAR observations.

From the repository root:

```sh
python -m pip install -r python/requirements.txt
python -m python.solmm --demo
python -m unittest python.solmm.test_solmm
```

The demo combines camera panels from the manuscript with example motion and scan inputs. It records one fragment, then shows the fallback on the first frame without context, the stored action on a context match, and fallback on an unfamiliar frame. It writes one JSON object per decision and an episode summary to standard output. It does not connect to ROS.

## Code map

| Manuscript | Implementation |
| --- | --- |
| Spatial activity and path integration | `spatial.py` integrates a body-frame planar twist and projects displacement onto the two VCO directions per scale. It also computes the three-direction spatial firing pattern, excitatory and inhibitory input to place cells, the winning cell's Gaussian field, and the normalized Hebbian update. |
| Memory generation and state decay | `memory.py` extracts SIFT descriptors, normalizes mutual ratio-test matches by the larger descriptor count, and uses the familiarity margin to select or add a visual state. The spatial activity gate controls which items are recorded. State activation decays by the logarithmic recurrence and active states accumulate directed transition weights. |
| Offline reorganization | `retained_indices` compares the wrapped angle and span of two segments, using strict thresholds. It keeps endpoints and retains the surviving items' stored actions. |
| Contextual retrieval and controller switching | `EpisodicMemory` compares the current and previous eligible observations to aligned stored items, takes the minimum SIFT similarity, and retrieves the following item's stored action if the context error passes. `NavigationController` sends unmatched scenes to the fixed archived fallback, using relative goal displacement and LiDAR coordinates rotated into the map frame. |

The default thresholds are `0.60` for the maximum grid-cell activity, `0.30` for the product of grid activities, `0.60` for scene familiarity, `10°` and `0.40 m` for offline reorganization, and `0.10` for state activity. The SIFT matcher uses the `0.75` mutual ratio test from the manuscript's SIFT check. The manuscript leaves several implementation choices open. This version uses a one-observation history drawn from spatially eligible frames, strict context error below `0.40`, logarithmic decay constants `a=3` and `mu=0`, two wavelengths of `1.2 m` and `1.8 m`, and place centers on a one-metre lattice. The spatial parameters and thresholds can be overridden in the input manifest. The fallback reuses the existing Python port of the fixed policy and converts metres to its internal centimetre coordinates. A caller can supply a different fallback callable to `NavigationController`.

## Replay your own observations

Run `python -m python.solmm --input replay.json`. An input contains synchronized observation sequences, grouped by episode. Image paths are resolved relative to the JSON file. LiDAR points are XY offsets in the robot body frame in metres, transformed from the sensor frame before input. The pose and goal are expressed in the same map frame. Velocity and elapsed time describe the interval since the prior frame. Set `arrival_action` to the action that actually led to the frame when recording training observations. Use `null` for the first observation. Python actions are indexed from `0` through `35`, corresponding to `0°` through `350°` counterclockwise in the map frame.

```json
{
  "episodes": [
    {
      "start_m": [0, 0], "heading_rad": 0, "goal_m": [2, 1],
      "learn": true, "reorganize": true,
      "frames": [
        {
          "image": "frames/001.png", "velocity_body_m_s": [0, 0],
          "angular_rad_s": 0, "dt_s": 0, "lidar_body_m": [[0.7, 0.1]],
          "arrival_action": null
        }
      ]
    }
  ]
}
```

Add further frames to record a sequence and later episodes with `learn: false` to evaluate retrieval. Completed fragments are available to subsequent episodes within the same replay. Optional top-level `spatial`, `thresholds`, and `memory` objects override the arguments in `SpatialEncoder`, `Thresholds`, and `EpisodicMemory`, respectively.
