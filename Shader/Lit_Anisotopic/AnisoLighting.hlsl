#ifndef UNIVERSAL_ANISO_LIGHTING_INCLUDED
#define UNIVERSAL_ANISO_LIGHTING_INCLUDED

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

half3 DirectBDRF_Anisotopic(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS,float3 X,float3 Y)
{
    half3 N=normalWS;
    half3 L=lightDirectionWS;
    half3 V=viewDirectionWS;

    float NdotL=dot(N,L);
    float NdotV=dot(N,V);

    if(NdotL<0||NdotV<0)
        return float3(0,0,0);
    
    half3 H=normalize(L+V);
    float NdotH=dot(N,H);
    float LdotH=dot(L,H);

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

        half aspect=sqrt(1-_Anisotropic*0.9);
        float ax=max(0.001,sqr(brdfData.roughness)/aspect);
        float ay=max(0.001,sqr(brdfData.roughness)*aspect);

        float Ds=GTR2_aniso(NdotH,dot(H,X),dot(H,Y),ax,ay);
        float FH=SchlickFresnel(LdotH);
        float3 Fs=lerp(brdfData.specular,float3(1,1,1),FH);
        float Gs;
        Gs=smithG_GGX_aniso(NdotL,dot(L,X),dot(L,Y),ax,ay);
        Gs*=smithG_GGX_aniso(NdotV,dot(V,X),dot(V,Y),ax,ay);

        half specularTerm=Ds*Fs*Gs;
        // /(4*NdotL*NdotV+0.01);

        half3 res=specularTerm*brdfData.specular+brdfData.diffuse;
        
        return res;
}


half3 LightingPhysicallyBased_Anisotopic(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS,float3 X,float3 Y){
    half3 lightColor=light.color;
    half lightAttenuation=light.distanceAttenuation * light.shadowAttenuation;
    half3 lightDirectionWS= light.direction;

    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    
    return DirectBDRF_Anisotopic(brdfData,normalize(normalWS) , lightDirectionWS, viewDirectionWS,X,Y) * radiance;
} 

half3 EnvironmentBRDF_Anisotopic(BRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
    half3 c = indirectDiffuse * brdfData.diffuse;
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
    return c;
}

    //??????    //??????    //??????

half3 GlossyEnvironmentReflection_Anisotopic(half3 reflectVector, half perceptualRoughness, half occlusion)
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


half3 GlobalIllumination_Anisotopic(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    //??????
    half3 indirectSpecular = GlossyEnvironmentReflection_Anisotopic(reflectVector, brdfData.perceptualRoughness, occlusion);
    return bakedGI;
    return EnvironmentBRDF_Anisotopic(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}



half4 UniversalFragmentPBR_Anisotopic(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha,float3 T,float3 B){
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);
    
    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0)); 



    half3 color = GlobalIllumination_Anisotopic(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    return half4(color, 1.0);
    //color += LightingPhysicallyBased_Anisotopic(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS,T,B);
    color += LightingPhysicallyBased_Anisotopic(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS,T,B);
    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
            color += LightingPhysicallyBased_Anisotopic(brdfData, light, inputData.normalWS, inputData.viewDirectionWS,T,B);
        }
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        color += inputData.vertexLighting * brdfData.diffuse;
    #endif

    color += emission;
    return half4(color, alpha);


}

#endif
