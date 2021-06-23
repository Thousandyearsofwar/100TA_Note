Shader "Unlit/GammaCorrectionTest"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "black" {}

        [ToggleOff]_Gamma("Gamma correction",Int)=0

        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags { 
            "RenderPipeline"="UniversalRenderPipeline"
        }
        LOD 100
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;

        CBUFFER_END

        TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);

        struct Attributes{
            float4 positionOS:POSITION;
            float2 texcoord:TEXCOORD;
        };

        struct Varyings{
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD0;
        };
        ENDHLSL
        Pass
        {
            Tags{
                "LightMode"="UniversalForward"
            }
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull Off

            HLSLPROGRAM
            #pragma shader_feature _CLIPPING
            #pragma shader_feature_local _GAMMA_OFF

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment


            Varyings LitPassVertex(Attributes input){
                Varyings output;
                output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
                output.texcoord=input.texcoord;
                return output;
            }

            float4 LitPassFragment(Varyings input):SV_TARGET{
                float4 color_Tex =SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
                #if  _GAMMA_OFF
                    return color_Tex;
                #else
                    return pow(color_Tex,2.2);
                #endif
            }

            ENDHLSL
        }
    }
}
