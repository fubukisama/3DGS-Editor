import test from "node:test";
import assert from "node:assert/strict";

import {
  twoDgsMeshOptionsFromValues,
  twoDgsMeshUsesPost,
} from "../static/two-dgs-mesh-options.mjs";

test("2DGS mesh options keep TSDF sizing automatic when optional fields are blank", () => {
  assert.deepEqual(twoDgsMeshOptionsFromValues({
    meshRes: "1024",
    numCluster: "50",
    depthRatio: "0",
    voxelSize: "",
    sdfTrunc: "",
    depthTrunc: "",
  }), {
    mesh_res: 1024,
    num_cluster: 50,
    depth_ratio: 0,
    voxel_size: -1,
    sdf_trunc: -1,
    depth_trunc: -1,
  });
});

test("2DGS mesh options preserve valid manual TSDF values", () => {
  assert.deepEqual(twoDgsMeshOptionsFromValues({
    meshRes: "2048",
    numCluster: "12",
    depthRatio: "0.25",
    voxelSize: "0.01",
    sdfTrunc: "0.05",
    depthTrunc: "40",
  }), {
    mesh_res: 2048,
    num_cluster: 12,
    depth_ratio: 0.25,
    voxel_size: 0.01,
    sdf_trunc: 0.05,
    depth_trunc: 40,
  });
});

test("2DGS mesh options reject unsafe ranges", () => {
  assert.throws(
    () => twoDgsMeshOptionsFromValues({ meshRes: "32", numCluster: "50", depthRatio: "0" }),
    /resolution/i,
  );
  assert.throws(
    () => twoDgsMeshOptionsFromValues({ meshRes: "512", numCluster: "0", depthRatio: "0" }),
    /clusters/i,
  );
  assert.throws(
    () => twoDgsMeshOptionsFromValues({ meshRes: "512", numCluster: "50", depthRatio: "1.2" }),
    /depth ratio/i,
  );
  assert.throws(
    () => twoDgsMeshOptionsFromValues({ meshRes: "512", numCluster: "50", depthRatio: "0", voxelSize: "0" }),
    /voxel/i,
  );
});

test("2DGS mesh source selection maps cleaned to post and raw to pre-filter mesh", () => {
  assert.equal(twoDgsMeshUsesPost("cleaned"), true);
  assert.equal(twoDgsMeshUsesPost("raw"), false);
  assert.equal(twoDgsMeshUsesPost("unknown"), true);
});
