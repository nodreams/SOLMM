"""Check the SIFT familiarity gate using the camera panels in tu16_Copy.pdf.

Run with Python, NumPy, and OpenCV: python python/sift_check/run_check.py
The JSON output distinguishes synthetic brightness changes of stored frames
from comparisons between independently captured frames at the same location.
"""

import hashlib
import json
import re
from pathlib import Path

import cv2
import numpy as np


FIGURE = Path(__file__).resolve().with_name("tu16_Copy.pdf")
BRIGHTNESS = (0.50, 0.75, 1.00, 1.25, 1.50)
THRESHOLDS = (0.50, 0.60, 0.70)
RATIO = 0.75


def read_panel(pdf, object_id):
    # In this source PDF the top-row panels (a), (b), and (c) are JPEG
    # XObjects 10, 11, and 12. Decode the embedded images at native size.
    pattern = rb"(?:^|[\r\n])%d 0 obj\s*<<(.*?)>>\s*stream\r?\n?" % object_id
    entry = re.search(pattern, pdf, re.DOTALL)
    if entry is None or b"/DCTDecode" not in entry[1]:
        raise ValueError(f"Expected embedded JPEG object {object_id}")
    length = int(re.search(rb"/Length\s+(\d+)", entry[1])[1])
    jpeg = pdf[entry.end():entry.end() + length]
    image = cv2.imdecode(np.frombuffer(jpeg, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
    if image is None:
        raise ValueError(f"Cannot decode camera panel {object_id}")
    return image


def ratio_matches(matcher, source, target):
    if source is None or target is None or len(target) < 2:
        return set()
    return {
        (first.queryIdx, first.trainIdx)
        for first, second in matcher.knnMatch(source, target, k=2)
        if first.distance < RATIO * second.distance
    }


def main():
    pdf = FIGURE.read_bytes()
    panels = {name: read_panel(pdf, i) for name, i in zip("abc", (10, 11, 12))}
    sift = cv2.SIFT_create()
    matcher = cv2.BFMatcher(cv2.NORM_L2)
    reference = {k: sift.detectAndCompute(panels[k], None)[1] for k in "ab"}

    rows = []
    for group, query, ref in (
        ("stored_frame_brightness", "a", "a"),
        ("stored_frame_brightness", "b", "b"),
        ("independent_static_capture", "b", "a"),
        ("independent_capture_with_obstacle", "c", "a"),
    ):
        for factor in BRIGHTNESS:
            image = np.clip(np.rint(panels[query].astype(float) * factor), 0, 255)
            _, descriptors = sift.detectAndCompute(image.astype(np.uint8), None)
            stored = reference[ref]
            forward = ratio_matches(matcher, descriptors, stored)
            reverse = ratio_matches(matcher, stored, descriptors)
            count = sum((j, i) in reverse for i, j in forward)
            n_query = len(descriptors) if descriptors is not None else 0
            n_ref = len(stored) if stored is not None else 0
            score = count / max(n_query, n_ref, 1)
            rows.append({
                "group": group,
                "reference_panel": ref,
                "query_panel": query,
                "brightness_factor": factor,
                "reference_keypoints": n_ref,
                "query_keypoints": n_query,
                "mutual_matches": count,
                "similarity": score,
                "familiar_at": {f"{t:.2f}": score >= t for t in THRESHOLDS},
            })

    print(json.dumps({
        "figure": FIGURE.name,
        "figure_sha256": hashlib.sha256(pdf).hexdigest(),
        "opencv": cv2.__version__,
        "nearest_neighbor_ratio": RATIO,
        "results": rows,
    }, indent=2))


if __name__ == "__main__":
    main()
