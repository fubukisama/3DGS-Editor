function requiredNumber(value, label) {
  const number = Number(value);
  if (!Number.isFinite(number)) throw new Error(`${label} must be a number.`);
  return number;
}

function optionalPositive(value, label) {
  if (value === undefined || value === null || String(value).trim() === "") return -1;
  const number = requiredNumber(value, label);
  if (number <= 0) throw new Error(`${label} must be positive or left blank for Auto.`);
  return number;
}

export function twoDgsMeshOptionsFromValues(values = {}) {
  const meshRes = Math.round(requiredNumber(values.meshRes ?? 512, "Mesh resolution"));
  const numCluster = Math.round(requiredNumber(values.numCluster ?? 50, "Connected clusters"));
  const depthRatio = requiredNumber(values.depthRatio ?? 0, "Depth ratio");

  if (meshRes < 64 || meshRes > 4096) {
    throw new Error("Mesh resolution must be between 64 and 4096.");
  }
  if (numCluster < 1 || numCluster > 500) {
    throw new Error("Connected clusters must be between 1 and 500.");
  }
  if (depthRatio < 0 || depthRatio > 1) {
    throw new Error("Depth ratio must be between 0 and 1.");
  }

  return {
    mesh_res: meshRes,
    num_cluster: numCluster,
    depth_ratio: depthRatio,
    voxel_size: optionalPositive(values.voxelSize, "Voxel size"),
    sdf_trunc: optionalPositive(values.sdfTrunc, "SDF truncation"),
    depth_trunc: optionalPositive(values.depthTrunc, "Depth truncation"),
  };
}

export function twoDgsMeshUsesPost(source) {
  return source !== "raw";
}
