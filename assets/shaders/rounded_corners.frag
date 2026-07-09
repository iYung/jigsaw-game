// Rounded-corner mask shader, shared by jigsaw pieces and the trophy shelf.
//
// RADIUS is a fixed, hardcoded constant -- it never varies and is never sent
// as a uniform. `size` is the only per-draw-target quantity: the drawable's
// pixel dimensions (e.g. {64, 64} for a piece, {cols*SLOT, rows*SLOT} for a
// completed-puzzle shelf entry), sent once by the caller.
const float RADIUS = 8.0;

uniform vec2 size;

// UV bounds (within the drawn texture) of the region actually being drawn:
// xy = min corner, zw = max corner. For a plain full-image draw this is
// {0,0,1,1}; for a Quad draw (e.g. a jigsaw piece sampled from a shared
// puzzle-image atlas) this is the quad's own sub-rectangle, since raw
// texture_coords are normalized to the whole atlas, not the quad.
uniform vec4 uv_rect;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 local_uv = (texture_coords - uv_rect.xy) / (uv_rect.zw - uv_rect.xy);
    vec2 pixel_pos = local_uv * size;

    bool outside_footprint = false;

    // Top-left corner
    if (pixel_pos.x < RADIUS && pixel_pos.y < RADIUS) {
        vec2 corner_center = vec2(RADIUS, RADIUS);
        if (distance(pixel_pos, corner_center) > RADIUS) {
            outside_footprint = true;
        }
    }
    // Top-right corner
    else if (pixel_pos.x > size.x - RADIUS && pixel_pos.y < RADIUS) {
        vec2 corner_center = vec2(size.x - RADIUS, RADIUS);
        if (distance(pixel_pos, corner_center) > RADIUS) {
            outside_footprint = true;
        }
    }
    // Bottom-left corner
    else if (pixel_pos.x < RADIUS && pixel_pos.y > size.y - RADIUS) {
        vec2 corner_center = vec2(RADIUS, size.y - RADIUS);
        if (distance(pixel_pos, corner_center) > RADIUS) {
            outside_footprint = true;
        }
    }
    // Bottom-right corner
    else if (pixel_pos.x > size.x - RADIUS && pixel_pos.y > size.y - RADIUS) {
        vec2 corner_center = vec2(size.x - RADIUS, size.y - RADIUS);
        if (distance(pixel_pos, corner_center) > RADIUS) {
            outside_footprint = true;
        }
    }

    vec4 texel = Texel(tex, texture_coords) * color;

    if (outside_footprint) {
        return vec4(texel.rgb, 0.0);
    }

    return texel;
}
