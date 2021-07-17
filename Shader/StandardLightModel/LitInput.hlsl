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
    half _OcclusionStrength;
    half _Anisotropic;
    CBUFFER_END



    TEXTURE2D(_AlbedoTexture);       SAMPLER(sampler_AlbedoTexture);
    TEXTURE2D(_SpecularTexture);       SAMPLER(sampler_SpecularTexture);
    TEXTURE2D(_EmissionTexture);       SAMPLER(sampler_EmissionTexture);

    TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
    TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
    TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);




    #ifdef _SPECULAR_SETUP
        #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
    #else
        #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
    #endif

    half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
    {
        half4 specGloss=0.0;
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
                specGloss=SAMPLE_TEXTURE2D(_SpecularTexture, sampler_SpecularTexture, uv);
            #else
                specGloss=0.0;
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

#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED
