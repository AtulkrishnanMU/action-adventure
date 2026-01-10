shader_type canvas_item;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 trail_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // White color
uniform float blur_amount : hint_range(0.0, 10.0) = 10.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	
	// Create white silhouette effect
	vec3 white_silhouette = vec3(1.0);
	float base_alpha = original_color.a * opacity * fade_alpha;
	
	// Apply blur effect
	vec2 texel_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec4 blurred_color = vec4(0.0);
	float total_weight = 0.0;
	
	// Simple Gaussian blur kernel
	float kernel[9] = float[](
		1.0, 2.0, 1.0,
		2.0, 4.0, 2.0,
		1.0, 2.0, 1.0
	);
	
	// Sample surrounding pixels for blur
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * texel_size * blur_amount;
			vec4 sample_color = texture(TEXTURE, UV + offset);
			float weight = kernel[(x + 1) * 3 + (y + 1)];
			
			blurred_color += sample_color * weight;
			total_weight += weight;
		}
	}
	
	blurred_color /= total_weight;
	
	// Apply trail color (white) with fade to blurred result
	COLOR = vec4(trail_color.rgb, blurred_color.a * opacity * fade_alpha);
	
	// Add stronger glow effect for better visibility
	float blurred_alpha = blurred_color.a * opacity * fade_alpha;
	if (blurred_alpha > 0.1) {
		COLOR.rgb += vec3(0.3) * blurred_alpha; // Add white glow that also fades
	}
}
