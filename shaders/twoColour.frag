#pragma header

uniform vec3 replacementColor;
uniform float intensity;

void main()
{
    vec4 col = flixel_texture2D(bitmap, openfl_TextureCoordv);

    // Keep transparent pixels transparent.
    if (col.a <= 0.0)
    {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec3 originalColor = col.rgb;

    // Measure how close the pixel is to pure black.
    float brightness = max(col.r, max(col.g, col.b));

    // Smoothly transition between the black and non-black regions.
    float blackMask = 1.0 - smoothstep(0.0, 0.08, brightness);

    // Black becomes white; other colours become the chosen colour.
    vec3 processedColor = mix(replacementColor, vec3(1.0), blackMask);

    // Blend the effect with the original sprite.
    col.rgb = mix(originalColor, processedColor, clamp(intensity, 0.0, 1.0));

    // Preserve the original alpha.
    gl_FragColor = col;
}