"""Generate deterministic multi-view media for COLMAP and 3DGS smoke tests.

The fixture is deliberately multi-depth: several textured planes sit between a
moving pinhole camera and a textured background.  Unlike a flat panorama or a
camera-only rotation, the resulting views contain enough translation and
parallax for a real sparse reconstruction.
"""

import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--views", type=int, default=16)
    parser.add_argument("--width", type=int, default=960)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--seed", type=int, default=20260718)
    return parser.parse_args()


def make_texture(width, height, seed, label):
    rng = np.random.RandomState(seed)
    texture = rng.randint(20, 236, size=(height, width, 3), dtype=np.uint8)
    texture = cv2.GaussianBlur(texture, (3, 3), 0.45)

    for x in range(0, width, 64):
        color = tuple(int(value) for value in rng.randint(30, 226, size=3))
        cv2.line(texture, (x, 0), (x, height - 1), color, 2, cv2.LINE_AA)
    for y in range(0, height, 64):
        color = tuple(int(value) for value in rng.randint(30, 226, size=3))
        cv2.line(texture, (0, y), (width - 1, y), color, 2, cv2.LINE_AA)

    for index in range(180):
        center = (
            int(rng.randint(18, max(19, width - 18))),
            int(rng.randint(18, max(19, height - 18))),
        )
        radius = int(rng.randint(4, 20))
        color = tuple(int(value) for value in rng.randint(0, 256, size=3))
        cv2.circle(texture, center, radius, color, 2, cv2.LINE_AA)
        if index % 4 == 0:
            offset = int(rng.randint(8, 30))
            cv2.line(
                texture,
                (center[0] - offset, center[1]),
                (center[0] + offset, center[1]),
                color,
                2,
                cv2.LINE_AA,
            )

    for row in range(5):
        cv2.putText(
            texture,
            "{}-{:02d}".format(label, row),
            (32 + (row % 2) * 170, 70 + row * 125),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.15,
            (245, 245, 245),
            4,
            cv2.LINE_AA,
        )
        cv2.putText(
            texture,
            "{}-{:02d}".format(label, row),
            (32 + (row % 2) * 170, 70 + row * 125),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.15,
            (15, 15, 15),
            2,
            cv2.LINE_AA,
        )
    return texture


def plane_corners(center, horizontal, vertical):
    center = np.asarray(center, dtype=np.float64)
    horizontal = np.asarray(horizontal, dtype=np.float64)
    vertical = np.asarray(vertical, dtype=np.float64)
    return np.stack(
        (
            center - horizontal - vertical,
            center + horizontal - vertical,
            center + horizontal + vertical,
            center - horizontal + vertical,
        )
    )


def world_to_camera(camera_position, target):
    camera_position = np.asarray(camera_position, dtype=np.float64)
    forward = np.asarray(target, dtype=np.float64) - camera_position
    forward /= np.linalg.norm(forward)
    world_down = np.asarray((0.0, 1.0, 0.0), dtype=np.float64)
    right = np.cross(world_down, forward)
    right /= np.linalg.norm(right)
    down = np.cross(forward, right)
    down /= np.linalg.norm(down)
    return np.stack((right, down, forward)), camera_position


def project_points(points, rotation, camera_position, intrinsics):
    camera_points = (rotation @ (points - camera_position).T).T
    if np.any(camera_points[:, 2] <= 0.05):
        raise ValueError("Fixture plane moved behind the camera")
    pixels = (intrinsics @ camera_points.T).T
    return pixels[:, :2] / pixels[:, 2:3], camera_points[:, 2]


def render_view(width, height, intrinsics, camera_position, target, planes):
    rotation, camera_position = world_to_camera(camera_position, target)
    canvas = np.full((height, width, 3), (28, 31, 38), dtype=np.uint8)
    projected = []
    for plane in planes:
        corners, depths = project_points(
            plane["corners"], rotation, camera_position, intrinsics
        )
        projected.append((float(np.mean(depths)), plane, corners.astype(np.float32)))

    for _depth, plane, destination in sorted(projected, key=lambda item: -item[0]):
        texture = plane["texture"]
        texture_height, texture_width = texture.shape[:2]
        source = np.asarray(
            (
                (0, 0),
                (texture_width - 1, 0),
                (texture_width - 1, texture_height - 1),
                (0, texture_height - 1),
            ),
            dtype=np.float32,
        )
        homography = cv2.getPerspectiveTransform(source, destination)
        warped = cv2.warpPerspective(
            texture,
            homography,
            (width, height),
            flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
        )
        mask = cv2.warpPerspective(
            np.full((texture_height, texture_width), 255, dtype=np.uint8),
            homography,
            (width, height),
            flags=cv2.INTER_NEAREST,
            borderMode=cv2.BORDER_CONSTANT,
        )
        canvas[mask > 0] = warped[mask > 0]

    return canvas


def build_planes(seed):
    definitions = (
        ((0.0, 0.0, 7.0), (5.2, 0.0, 0.0), (0.0, 3.9, 0.0)),
        ((-2.1, -1.05, 4.7), (1.15, 0.0, 0.18), (0.0, 0.85, 0.0)),
        ((1.75, -1.0, 5.25), (1.25, 0.0, -0.2), (0.0, 0.9, 0.0)),
        ((-1.45, 1.25, 5.55), (1.15, 0.0, -0.12), (0.0, 0.75, 0.0)),
        ((1.3, 1.15, 3.65), (1.1, 0.0, 0.15), (0.0, 0.72, 0.0)),
        ((0.05, 0.0, 4.25), (0.72, 0.0, -0.08), (0.0, 0.6, 0.0)),
    )
    planes = []
    for index, (center, horizontal, vertical) in enumerate(definitions):
        planes.append(
            {
                "corners": plane_corners(center, horizontal, vertical),
                "texture": make_texture(
                    1024,
                    768,
                    seed + index * 104729,
                    "GSW{}".format(index),
                ),
            }
        )
    return planes


def write_contact_sheet(images, path):
    columns = 4
    thumb_width = 320
    thumb_height = 240
    rows = int(math.ceil(len(images) / float(columns)))
    sheet = np.full(
        (rows * thumb_height, columns * thumb_width, 3),
        (18, 18, 18),
        dtype=np.uint8,
    )
    for index, image in enumerate(images):
        thumbnail = cv2.resize(image, (thumb_width, thumb_height), cv2.INTER_AREA)
        row, column = divmod(index, columns)
        y = row * thumb_height
        x = column * thumb_width
        sheet[y : y + thumb_height, x : x + thumb_width] = thumbnail
    if not cv2.imwrite(str(path), sheet, (cv2.IMWRITE_JPEG_QUALITY, 92)):
        raise RuntimeError("Could not write contact sheet: {}".format(path))


def main():
    args = parse_args()
    if args.views < 8:
        raise ValueError("At least 8 translated views are required")
    if args.width < 640 or args.height < 480:
        raise ValueError("Fixture resolution must be at least 640x480")

    output_dir = Path(args.output_dir).resolve()
    photos_dir = output_dir / "photos"
    photos_dir.mkdir(parents=True, exist_ok=True)

    focal_length = 0.82 * args.width
    intrinsics = np.asarray(
        (
            (focal_length, 0.0, args.width / 2.0),
            (0.0, focal_length, args.height / 2.0),
            (0.0, 0.0, 1.0),
        ),
        dtype=np.float64,
    )
    planes = build_planes(args.seed)
    target = np.asarray((0.0, 0.0, 5.25), dtype=np.float64)
    images = []
    camera_positions = []
    for index in range(args.views):
        phase = index / float(args.views - 1)
        camera_position = np.asarray(
            (
                -1.35 + 2.7 * phase,
                0.22 * math.sin(phase * math.pi * 2.0),
                0.14 * math.cos(phase * math.pi * 2.0),
            ),
            dtype=np.float64,
        )
        image = render_view(
            args.width,
            args.height,
            intrinsics,
            camera_position,
            target,
            planes,
        )
        image_path = photos_dir / "view_{:03d}.jpg".format(index)
        if not cv2.imwrite(
            str(image_path), image, (cv2.IMWRITE_JPEG_QUALITY, 94)
        ):
            raise RuntimeError("Could not write fixture view: {}".format(image_path))
        images.append(image)
        camera_positions.append([float(value) for value in camera_position])

    write_contact_sheet(images, output_dir / "contact_sheet.jpg")
    manifest = {
        "version": 1,
        "kind": "gsw-colmap-training-fixture",
        "views": args.views,
        "width": args.width,
        "height": args.height,
        "focalLength": focal_length,
        "seed": args.seed,
        "cameraPositions": camera_positions,
        "target": [float(value) for value in target],
    }
    (output_dir / "fixture.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    print(str(output_dir))


if __name__ == "__main__":
    main()
