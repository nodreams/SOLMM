# SOLMM mobile robot navigation

Research code associated with the manuscript *Behavioral decision-making of mobile robot by simulating the cognitive mechanism of hippocampus and entorhinal cortex*. This package contains archived MATLAB controllers and simulation protocols, revision-stage Python checks, and the SOLMM navigation module.

## Repository contents

| Path | Contents and provenance |
| --- | --- |
| `matlab/legacy_mdn22/` | Archived developmental-network inference, fallback control, controller selection, and offline memory-reorganization routines from `MDN22`. The `historical_runs/` subdirectory contains the earlier hybrid and memory-reorganization experiment drivers. |
| `matlab/ablation/` | Archived MATLAB implementation of the static and dynamic four-variant simulations, from `仿真实验/ablation_reorganization`. The executable settings are in `default_ablation_config.m`. |
| `matlab/robot_archive/` | ROS 1 geometric navigation and offline controller inference from `MDN22`. Includes a recovered DN3 inference routine and a recorded map and obstacle trajectory. |
| `models/` | Initial memory checkpoint (`nice_mdn2_model.mat`), fixed fallback checkpoint (`goodmodel.mat`), reorganized memory checkpoint (`gongguMDN2.mat`), and recovered historical files (`shiwushiyan_model.mat`, `yuanshiMDN2.mat`). |
| `python/static_threshold_sensitivity/` | Revision-stage static sensitivity experiment. This adaptation extracts SIFT from synthetic overhead images and builds replay memory from shared successful trajectories. |
| `python/sift_check/` | Revision-stage image-level SIFT check using the three camera panels embedded in the supplied PDF figure. |
| [`python/solmm/`](python/solmm/README.md) | SOLMM navigation and episodic memory from Sections 3–4, with grid/place activity, visual state neurons, contextual action retrieval and geometric memory reorganization. |

## MATLAB ablation simulation

Open MATLAB in the repository root. The documented entry points use the packaged checkpoints and the 5 m by 5 m point-obstacle layouts.

~~~matlab
addpath(fullfile(pwd, 'matlab', 'ablation'))

% Short integration runs
smoke_test_static_random();
smoke_test_dynamic_random();

% Archived full protocols
staticRun = run_static_random_ablation();
dynamicRun = run_dynamic_random_ablation();
~~~

Each run saves its resolved configuration, episode records, summaries, and selected trajectory plots under a timestamped directory. The per-variant memory checkpoints are working copies in the run directory. The archived geometry-based simulator supplies relative obstacle measurements to its controllers. Its default `legacy_equivalent` fallback invokes `dh_test` with a fixed checkpoint.

The static and dynamic random-point modes reproduce the archived geometric protocol. The memory controller receives relative goal and obstacle geometry. The switching rule compares predicted obstacle clearance and goal progress. During training the offline update calls `fxxz` to identify candidate action corrections and `memorycons` to apply them to the working checkpoint. `SOLMM-NoReorg` skips those weight updates. The optional `paper_smoke` mode uses the recovered ROS map and measured obstacle trajectory.

The older scripts under `historical_runs/` are preserved for provenance. To inspect their behavior in MATLAB, use an isolated working directory with copies of `goodmodel.mat` and `gongguMDN2.mat`, and put `legacy_mdn22/` on the MATLAB path. They can update the working memory checkpoint and write Excel summaries in the working directory.

## Python checks

Python 3.12 was used with the dependency versions in `python/requirements.txt`. Run these commands from the repository root:

~~~sh
python -m pip install -r python/requirements.txt
python python/static_threshold_sensitivity/run_static_threshold_sensitivity.py --smoke
python python/static_threshold_sensitivity/run_static_threshold_sensitivity.py
python python/sift_check/run_check.py
~~~

The navigation script writes `protocol.json`, `episode_results.csv` and `success_summary.csv`. The image-level script prints JSON. The sensitivity adaptation uses its own static protocol, with synthetic grayscale imagery and spatially shortlisted replay candidates. Its output applies to that simulation configuration.

## Physical robot archive

`response_dn2(agent, laserMap, goal)` evaluates the recovered geometric controller in MATLAB without ROS. Position, obstacle coordinates and goal are in metres in the map frame. The routine loads the packaged checkpoints and returns a map heading in degrees. `rosdn2(goal, maxSteps)` supplies live LiDAR and odometry to that controller using ROS 1 and a configured transform tree. The interface repairs were checked with offline controller inputs. Live robot deployment has not been verified.

```matlab
addpath(fullfile(pwd, 'matlab', 'robot_archive'))
[headingDeg, action] = response_dn2([0, 0], [0.4, 0.1; 1, 1], [2, 1]);
```

`dn3/response_dn3.m` and the three `env28` weight files were recovered from the nested `ros机器人最终版` archive. Initialize its `global network` with `load_dn3_checkpoint()` before supplying a six-element geometric feature vector. `models/shiwushiyan_model.mat` preserves the recovered MDN22 workspace used by the historical wrapper. `models/yuanshiMDN2.mat`, `data/map_new.mat`, and the measured obstacle trajectory restore the inputs of the legacy recorded-map simulation.

## SOLMM navigation

Run `python -m python.solmm --demo` from the repository root to trace spatial activity, memory generation, contextual retrieval and fallback on the packaged camera panels. The [module documentation](python/solmm/README.md) maps each mechanism to its implementation and describes the input format and choices for parameters left unspecified in the manuscript.

## Packaging changes

Source files are stored as UTF-8. MATLAB and Python simulation paths resolve relative to this repository. Historical Excel outputs use local filenames, and the ROS archive uses environment-supplied connection settings. The two repackaged checkpoints contain only the `network` variable. Their fields, dimensions, and values were verified against the source files. The initial memory checkpoint was copied as-is.

