import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.request import urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import server  # noqa: E402


class SceneWorkspaceTests(unittest.TestCase):
    def test_scene_listing_exposes_real_model_path(self):
        original_output = server.OUTPUT_DIR
        try:
            with tempfile.TemporaryDirectory() as tmp:
                server.OUTPUT_DIR = Path(tmp) / "output"
                model = server.OUTPUT_DIR / "existing_scene"
                point_cloud = model / "point_cloud" / "iteration_30000" / "point_cloud.ply"
                point_cloud.parent.mkdir(parents=True)
                point_cloud.write_bytes(b"ply\n")
                (model / "training_backend.json").write_text(
                    json.dumps({"backend": "2dgs"}),
                    encoding="utf-8",
                )

                scenes = server.list_scenes()

                self.assertEqual(len(scenes), 1)
                self.assertEqual(scenes[0]["name"], "existing_scene")
                self.assertEqual(scenes[0]["latest_iteration"], 30000)
                self.assertEqual(scenes[0]["backend"], "2dgs")
                self.assertEqual(Path(scenes[0]["path"]), model.resolve())
        finally:
            server.OUTPUT_DIR = original_output

    def test_gaussian_ply_download_preserves_original_file(self):
        original_output = server.OUTPUT_DIR
        httpd = None
        thread = None
        try:
            with tempfile.TemporaryDirectory() as tmp:
                server.OUTPUT_DIR = Path(tmp) / "output"
                point_cloud = (
                    server.OUTPUT_DIR
                    / "gaussian_scene"
                    / "point_cloud"
                    / "iteration_30000"
                    / "point_cloud.ply"
                )
                point_cloud.parent.mkdir(parents=True)
                expected = (
                    b"ply\nformat binary_little_endian 1.0\n"
                    b"element vertex 1\nproperty float x\nproperty float f_dc_0\n"
                    b"property float opacity\nproperty float scale_0\nproperty float rot_0\n"
                    b"end_header\n\x00\x01\x02\x03"
                )
                point_cloud.write_bytes(expected)

                asset = server.scene_splat_assets("gaussian_scene", 30000)[0]
                self.assertEqual(asset["label_key"], "asset.gaussianPly")
                self.assertEqual(
                    asset["url"],
                    "/api/splat/ply?scene=gaussian_scene&iteration=30000",
                )

                httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
                thread = threading.Thread(target=httpd.serve_forever, daemon=True)
                thread.start()
                port = httpd.server_address[1]

                with urlopen(
                    f"http://127.0.0.1:{port}/api/splat/ply"
                    "?scene=gaussian_scene&iteration=30000",
                    timeout=5,
                ) as response:
                    self.assertEqual(response.read(), expected)
                    self.assertEqual(
                        response.headers.get("Content-Disposition"),
                        'attachment; filename="gaussian_scene_iteration_30000_gaussians.ply"',
                    )
        finally:
            if httpd is not None:
                httpd.shutdown()
                httpd.server_close()
            if thread is not None:
                thread.join(timeout=5)
            server.OUTPUT_DIR = original_output


if __name__ == "__main__":
    unittest.main()
