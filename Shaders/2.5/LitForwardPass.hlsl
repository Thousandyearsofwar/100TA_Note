#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
    #define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

    #include "StandardLighting.hlsl"
    #include "Parallax.hlsl"

    struct Attributes
    {
        float4 positionOS   : POSITION;
        float3 normalOS     : NORMAL;
        float4 tangentOS    : TANGENT;
        float2 texcoord     : TEXCOORD0;
        float2 lightmapUV   : TEXCOORD1;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float2 uv                       : TEXCOORD0;
        DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            float3 positionWS               : TEXCOORD2;
        #endif

        float3 normalWS                 : TEXCOORD3;

        float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign

        float3 bitangentWS              :TEXCOORD8;

        float3 viewDirWS                : TEXCOORD5;

        half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            float4 shadowCoord              : TEXCOORD7;
        #endif

        float4 positionCS               : SV_POSITION;
        float4 ssPos					:VAR_SCRPOS;

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
    {
        inputData = (InputData)0;

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            inputData.positionWS = input.positionWS;
        #endif

        half3 viewDirWS = SafeNormalize(input.viewDirWS);
        #ifdef _NORMALMAP 
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
        #else
            inputData.normalWS = input.normalWS;
        #endif

        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        inputData.viewDirectionWS = viewDirWS;

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            inputData.shadowCoord = input.shadowCoord;
        #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        #else
            inputData.shadowCoord = float4(0, 0, 0, 0);
        #endif

        inputData.fogCoord = input.fogFactorAndVertexLight.x;
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
        inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
    }

    ///////////////////////////////////////////////////////////////////////////////
    //                  Vertex and Fragment functions                            //
    ///////////////////////////////////////////////////////////////////////////////

    float4x4 _RowAccess={1,1,1,1,
        1,1,1,1,
        1,1,1,1,
    1,1,1,1};

    // Used in Standard (Physically Based) shader
    Varyings LitPassVertex(Attributes input)
    {
        Varyings output = (Varyings)0;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        
        // normalWS and tangentWS already normalize.
        // this is required to avoid skewing the direction during interpolation
        // also required for per-vertex lighting and SH evaluation
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
        float3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

        // already normalized from normal transform to WS.
        output.normalWS = normalInput.normalWS;
        output.viewDirWS = viewDirWS;
        // #ifdef normal map canceled

        #ifdef _NORMALMAP
            real sign = input.tangentOS.w * GetOddNegativeScale();
            output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
            output.bitangentWS = cross(output.normalWS, output.tangentWS) * sign;
        #else
            output.tangentWS.xyz =normalInput.tangentWS.xyz;
            output.bitangentWS =normalInput.bitangentWS;
        #endif


        OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
        OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            output.positionWS = vertexInput.positionWS;
        #endif

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            output.shadowCoord = GetShadowCoord(vertexInput);
        #endif

        output.positionCS = vertexInput.positionCS;
        output.ssPos.xy = vertexInput.positionCS.xy*0.5+0.5*float2( vertexInput.positionCS.w, vertexInput.positionCS.w);
        output.ssPos.zw = vertexInput.positionCS.zw;
        return output;
    }



    half4 LitPassFragment_Parallax(Varyings input) : SV_Target{
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        //@@@Parallax UV Offset
        
        
        #ifdef _ParallaxMode_Parallax 
            half3 viewDirTS = SafeNormalize(input.viewDirWS);
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            viewDirTS = TransformWorldToTangent(viewDirTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
            viewDirTS = NormalizeNormalPerPixel(viewDirTS);

            float height=SAMPLE_TEXTURE2D(_HeightMap,sampler_HeightMap,input.uv);
            input.uv+=height*_HeightScale*viewDirTS.xy/viewDirTS.z;
        #elif _ParallaxMode_Steep_Parallax
            half3 viewDirTS = SafeNormalize(input.viewDirWS);
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            viewDirTS = TransformWorldToTangent(viewDirTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
            viewDirTS = NormalizeNormalPerPixel(viewDirTS);

            input.uv+=ParallaxMapping(input.uv,viewDirTS);
        #elif _ParallaxMode_POM
            half3 viewDirTS = SafeNormalize(input.viewDirWS);
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            viewDirTS = TransformWorldToTangent(viewDirTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
            viewDirTS = NormalizeNormalPerPixel(viewDirTS);

            float height=SAMPLE_TEXTURE2D(_HeightMap,sampler_HeightMap,input.uv);
            input.uv+=height*_HeightScale*viewDirTS.xy/viewDirTS.z;
        #endif

        


        SurfaceData surfaceData;
        InitializeStandardLitSurfaceData(input.uv, surfaceData);

        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, inputData);

        float3 N=inputData.normalWS;

        half4 color;
        #ifdef _LightMode_Classic_Lighting
            color =UniversalFragmentBasic_lighting(inputData, surfaceData.albedo, surfaceData.metallic,
            surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);
        #else
            color = UniversalFragmentPBR_Standard(inputData, surfaceData.albedo, surfaceData.metallic,
            surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);
        #endif
        
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
        //color.rgb = N;
        color.a = OutputAlpha(color.a);
        
        return color;
    }






    // Used in Standard (Physically Based) shader
    half4 LitPassFragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        SurfaceData surfaceData;
        InitializeStandardLitSurfaceData(input.uv, surfaceData);

        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, inputData);

        half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);
        
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
        color.a = OutputAlpha(color.a);
        return color;

        /* 	
        input.ssPos.xy/=input.ssPos.w;
        #ifdef UNITY_STARTS_AT_Top
            input.ssPos.y=1-input.ssPos.y;
        #endif
        float DITHER_THRESHOLDS[16] =
        {
            1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
            13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
            4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
            16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
        };
        float2 pos=input.ssPos.xy*_ScreenParams.xy;
        uint index = (uint(pos.x) % 4) * 4 + uint(pos.y) % 4;

        
        clip(0.3 - DITHER_THRESHOLDS[index]);

        return color; 
        */
    }

#endif
