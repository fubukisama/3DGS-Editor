"""Validate the structural output of a completed 3DGS smoke training run."""

import argparse
import json
from pathlib import Path

from plyfile import PlyData


REQUIRED_GAUSSIAN_FIELDS = {
    "x",
    "y",
    "z",
    "f_dc_0",
    "f_dc_1",
    "f_dc_2",
    "opacity",
    "scale_0",
    "scale_1",
    "scale_2",
    "rot_0",
    "rot_1",
    "rot_2",
    "rot_3",
}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("ply")
    parser.add_argument("--checkpoint")
    parser.add_argument("--minimum-vertices", type=int, default=1)
    parser.add_argument("--json-output")
    return parser.parse_args()


def main():
    args = parse_args()
    ply_path = Path(args.ply).resolve()
    if not ply_path.is_file():
        raise FileNotFoundError("Gaussian PLY is missing: {}".format(ply_path))

    ply = PlyData.read(str(ply_path))
    if "vertex" not in ply:
        raise ValueError("PLY has no vertex element: {}".format(ply_path))
    vertices = ply["vertex"]
    names = set(vertices.data.dtype.names or ())
    missing = sorted(REQUIRED_GAUSSIAN_FIELDS - names)
    if missing:
        raise ValueError("PLY is missing Gaussian fields: {}".format(", ".join(missing)))
    if len(vertices) < args.minimum_vertices:
        raise ValueError(
            "PLY contains {} vertices; expected at least {}".format(
                len(vertices), args.minimum_vertices
            )
        )

    checkpoint_path = Path(args.checkpoint).resolve() if args.checkpoint else None
    if checkpoint_path is not None and not checkpoint_path.is_file():
        raise FileNotFoundError("Training checkpoint is missing: {}".format(checkpoint_path))

    result = {
        "version": 1,
        "valid": True,
        "ply": str(ply_path),
        "plyBytes": ply_path.stat().st_size,
        "format": "ascii" if ply.text else "binary_little_endian",
        "vertices": len(vertices),
        "properties": len(names),
        "requiredGaussianFieldsPresent": True,
        "checkpoint": str(checkpoint_path) if checkpoint_path else None,
        "checkpointBytes": checkpoint_path.stat().st_size if checkpoint_path else None,
    }
    serialized = json.dumps(result, indent=2)
    if args.json_output:
        Path(args.json_output).resolve().write_text(serialized + "\n", encoding="utf-8")
    print(serialized)


if __name__ == "__main__":
    main()
