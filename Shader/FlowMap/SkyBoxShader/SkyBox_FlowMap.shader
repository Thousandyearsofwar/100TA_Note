// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "URP/SkyBox_FlowMap"
{
    Properties
    {
        _Tint ("Tint Color", Color) = (.5, .5, .5, .5)
        _LightingColor ("Lighting Color", Color) = (.5, .5, .5, .5)
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
        _Rotation ("Rotation", Range(0, 360)) = 0
        [NoScaleOffset] _MainTex ("Spherical  (HDR)", 2D) = "grey" { }
        [NoScaleOffset] _NoiseTex ("Noise", 2D) = "grey" { }
        [NoScaleOffset] _FlowTex ("FlowMap", 2D) = "grey" { }
        _FlowSpeed ("Flow Speed", float) = 0.5
        _TimeSpeed ("Time Speed", float) = 1.0
        _LightingSpeed ("Lighting Speed", float) = 1.0
        _DebugValue ("DebugValue", float) = 1.0
        [KeywordEnum(6 Frames Layout, Latitude Longitude Layout)] _Mapping ("Mapping", Float) = 1
        [Enum(360 Degrees, 0, 180 Degrees, 1)] _ImageType ("Image Type", Float) = 0
        [Toggle] _MirrorOnBack ("Mirror on Back", Float) = 0
        [Enum(None, 0, Side by Side, 1, Over Under, 2)] _Layout ("3D Layout", Float) = 0
    }

    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
        Cull Off ZWrite Off

        Pass
        {

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            #pragma multi_compile_local __ _MAPPING_6_FRAMES_LAYOUT

            TEXTURE2D(_MainTex);       SAMPLER(sampler_MainTex);
            TEXTURE2D(_FlowTex);       SAMPLER(sampler_FlowTex);
            TEXTURE2D(_NoiseTex);       SAMPLER(sampler_NoiseTex);
            
            float4 _MainTex_TexelSize;
            float4 _MainTex_HDR;
            half4 _Tint;
            float4 _LightingColor;
            half _Exposure;
            float _Rotation;
            float _FlowSpeed;
            float _TimeSpeed;
            float _DebugValue;
            float _LightingSpeed;
            #ifndef _MAPPING_6_FRAMES_LAYOUT
                bool _MirrorOnBack;
                int _ImageType;
                int _Layout;
            #endif

            #ifndef _MAPPING_6_FRAMES_LAYOUT
                inline float2 ToRadialCoords(float3 coords)
                {
                    float3 normalizedCoords = normalize(coords);
                    float latitude = acos(normalizedCoords.y);
                    float longitude = atan2(normalizedCoords.z, normalizedCoords.x);
                    float2 sphereCoords = float2(longitude, latitude) * float2(0.5 / PI, 1.0 / PI);
                    return float2(0.5, 1.0) - sphereCoords;
                }
            #endif

            #ifdef _MAPPING_6_FRAMES_LAYOUT
                inline float2 ToCubeCoords(float3 coords, float3 layout, float4 edgeSize, float4 faceXCoordLayouts, float4 faceYCoordLayouts, float4 faceZCoordLayouts)
                {
                    // Determine the primary axis of the normal
                    float3 absn = abs(coords);
                    float3 absdir = absn > float3(max(absn.y, absn.z), max(absn.x, absn.z), max(absn.x, absn.y)) ? 1 : 0;
                    // Convert the normal to a local face texture coord [-1,+1], note that tcAndLen.z==dot(coords,absdir)
                    // and thus its sign tells us whether the normal is pointing positive or negative
                    float3 tcAndLen = mul(absdir, float3x3(coords.zyx, coords.xzy, float3(-coords.xy, coords.z)));
                    tcAndLen.xy /= tcAndLen.z;
                    // Flip-flop faces for proper orientation and normalize to [-0.5,+0.5]
                    bool2 positiveAndVCross = float2(tcAndLen.z, layout.x) > 0;
                    tcAndLen.xy *= (positiveAndVCross[0] ? absdir.yx : (positiveAndVCross[1] ? float2(absdir[2], 0) : float2(0, absdir[2]))) - 0.5;
                    // Clamp values which are close to the face edges to avoid bleeding/seams (ie. enforce clamp texture wrap mode)
                    tcAndLen.xy = clamp(tcAndLen.xy, edgeSize.xy, edgeSize.zw);
                    // Scale and offset texture coord to match the proper square in the texture based on layout.
                    float4 coordLayout = mul(float4(absdir, 0), float4x4(faceXCoordLayouts, faceYCoordLayouts, faceZCoordLayouts, faceZCoordLayouts));
                    tcAndLen.xy = (tcAndLen.xy + (positiveAndVCross[0] ? coordLayout.xy : coordLayout.zw)) * layout.yz;
                    return tcAndLen.xy;
                }
            #endif

            float3 RotateAroundYInDegrees(float3 vertex, float degrees)
            {
                float alpha = degrees * PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float3(mul(m, vertex.xz), vertex.y).xzy;
            }

            struct appdata_t
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 texcoord : TEXCOORD0;
                #ifdef _MAPPING_6_FRAMES_LAYOUT
                    float3 layout : TEXCOORD1;
                    float4 edgeSize : TEXCOORD2;
                    float4 faceXCoordLayouts : TEXCOORD3;
                    float4 faceYCoordLayouts : TEXCOORD4;
                    float4 faceZCoordLayouts : TEXCOORD5;
                #else
                    float2 image180ScaleAndCutoff : TEXCOORD1;
                    float4 layout3DScaleAndOffset : TEXCOORD2;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);
                o.vertex = TransformObjectToHClip(rotated);
                o.texcoord = v.vertex.xyz;
                #ifdef _MAPPING_6_FRAMES_LAYOUT
                    // layout and edgeSize are solely based on texture dimensions and can thus be precalculated in the vertex shader.
                    float sourceAspect = float(_MainTex_TexelSize.z) / float(_MainTex_TexelSize.w);
                    // Use the halfway point between the 1:6 and 3:4 aspect ratios of the strip and cross layouts to
                    // guess at the correct format.
                    bool3 aspectTest = sourceAspect >
                    float3(1.0, 1.0f / 6.0f + (3.0f / 4.0f - 1.0f / 6.0f) / 2.0f, 6.0f / 1.0f + (4.0f / 3.0f - 6.0f / 1.0f) / 2.0f);
                    // For a given face layout, the coordinates of the 6 cube faces are fixed: build a compact representation of the
                    // coordinates of the center of each face where the first float4 represents the coordinates of the X axis faces,
                    // the second the Y, and the third the Z. The first two float componenents (xy) of each float4 represent the face
                    // coordinates on the positive axis side of the cube, and the second (zw) the negative.
                    // layout.x is a boolean flagging the vertical cross layout (for special handling of flip-flops later)
                    // layout.yz contains the inverse of the layout dimensions (ie. the scale factor required to convert from
                    // normalized face coords to full texture coordinates)
                    if (aspectTest[0]) // horizontal

                    {
                        if (aspectTest[2])
                        {
                            // horizontal strip
                            o.faceXCoordLayouts = float4(0.5, 0.5, 1.5, 0.5);
                            o.faceYCoordLayouts = float4(2.5, 0.5, 3.5, 0.5);
                            o.faceZCoordLayouts = float4(4.5, 0.5, 5.5, 0.5);
                            o.layout = float3(-1, 1.0 / 6.0, 1.0 / 1.0);
                        }
                        else
                        {
                            // horizontal cross
                            o.faceXCoordLayouts = float4(2.5, 1.5, 0.5, 1.5);
                            o.faceYCoordLayouts = float4(1.5, 2.5, 1.5, 0.5);
                            o.faceZCoordLayouts = float4(1.5, 1.5, 3.5, 1.5);
                            o.layout = float3(-1, 1.0 / 4.0, 1.0 / 3.0);
                        }
                    }
                    else
                    {
                        if (aspectTest[1])
                        {
                            // vertical cross
                            o.faceXCoordLayouts = float4(2.5, 2.5, 0.5, 2.5);
                            o.faceYCoordLayouts = float4(1.5, 3.5, 1.5, 1.5);
                            o.faceZCoordLayouts = float4(1.5, 2.5, 1.5, 0.5);
                            o.layout = float3(1, 1.0 / 3.0, 1.0 / 4.0);
                        }
                        else
                        {
                            // vertical strip
                            o.faceXCoordLayouts = float4(0.5, 5.5, 0.5, 4.5);
                            o.faceYCoordLayouts = float4(0.5, 3.5, 0.5, 2.5);
                            o.faceZCoordLayouts = float4(0.5, 1.5, 0.5, 0.5);
                            o.layout = float3(-1, 1.0 / 1.0, 1.0 / 6.0);
                        }
                    }
                    // edgeSize specifies the minimum (xy) and maximum (zw) normalized face texture coordinates that will be used for
                    // sampling in the texture. Setting these to the effective size of a half pixel horizontally and vertically
                    // effectively enforces clamp mode texture wrapping for each individual face.
                    o.edgeSize.xy = _MainTex_TexelSize.xy * 0.5 / o.layout.yz - 0.5;
                    o.edgeSize.zw = -o.edgeSize.xy;
                #else // !_MAPPING_6_FRAMES_LAYOUT
                    // Calculate constant horizontal scale and cutoff for 180 (vs 360) image type
                    if (_ImageType == 0)  // 360 degree
                    o.image180ScaleAndCutoff = float2(1.0, 1.0);
                    else  // 180 degree
                        o.image180ScaleAndCutoff = float2(2.0, _MirrorOnBack ? 1.0 : 0.5);
                    // Calculate constant scale and offset for 3D layouts
                    if (_Layout == 0) // No 3D layout
                    o.layout3DScaleAndOffset = float4(0, 0, 1, 1);
                    else if (_Layout == 1) // Side-by-Side 3D layout
                        o.layout3DScaleAndOffset = float4(unity_StereoEyeIndex, 0, 0.5, 1);
                    else // Over-Under 3D layout
                        o.layout3DScaleAndOffset = float4(0, 1 - unity_StereoEyeIndex, 1, 0.5);
                #endif
                return o;
            }

            #ifdef UNITY_COLORSPACE_GAMMA
                #define unity_ColorSpaceGrey half4(0.5, 0.5, 0.5, 0.5)
                #define unity_ColorSpaceDouble half4(2.0, 2.0, 2.0, 2.0)
                #define unity_ColorSpaceDielectricSpec half4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)
                #define unity_ColorSpaceLuminance half4(0.22, 0.707, 0.071, 0.0) // Legacy: alpha is set to 0.0 to specify gamma mode
            #else // Linear values
                #define unity_ColorSpaceGrey half4(0.214041144, 0.214041144, 0.214041144, 0.5)
                #define unity_ColorSpaceDouble half4(4.59479380, 4.59479380, 4.59479380, 2.0)
                #define unity_ColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)
                #define unity_ColorSpaceLuminance half4(0.0396819152, 0.458021790, 0.00609653955, 1.0) // Legacy: alpha is set to 1.0 to specify linear mode
            #endif

            inline half3 DecodeHDR(half4 data, half4 decodeInstructions)
            {
                // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
                half alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;

                // If Linear mode is not supported we can skip exponent part
                #if defined(UNITY_COLORSPACE_GAMMA)
                    return(decodeInstructions.x * alpha) * data.rgb;
                #else
                    #if defined(UNITY_USE_NATIVE_HDR)
                        return decodeInstructions.x * data.rgb; // Multiplier for future HDRI relative to absolute conversion.
                    #else
                        return(decodeInstructions.x * pow(alpha, decodeInstructions.y)) * data.rgb;
                    #endif
                #endif
            }


            float2 random(float2 st)
            {
                st = float2(dot(st, float2(127.1, 311.7)), dot(st, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            float4 frag(v2f i) : SV_Target
            {
                //o.layout3DScaleAndOffset = float4(0, 0, 1, 1);
                // o.image180ScaleAndCutoff = float2(1.0, 1.0);
                #ifdef _MAPPING_6_FRAMES_LAYOUT
                    float2 tc = ToCubeCoords(i.texcoord, i.layout, i.edgeSize, i.faceXCoordLayouts, i.faceYCoordLayouts, i.faceZCoordLayouts);
                #else
                    float2 tc = ToRadialCoords(i.texcoord);
                    if (tc.x > i.image180ScaleAndCutoff[1])
                        return half4(0, 0, 0, 1);
                    tc.x = fmod(tc.x * i.image180ScaleAndCutoff[0], 1);
                    tc = (tc + i.layout3DScaleAndOffset.xy) * i.layout3DScaleAndOffset.zw;
                #endif

                float3 flowDir = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex, tc) * 2 - 1;
                float phase0 = frac(_Time * _TimeSpeed);
                float phase1 = frac(_Time * _TimeSpeed + 0.5);
                float t = abs(phase0 * 2 - 1);
                float2 uv0 = tc - flowDir.xy * _FlowSpeed * phase0;
                float2 uv1 = tc - flowDir.xy * _FlowSpeed * phase1;

                float4 tex0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv0);
                float4 tex1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv1);

                float4 tex = lerp(tex0, tex1, t);

                float curveVal = saturate(abs(1 - i.texcoord.y));
                curveVal = smoothstep(0.69, 1, curveVal);
                

                float mask = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.texcoord.xz * 0.05) * (1 - curveVal) * 2.11;
                float x = _Time;
                float curve0 = random(float2(3 * x, 3 * x)).x * frac(_TimeSpeed * mask) * _DebugValue ;
                float3 lighting = _LightingColor * mask * curve0;


                float3 _TintColor = lerp(_Tint, float3(0, 0, 0), curveVal);

                _TintColor = _TintColor + lighting ;

                float3 c = DecodeHDR(tex, _MainTex_HDR);
                c = c * _TintColor * unity_ColorSpaceDouble;
                c *= _Exposure;

                
                

                //_TintColor Debug use
                
                //return float4(lighting.xyz, 1);
                return float4(c.xyz, 1);
            }
            ENDHLSL

        }
    }


    Fallback Off
    //CustomEditor "SkyboxPanoramicShaderGUI"

}