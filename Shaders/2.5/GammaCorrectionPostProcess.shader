Shader "Hidden/GammaCorrectionPostProcess"
{
    Properties
    {
        [HideInInspector]_MainTex("MainTex",2D)="white"{}
        _Gamma("_Gamma",Range(0.454545,2.2))=1
    }
    SubShader
    {
        Tags{
            "RenderPipeline"="UniversalRenderPipeline"
        }
        Cull Off
        ZWrite Off
        ZTest Always

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _Gamma;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct Attributes{
            float4 positionOS:POSITION;
            float2 texcoord:TEXCOORD;
        };
        struct Varyings{
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD;
        };
        ENDHLSL

        pass{
            HLSLPROGRAM
            #pragma vertex vertexShader
            #pragma fragment fragmentShader

            Varyings vertexShader(Attributes input){
                Varyings output;
                output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
                output.texcoord=input.texcoord;
                return output;
            }

            float4 fragmentShader(Varyings input):SV_TARGET{
                float4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord);
                tex=pow(tex,_Gamma);
                return tex;
            }

            ENDHLSL
        }

    }

}
