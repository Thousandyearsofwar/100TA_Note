Shader "URP/Testddxddy2"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
		_HeightTex("HeightTex", 2D) = "white" {}
		_BaseColor("BaseColor",Color)=(1,1,1,1)
		_SpecularRange("SpecularRange",Range(10,300))=10
		[HDR]_SpecularColor("SpecularColor",Color)=(1,1,1,1)
		[Normal]_NormalTex("Normal",2D)="bump"{}
		_NormalScale("NormalScale",Range(0,1))=1

        [KeywordEnum(LMRTMB,CMRCMT,FLATSHADE,DDXDDY)]SampleType("Sample type",Float)=0
        _Intensity("Intensity",Range(0,20))=2

		[HideInInspector] _ZWrite("__zw", Float) = 1.0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1.0 
        [Enum(UnityEngine.Rendering.BlendMode)]  _DstBlend("Dst Blend", Float) = 0.0
		[HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags { 
		"RenderType"="Opaque" 
		"RenderPipeline"="UniversalRenderPipeline"

		}
        LOD 100
		HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
				float4 _NormalTex_ST;
				float4 _HeightTex_ST;
				float4 _HeightTex_TexelSize;

				float _Intensity;

				float4 _BaseColor;
				float _NormalScale;

				float _SpecularRange;
				float4 _SpecularColor;
			CBUFFER_END

			TEXTURE2D(_MainTex);	SAMPLER(sampler_MainTex);
			TEXTURE2D(_HeightTex);	SAMPLER(sampler_HeightTex);
			TEXTURE2D(_NormalTex);	SAMPLER(sampler_NormalTex);


			struct Attributes{
				float4 positionOS:POSITION;
				float4 normalOS:NORMAL;
				float4 tangentOS:TANGENT;
				float2 texcoord:TEXCOORD;
			};

			struct Varyings{
				float4 positionCS:SV_POSITION;
				float3 positionWS:VAR_POSITION;
				float2 texcoord:TEXCOORD;
				float3 Normal:TEXCOORD1;
				float3 tangentLightDir:VAR_TANGENTLIGHT;
				float3 tangentViewPos:VAR_TANGENTVIEW;
				float3 tangentFragPos:VAR_TANGENTFRAG;
			};
		ENDHLSL
        Pass
        {
		Tags{
				"LightMode"="UniversalForward"
			}

			Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            HLSLPROGRAM
			
			#pragma multi_compile SAMPLETYPE_LMRTMB SAMPLETYPE_CMRCMT SAMPLETYPE_DDXDDY SAMPLETYPE_FLATSHADE

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment

			Varyings LitPassVertex(Attributes input){
				Light mainLight=GetMainLight();
				float3 L=normalize(mainLight.direction);

				Varyings output;
				output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
				output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
				output.texcoord=TRANSFORM_TEX(input.texcoord,_MainTex);

				float3x3 normalMatrix=transpose(UNITY_MATRIX_M);
				float3 T=normalize(mul(input.tangentOS,normalMatrix));
				float3 N=normalize(mul(input.normalOS,normalMatrix));
				T=normalize(T-dot(T,N)*N);
				float3 B=cross(N,T);
				
				float3x3 TBN;
				TBN[0]=T;
				TBN[1]=B;
				TBN[2]=N;
				output.Normal=TransformObjectToWorldNormal(input.normalOS);
				output.tangentLightDir=mul(TBN,L);
				output.tangentViewPos=mul(TBN,GetCameraPositionWS());
				output.tangentFragPos=mul(TBN,output.positionWS);

				return output;
			}

			float4 LitPassFragment(Varyings input):SV_TARGET{
				float3 color =SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord).rgb;
				float Height=SAMPLE_TEXTURE2D(_HeightTex,sampler_HeightTex,input.texcoord).r;
				float4 N_tex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,input.texcoord);
				float3 N=UnpackNormalScale(N_tex,_NormalScale);

				N=normalize(N);

				//LMRTMB
				#if SAMPLETYPE_LMRTMB

				float Left=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(-1,0)).r;
				float Right=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(1,0)).r;
				float Top=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(0,1)).r;
				float Bottom=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(0,-1)).r;
				float dx=Left-Right;
				float dy=Top-Bottom;

				N=normalize(N+float3(dx,dy,0)*_Intensity);

				//CMRCMT
				#elif  SAMPLETYPE_CMRCMT
				float Left=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(-1,0)).r;
				float Right=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(1,0)).r;
				float Top=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(0,1)).r;
				float Bottom=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(0,-1)).r;
				
				float Center=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.texcoord+_HeightTex_TexelSize*float2(0,-1)).r;

				float dx=Center-Right;
				float dy=Center-Top;

				N=normalize(N+float3(dx,dy,0)*_Intensity);

				//flat shading
				#elif SAMPLETYPE_FLATSHADE
					float3 wT=-ddx(input.positionWS);
					float3 wB=ddy(input.positionWS);
					N=normalize(cross(wT,wB));
					//或者 					
					//float3 wT=ddx(input.positionWS);
					//float3 wB=ddy(input.positionWS);
					//N=normalize(cross(wB,wT));
				//ddxddy
				#else
				
				float dx=-ddx(Height);
				float dy=ddy(Height);

				N=normalize(N+float3(dx,dy,0)*_Intensity);
				#endif

				


				Light mainLight=GetMainLight();
				float3 LightColor=mainLight.color;

				float3 L=normalize(input.tangentLightDir);
				
				float3 V=normalize(input.tangentViewPos-input.tangentFragPos);
				float3 H=normalize(V+L);
				float NdotL=max(dot(L,N),0.0);
				float NdotH=max(dot(N,H),0.0);

				float  diff=NdotL;
				float3 diffuse=diff*color;


				float3 spec=pow(NdotH,_SpecularRange);
				float3 specular=LightColor*spec*_SpecularColor.rgb;

				float3 finalColor=(diffuse+specular)*color;



				return float4(N-input.Normal,1.0);
			}

			ENDHLSL
        }
    }
}