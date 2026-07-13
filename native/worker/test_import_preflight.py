import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).with_name("import_preflight.py")


def load_module():
    spec = importlib.util.spec_from_file_location("gsw_import_preflight", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ImportPreflightTests(unittest.TestCase):
    def setUp(self):
        self.preflight = load_module()
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        crop_editor = self.root / "crop_editor"
        crop_editor.mkdir()
        (crop_editor / "video_extract.py").write_text("import cv2\n", encoding="utf-8")
        (crop_editor / "server.py").write_text(
            "import numpy\n"
            "import plyfile\n"
            "def ffmpeg_executable():\n"
            "    return None\n"
            "def conda_executable():\n"
            "    return None\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.temporary.cleanup()

    def test_loads_the_staged_server_and_required_media_modules(self):
        fake_numpy = mock.MagicMock()
        fake_plyfile = mock.MagicMock()
        with mock.patch.dict(sys.modules, {"numpy": fake_numpy, "plyfile": fake_plyfile}):
            report = self.preflight.probe_import_environment(self.root, require_video=False)

        self.assertTrue(report["ready"])
        self.assertEqual(report["server"], str((self.root / "crop_editor" / "server.py").resolve()))
        self.assertEqual(report["python"], str(Path(sys.executable).resolve()))

    def test_video_import_accepts_current_python_opencv(self):
        with mock.patch.dict(
            sys.modules,
            {"numpy": mock.MagicMock(), "plyfile": mock.MagicMock(), "cv2": mock.MagicMock()},
        ):
            report = self.preflight.probe_import_environment(self.root, require_video=True)

        self.assertTrue(report["ready"])
        self.assertEqual(report["videoBackend"], "opencv-current-python")

    def test_video_import_only_accepts_ffmpeg_after_executable_probe(self):
        ffmpeg = self.root / "ffmpeg.exe"
        ffmpeg.write_bytes(b"fixture")
        server = mock.MagicMock()
        server.ffmpeg_executable.return_value = ffmpeg
        completed = mock.Mock(returncode=0, stdout="ffmpeg version fixture", stderr="")
        with mock.patch.object(self.preflight, "load_server_module", return_value=server), mock.patch.object(
            self.preflight.importlib, "import_module", return_value=mock.MagicMock()
        ), mock.patch.object(self.preflight.subprocess, "run", return_value=completed) as run_mock:
            report = self.preflight.probe_import_environment(self.root, require_video=True)

        self.assertTrue(report["ready"])
        self.assertEqual(report["videoBackend"], "ffmpeg")
        self.assertEqual(run_mock.call_args.args[0], [str(ffmpeg), "-version"])

    def test_video_import_rejects_broken_ffmpeg_file_without_other_backend(self):
        ffmpeg = self.root / "ffmpeg.exe"
        ffmpeg.write_bytes(b"not an executable")
        server = mock.MagicMock()
        server.ffmpeg_executable.return_value = ffmpeg
        server.conda_executable.return_value = None
        completed = mock.Mock(returncode=1, stdout="", stderr="invalid executable")

        def import_without_cv2(name):
            if name == "cv2":
                raise ImportError("cv2 unavailable")
            return mock.MagicMock()

        with mock.patch.object(self.preflight, "load_server_module", return_value=server), mock.patch.object(
            self.preflight.importlib, "import_module", side_effect=import_without_cv2
        ), mock.patch.object(self.preflight.subprocess, "run", return_value=completed):
            report = self.preflight.probe_import_environment(self.root, require_video=True)

        self.assertFalse(report["ready"])
        self.assertIn("invalid executable", report["error"])

    def test_video_import_rejects_environment_without_any_extraction_backend(self):
        real_import = self.preflight.importlib.import_module

        def controlled_import(name):
            if name == "cv2":
                raise ImportError("cv2 unavailable")
            return real_import(name)

        with mock.patch.dict(sys.modules, {"numpy": mock.MagicMock(), "plyfile": mock.MagicMock()}), mock.patch.object(
            self.preflight.importlib, "import_module", side_effect=controlled_import
        ):
            report = self.preflight.probe_import_environment(self.root, require_video=True)

        self.assertFalse(report["ready"])
        self.assertIn("FFmpeg", report["error"])
        self.assertIn("OpenCV", report["error"])

    def test_video_import_accepts_verified_conda_fallback(self):
        conda = self.root / "conda.exe"
        conda.write_bytes(b"fixture")
        server = mock.MagicMock()
        server.ffmpeg_executable.return_value = None
        server.conda_executable.return_value = conda
        completed = mock.Mock(returncode=0, stdout="ok", stderr="")

        def import_without_cv2(name):
            if name == "cv2":
                raise ImportError("cv2 unavailable")
            return mock.MagicMock()

        with mock.patch.object(self.preflight, "load_server_module", return_value=server), mock.patch.object(
            self.preflight.importlib, "import_module", side_effect=import_without_cv2
        ), mock.patch.object(self.preflight.subprocess, "run", return_value=completed) as run_mock:
            report = self.preflight.probe_import_environment(self.root, require_video=True)

        self.assertTrue(report["ready"])
        self.assertEqual(report["videoBackend"], "conda-video-extract")
        command = run_mock.call_args.args[0]
        self.assertEqual(command[:5], [str(conda), "run", "-n", "gaussian_splatting", "python"])
        self.assertIn("import cv2", command[-1])


if __name__ == "__main__":
    unittest.main()
