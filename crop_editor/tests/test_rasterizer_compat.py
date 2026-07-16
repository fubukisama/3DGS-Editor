import importlib.util
import unittest
from collections import namedtuple
from pathlib import Path


COMPAT_PATH = (
    Path(__file__).resolve().parents[2]
    / "gaussian-splatting"
    / "gaussian_renderer"
    / "rasterizer_compat.py"
)


class RasterizerCompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("rasterizer_compat", COMPAT_PATH)
        cls.compat = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.compat)

    def test_filters_modern_only_settings_for_legacy_rasterizer(self):
        legacy = namedtuple("LegacySettings", "image_height debug")
        values = {"image_height": 480, "debug": False, "antialiasing": True}

        self.assertEqual(
            self.compat.compatible_settings_kwargs(legacy, values),
            {"image_height": 480, "debug": False},
        )
        self.assertFalse(self.compat.supports_depth_output(legacy))

    def test_preserves_modern_settings_and_depth_output(self):
        modern = namedtuple("ModernSettings", "image_height debug antialiasing")
        values = {"image_height": 480, "debug": False, "antialiasing": True}

        self.assertEqual(self.compat.compatible_settings_kwargs(modern, values), values)
        self.assertTrue(self.compat.supports_depth_output(modern))

    def test_unpacks_legacy_and_modern_rasterizer_results(self):
        self.assertEqual(
            self.compat.unpack_rasterizer_result(("color", "radii")),
            ("color", "radii", None),
        )
        self.assertEqual(
            self.compat.unpack_rasterizer_result(("color", "radii", "depth")),
            ("color", "radii", "depth"),
        )
        with self.assertRaisesRegex(RuntimeError, "Unexpected rasterizer output"):
            self.compat.unpack_rasterizer_result(("color",))


if __name__ == "__main__":
    unittest.main()
