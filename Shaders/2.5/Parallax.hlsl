#ifndef UNIVERSAL_PARALLAX_INCLUDED
#define UNIVERSAL_PARALLAX_INCLUDED

float2 ParallaxMapping(float2 texCoords, float3 viewDir)
{
    float numLayers = 20;
    float layerDepth = 1.0 / numLayers;

    float currentLayerDepth = 0.0;

    float2 P = viewDir.xy / viewDir.z * _HeightScale;

    float2 deltaTexcoords = P / numLayers;

    float2 currentTexCoords = texCoords;

    float2 AddUV = float2(0, 0);

    float currentDepthMapValue = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, currentTexCoords).r;

    for (int i = 0; i < numLayers; i++)
    {

        if (currentLayerDepth > currentDepthMapValue)
            return AddUV;
        AddUV += deltaTexcoords;
        currentDepthMapValue = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, currentTexCoords + AddUV).r;
        currentLayerDepth += layerDepth;
    }
    return AddUV;
}

float2 ParallaxOcclusionMapping(float2 texCoords, float3 viewDir)
{
    float2 offsetUV = viewDir.xy / viewDir.z * _HeightScale;
    float RayNum = 20;

    float layerDepth = 1.0 / RayNum;

    float2 SteepingUV = offsetUV / RayNum;

    float offsetUVLength = length(offsetUV);

    float currentLayerDepth = 0;

    float offUV = float2(0, 0);

    for (int i = 0; i < RayNum; i++)
    {
        offUV += SteepingUV;

        float currentDepth = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, texCoords + offUV).r;
        currentLayerDepth += currentDepth;

        if(currentDepth<currentLayerDepth)
            break;
    }

    float2 T0=texCoords-SteepingUV,T1=texCoords+offUV;

    for(int j=0;j<20;j++){
        float2 P0=(T0+T1)/2;
        float P0Height=SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap,P0).r;
        float P0LayerHeight=length(P0)/offsetUVLength;
        if(P0Height<P0LayerHeight)
            T0=P0;
        else
            T1=P0;
    }

    return (T0+T1)/2-texCoords;
}



#endif