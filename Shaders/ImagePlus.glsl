#include "Common.glsl"

/* META GLOBAL
    @meta: category=Texturing;
*/

void _sample_texture(sampler2D Image, vec2 UV, bool Smooth_Interpolation, vec2 Resolution, out vec4 Color)
{
    if (Smooth_Interpolation)
    {
        Color = texture(Image, UV);
    }
    else
    {
        ivec2 texel = ivec2(mod(UV * Resolution, Resolution));
        Color = texelFetch(Image, texel, 0);
    }
}

// lifted from Blender source
// link: https://projects.blender.org/blender/blender/src/branch/main/source/blender/gpu/shaders/material/gpu_shader_material_tex_image.glsl
void _tex_box_Blend(
    vec3 N, vec4 Color1, vec4 Color2, vec4 Color3, float Blend, out vec4 Color)
{
  /* project from direction vector to barycentric coordinates in triangles */
  N = abs(N);
  N /= dot(N, vec3(1.0));

  /* basic idea is to think of this as a triangle, each corner representing
   * one of the 3 faces of the cube. in the corners we have single textures,
   * in between we Blend between two textures, and in the middle we a Blend
   * between three textures.
   *
   * the `Nxyz` values are the barycentric coordinates in an equilateral
   * triangle, which in case of Blending, in the middle has a smaller
   * equilateral triangle where 3 textures Blend. this divides things into
   * 7 zones, with an if () test for each zone
   * EDIT: Now there is only 4 if's. */

  float limit = 0.5 + 0.5 * Blend;

  vec3 weight;
  weight = N.xyz / (N.xyx + N.yzz);
  weight = clamp((weight - 0.5 * (1.0 - Blend)) / max(1e-8, Blend), 0.0, 1.0);

  /* test for mixes between two textures */
  if (N.z < (1.0 - limit) * (N.y + N.x)) {
    weight.z = 0.0;
    weight.y = 1.0 - weight.x;
  }
  else if (N.x < (1.0 - limit) * (N.y + N.z)) {
    weight.x = 0.0;
    weight.z = 1.0 - weight.y;
  }
  else if (N.y < (1.0 - limit) * (N.x + N.z)) {
    weight.y = 0.0;
    weight.x = 1.0 - weight.z;
  }
  else {
    /* last case, we have a mix between three */
    weight = ((2.0 - limit) * N + (limit - 1.0)) / max(1e-8, Blend);
  }

  Color = weight.x * Color1 + weight.y * Color2 + weight.z * Color3;
}

/* META
    @UV: label=UV; default=UV[0];
    @Smooth_Interpolation: default=true;
    @Normal: subtype=Normal; default=NORMAL;
    @Projection_Method: subtype=ENUM(Flat, Box); default=0;
    @Blend: subtype=Slider; min=0.0; max=1.0; default=1.0;
*/
void Image_Plus(
    sampler2D Image,
    vec3 UV,
    vec3 Normal,
    bool Smooth_Interpolation,
    int Projection_Method,
    float Blend,
    out vec4 Color,
    out vec2 Resolution
)
{
    Resolution = vec2(textureSize(Image, 0));
    
    if (Projection_Method == 0)
    {
      _sample_texture(Image, UV.xy, Smooth_Interpolation, Resolution, Color);
    }
    else if (Projection_Method == 1)
    {
      vec4 c1;
      vec4 c2;
      vec4 c3;
      _sample_texture(Image, UV.yz, Smooth_Interpolation, Resolution, c1);
      _sample_texture(Image, UV.xz, Smooth_Interpolation, Resolution, c2);
      _sample_texture(Image, UV.xy, Smooth_Interpolation, Resolution, c3);
      _tex_box_Blend(Normal, c1, c2, c3, Blend, Color);
    }
}