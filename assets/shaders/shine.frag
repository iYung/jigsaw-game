// Sweeping shine shader for puzzle-completion celebration.
//
// `local_progress` is the shine band's center in this piece's local UV x-space
// (0 = left edge of piece, 1 = right edge). It can be outside [0,1] while the
// band is entering from the left or exiting to the right, which produces a soft
// fade-in/out at each piece's edge rather than a hard cut.
//
// `uv_rect` (xy = min UV, zw = max UV) is sent automatically by Sprite:draw()
// whenever a shader is active, so this shader does not need the caller to send
// it explicitly.

uniform float local_progress;
uniform vec4 uv_rect;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(tex, texture_coords) * color;

    vec2 local_uv = (texture_coords - uv_rect.xy) / max(uv_rect.zw - uv_rect.xy, vec2(0.0001));
    float dist = abs(local_uv.x - local_progress);
    float band = max(0.0, 1.0 - dist / 0.35) * 0.75;

    pixel.rgb = min(vec3(1.0), pixel.rgb + band);
    return pixel;
}
