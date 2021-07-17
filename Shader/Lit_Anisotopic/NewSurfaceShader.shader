Shader "Study /Anisotropic"
{
	Properties
	{
		_Diffuse("Diffuse", Color) = (1, 1, 1, 1)
		_Specular("Specular", Color) = (1, 1, 1, 1)
		_Gloss("Gloss", Range(8.0, 256)) = 20
		_Tangent ("Tangent", Range(0, 1)) = 0
	}
	SubShader
	{
		Pass
		{
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#include "Lighting.cginc"

			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			float _Tangent;

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 worldBinormal : TEXCOORD2;
			};

			//顶点着色器当中的计算
			v2f vert(a2v v)
			{
				v2f o;
				//转换顶点空间：模型=>投影
				o.pos = UnityObjectToClipPos(v.vertex);
				//转换顶点空间：模型=>世界
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				//转换法线空间：模型=>世界
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldNormal = worldNormal;
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				o.worldBinormal = cross(worldTangent, worldNormal);
				return o;
			}

			//片元着色器中的计算
			fixed4 frag(v2f i) : SV_Target
			{
				//获取环境光
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				fixed3 AnisotropicworldNormal = normalize(lerp(i.worldNormal + i.worldBinormal, i.worldBinormal, _Tangent));
				fixed3 lightDir =  normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 viewDir =  normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 reflectDir = normalize(lightDir + viewDir);
				//计算反射信息
				float Anisotropic = dot(AnisotropicworldNormal, reflectDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, sqrt(1 - (Anisotropic * Anisotropic))), _Gloss);
				//Lanbert光照
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(i.worldNormal, lightDir));
				//对高光范围进行遮罩
				specular *= saturate(diffuse * 2);
				return fixed4(ambient + diffuse + specular, 1.0);
			}
			ENDCG
		}
	}
	FallBack "Specular"
}