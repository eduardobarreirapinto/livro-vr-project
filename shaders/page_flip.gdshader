shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cor_verso : source_color = vec4(0.92, 0.89, 0.82, 1.0);

void fragment() {
    vec2 uv = UV;
    float fold = smoothstep(0.0, 0.02, abs(uv.x - (0.5 + 0.5 * progress)));
    float sine = sin(progress * 3.14159) * (0.12 + 0.06 * uv.y);
    float shadow = smoothstep(0.0, 0.18, abs(uv.x - (0.5 + 0.5 * progress))) * (0.35 * progress);

    vec2 displaced_uv = uv;
    displaced_uv.x += (uv.x > 0.5) ? (sine * (1.0 - progress)) : (-sine * progress);
    displaced_uv.x = clamp(displaced_uv.x, 0.0, 1.0);

    vec4 page_color = texture(TEXTURE, displaced_uv);
    vec4 shadow_color = vec4(0.0, 0.0, 0.0, shadow);

    if (uv.x > 0.5) {
        page_color.rgb = mix(page_color.rgb, cor_verso.rgb, 0.12 * progress);
    }

    COLOR = mix(page_color, shadow_color, fold * 0.65);
}
