#ifndef UNIVERSAL_LIT_INPUT_INCLUDED
#define UNIVERSAL_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"


CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;

half4 _Albedo;
half _Gloss;

half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _HeightScale;
half _ParrallaxDepthBias;
half _OcclusionStrength;
half _Anisotropic;
half _TimeSpeed;
CBUFFER_END



TEXTURE2D(_AlbedoTexture);       SAMPLER(sampler_AlbedoTexture);
TEXTURE2D(_SpecularTexture);     SAMPLER(sampler_SpecularTexture);
TEXTURE2D(_HeightMap);           SAMPLER(sampler_HeightMap);
TEXTURE2D(_FlowMap);             SAMPLER(sampler_FlowMap);
TEXTURE2D(_EmissionTexture);     SAMPLER(sampler_EmissionTexture);

TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);


#include "Parallax.hlsl"

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss = 0.0;
    #ifdef _LightMode_PBR
        #ifdef _METALLICSPECGLOSSMAP
            specGloss = SAMPLE_METALLICSPECULAR(uv);
            #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                specGloss.a = albedoAlpha * _Smoothness;
            #else
                specGloss.a *= _Smoothness;
            #endif
        #else // _METALLICSPECGLOSSMAP
            #if _SPECULAR_SETUP
                specGloss.rgb = _SpecColor.rgb;
            #else
                specGloss.rgb = _Metallic.rrr;
            #endif

            #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
                specGloss.a = albedoAlpha * _Smoothness;
            #else
                specGloss.a = _Smoothness;
            #endif
        #endif
    #else
        #if _SPECULARMAP
            specGloss = SAMPLE_TEXTURE2D(_SpecularTexture, sampler_SpecularTexture, uv);
        #else
            specGloss = 0.0;
        #endif
    #endif

    return specGloss;
}

half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
        // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
        #if defined(SHADER_API_GLES)
            return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        #else
            half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            return LerpWhiteTo(occ, _OcclusionStrength);
        #endif
    #else
        return 1.0;
    #endif
}

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    #ifdef _LightMode_PBR
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_AlbedoTexture, sampler_AlbedoTexture));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _Albedo, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        
        outSurfaceData.albedo = albedoAlpha.rgb * _Albedo.rgb;

        #if _SPECULAR_SETUP
            outSurfaceData.metallic = 1.0h;
            outSurfaceData.specular = specGloss.rgb;
        #else
            outSurfaceData.metallic = specGloss.r;
            outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
        #endif

        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    #else
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_AlbedoTexture, sampler_AlbedoTexture));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _Albedo, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        
        outSurfaceData.albedo = albedoAlpha.rgb * _Albedo.rgb;

        outSurfaceData.metallic = 1.0h;
        outSurfaceData.specular = specGloss.rgb;


        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    #endif
}

void ParallaxOffset(inout float2 uv, float3 viewDirWS, float4 tangentWS, float3 normalWS)
{
    float height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv);
    #ifdef _ParallaxMode_Parallaxq
        half3 viewDirTS = SafeNormalize(viewDirWS);
        float sgn = tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);
        viewDirTS = TransformWorldToTangent(viewDirTS, half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz));
        viewDirTS = NormalizeNormalPerPixel(viewDirTS);

        
        uv += height * _HeightScale * viewDirTS.xy / viewDirTS.z;
    #elif _ParallaxMode_Steep_Parallax
        half3 viewDirTS = SafeNormalize(viewDirWS);
        float sgn = tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);
        viewDirTS = TransformWorldToTangent(viewDirTS, half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz));
        viewDirTS = NormalizeNormalPerPixel(viewDirTS);

        uv += ParallaxMapping(uv, viewDirTS);
    #elif _ParallaxMode_POM
        half3 viewDirTS = SafeNormalize(viewDirWS);
        float sgn = tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);
        viewDirTS = TransformWorldToTangent(viewDirTS, half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz));
        viewDirTS = NormalizeNormalPerPixel(viewDirTS);

        uv += ParallaxOcclusionMapping(uv, viewDirTS, saturate(dot(normalWS, viewDirWS)));
    #endif
}

inline void InitializeStandardLitSurfaceData_FlowMap(inout float2 uv, out SurfaceData outSurfaceData, float3 viewDirWS, float4 T, float3 N)
{
    ParallaxOffset(uv, viewDirWS, T, N);
    #ifdef _LightMode_PBR
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_AlbedoTexture, sampler_AlbedoTexture));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _Albedo, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        
        outSurfaceData.albedo = albedoAlpha.rgb * _Albedo.rgb;

        #if _SPECULAR_SETUP
            outSurfaceData.metallic = 1.0h;
            outSurfaceData.specular = specGloss.rgb;
        #else
            outSurfaceData.metallic = specGloss.r;
            outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
        #endif

        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    #else
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_AlbedoTexture, sampler_AlbedoTexture));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, _Albedo, _Cutoff);

        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
        
        outSurfaceData.albedo = albedoAlpha.rgb * _Albedo.rgb;

        outSurfaceData.metallic = 1.0h;
        outSurfaceData.specular = specGloss.rgb;


        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        outSurfaceData.occlusion = SampleOcclusion(uv);
        outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    #endif
}

void lerpStandardLitSurfaceData(float t, inout SurfaceData surfaceOutput0, SurfaceData surfaceOutput1)
{
    /*
    struct SurfaceData
    {
        half3 albedo;
        half3 specular;
        half  metallic;
        half  smoothness;
        half3 normalTS;
        half3 emission;
        half  occlusion;
        half  alpha;
    };
    */
    #ifdef _LightMode_PBR
        surfaceOutput0.albedo = lerp(surfaceOutput0.albedo, surfaceOutput1.albedo, t);
        surfaceOutput0.specular = lerp(surfaceOutput0.specular, surfaceOutput1.specular, t);
        surfaceOutput0.metallic = lerp(surfaceOutput0.metallic, surfaceOutput1.metallic, t);
        surfaceOutput0.smoothness = lerp(surfaceOutput0.smoothness, surfaceOutput1.smoothness, t);
        surfaceOutput0.normalTS = lerp(surfaceOutput0.normalTS, surfaceOutput1.normalTS, t);
        surfaceOutput0.emission = lerp(surfaceOutput0.emission, surfaceOutput1.emission, t);
        surfaceOutput0.occlusion = lerp(surfaceOutput0.occlusion, surfaceOutput1.occlusion, t);
        surfaceOutput0.alpha = lerp(surfaceOutput0.alpha, surfaceOutput1.alpha, t);
    #endif
}

#endif //