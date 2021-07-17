#ifndef UNIVERSAL_STANDARD_LIGHTING_INCLUDED
    #define UNIVERSAL_STANDARD_LIGHTING_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    #define PI 3.14159265358979323846

    float sqr(float x ){return x*x;}

    float SchlickFresnel(float u){
        float m= clamp(1-u,0,1);
        float m2=m*m;
        return m2*m2*m;
    }

    float GTR1(float NdotH,float a){
        if(a>=1)
        return 1/PI;
        float a2 =a*a;
        float t=1+(a2-1)*NdotH*NdotH;
        return (a2-1)/(PI*log(a2)*t);
    }

    float GTR2(float NdotH,float a){
        float a2 =a*a;
        float t=1+(a2-1)*NdotH*NdotH;
        return (a2-1)/(PI*t*t);
    }

    float GTR2_aniso(float NdotH,float HdotX,float HdotY,float ax,float ay){
        return 1/(PI*ax*ay*sqr(sqr(HdotX/ax)+sqr(HdotY/ay)+NdotH*NdotH));
    }

    float smithG_GGX(float NdotV,float alphaG){
        float a=alphaG*alphaG;
        float b=NdotV*NdotV;
        return 1/(NdotV+sqrt(a+b-a*b));
    }

    float smithG_GGX_aniso(float NdotV,float VdotX,float VdotY,float ax,float ay){
        return 1/(NdotV+sqrt(sqr(VdotX*ax)+sqr(VdotY*ay)+sqr(NdotV)));
    }

    float3 mon2lin(float3 x){
        return float3(pow(x[0],2.2),pow(x[1],2.2),pow(x[2],2.2));
    }

    half3 DirectBDRF_Standard(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
    {
        /*
        struct BRDFData
        {
            half3 diffuse;
            half3 specular;
            half perceptualRoughness;
            half roughness;
            half roughness2;
            half grazingTerm;

            // We save some light invariant BRDF terms so we don't have to recompute
            // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
            half normalizationTerm;     // roughness * 4.0 + 2.0
            half roughness2MinusOne;    // roughness^2 - 1.0
        };
        */

        #ifndef _SPECULARHIGHLIGHTS_OFF
            float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));

            float NoH = saturate(dot(normalWS, halfDir));
            half LoH = saturate(dot(lightDirectionWS, halfDir));

            // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
            // BRDFspec = (D * V * F) / 4.0
            // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
            // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
            // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
            // https://community.arm.com/events/1155

            // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
            // We further optimize a few light invariant terms
            // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
            float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

            half LoH2 = LoH * LoH;
            half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

            // On platforms where half actually means something, the denominator has a risk of overflow
            // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
            // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
            #if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
                specularTerm = specularTerm - HALF_MIN;
                specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
            #endif

            half3 color = specularTerm * brdfData.specular + brdfData.diffuse;
            return color;
        #else
            return brdfData.diffuse;
        #endif
    }


    half3 LightingPhysicallyBased_Standard(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS){
        half NdotL = saturate(dot(normalWS, lightDirectionWS));
        half3 radiance = lightColor * (lightAttenuation * NdotL);
        return DirectBDRF_Standard(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
    } 

    half3 LightingPhysicallyBased_Standard(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
    {
        return LightingPhysicallyBased(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS);
    }

    half3 EnvironmentBRDF_Standard(BRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
    {
        half3 c = indirectDiffuse * brdfData.diffuse;
        float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
        c += surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
        return c;
    }



    half3 GlossyEnvironmentReflection_Standard(half3 reflectVector, half perceptualRoughness, half occlusion)
    {
        #if !defined(_ENVIRONMENTREFLECTIONS_OFF)
            half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
            half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);

            #if !defined(UNITY_USE_NATIVE_HDR)
                half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
            #else
                half3 irradiance = encodedIrradiance.rgb;
            #endif

            return irradiance * occlusion;
        #endif // GLOSSY_REFLECTIONS

        return _GlossyEnvironmentColor.rgb * occlusion;
    }


    half3 GlobalIllumination_Standard(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
    {
        half3 reflectVector = reflect(-viewDirectionWS, normalWS);
        half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

        half3 indirectDiffuse = bakedGI * occlusion;
        half3 indirectSpecular = GlossyEnvironmentReflection_Standard(reflectVector, brdfData.perceptualRoughness, occlusion);

        return EnvironmentBRDF_Standard(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
    }



    half4 UniversalFragmentPBR_Standard(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha){
        BRDFData brdfData;
        InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);
        
        Light mainLight = GetMainLight(inputData.shadowCoord);
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

        half3 color = GlobalIllumination_Standard(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
        color += LightingPhysicallyBased_Standard(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

        #ifdef _ADDITIONAL_LIGHTS
            uint pixelLightCount = GetAdditionalLightsCount();
            for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
            {
                Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                color += LightingPhysicallyBased_Standard(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
            }
        #endif

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            color += inputData.vertexLighting * brdfData.diffuse;
        #endif

        color += emission;
        return half4(color, alpha);

    }

    //@@@Basic lighting
    half4 UniversalFragmentBasic_lighting(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha){
        BRDFData brdfData;
        InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);
        
        Light mainLight = GetMainLight(inputData.shadowCoord);
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

        float3 N=inputData.normalWS;
        float3 L=mainLight.direction;
        float3 V=inputData.viewDirectionWS;
        float3 H=normalize(V+L);
        float3 R = reflect(-V,N);

        float3 directDiffuse=mainLight.color*albedo*saturate(dot(N,L));
        float3 directSpecular=mainLight.color*albedo*pow(saturate(dot(N,H)),_Gloss+0.01);
        half fresnelTerm = Pow4(1.0 - saturate(dot(N, V)));

        float3 indirectDiffuse = inputData.bakedGI*(albedo * (half3(1.0h, 1.0h, 1.0h) - specular));
        float3 indirectSpecular = GlossyEnvironmentReflection_Standard(R, (256-_Gloss)/256, 1.0);

        half3 color=indirectDiffuse+indirectSpecular*fresnelTerm+directDiffuse+directSpecular;
        //half3 color=directDiffuse+directSpecular;
        // half3 color = GlobalIllumination_Standard(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
        // color += LightingPhysicallyBased_Standard(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

        #ifdef _ADDITIONAL_LIGHTS
            uint pixelLightCount = GetAdditionalLightsCount();
            for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
            {
                Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                L=light.direction;

                directDiffuse=light.color*albedo*saturate(dot(N,L));
                directSpecular=light.color*albedo*pow(saturate(dot(V,R)),_Gloss);

                color+=directDiffuse+directSpecular;
                //color += LightingPhysicallyBased_Standard(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
            }
        #endif

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            color += inputData.vertexLighting * brdfData.diffuse;
        #endif

        color += emission;
        return half4(color, alpha);

    }



#endif
