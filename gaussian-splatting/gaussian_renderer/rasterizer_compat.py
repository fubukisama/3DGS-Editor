def rasterizer_fields(settings_type):
    return set(getattr(settings_type, "_fields", ()))


def supports_depth_output(settings_type):
    return "antialiasing" in rasterizer_fields(settings_type)


def compatible_settings_kwargs(settings_type, values):
    fields = rasterizer_fields(settings_type)
    if not fields:
        return dict(values)
    return {name: value for name, value in values.items() if name in fields}


def unpack_rasterizer_result(result):
    if len(result) == 3:
        return result
    if len(result) == 2:
        color, radii = result
        return color, radii, None
    raise RuntimeError(f"Unexpected rasterizer output count: {len(result)}")
