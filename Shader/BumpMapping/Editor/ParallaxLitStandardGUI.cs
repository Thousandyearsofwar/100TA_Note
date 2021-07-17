using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    public static class ParallaxLitStandardGUI
    {
        public static class Styles
        {
            public static GUIContent AlbedoMapTip = new GUIContent("AlbedoTex", "漫反射贴图");
            public static GUIContent NormalMapTip = new GUIContent("NormalTex", "法线贴图");
            public static GUIContent HeightMapTip = new GUIContent("HeightTex", "高度图");
            public static GUIContent HeightScaleTip = new GUIContent("Height Scale", "高度比例");
            public static GUIContent SpecularMapTip = new GUIContent("SpecularTex", "镜面反射贴图");
            public static GUIContent EmissionMapTip = new GUIContent("EmissionTex", "自发光贴图");

            public static GUIContent AlbedoTip = new GUIContent("Albedo", "漫反射率");
            public static GUIContent SpecularTip = new GUIContent("Specular", "镜面反射率");
            public static GUIContent NormalScaleTip = new GUIContent("NormalScale", "法线比例");
            public static GUIContent GlossTip = new GUIContent("Gloss", "高光度");

            public static GUIContent LightModeTip = new GUIContent("LightMode", "光照模型");
            public static readonly string[] LightModeToggleText = { "经典光照", "PBR" };

            public static GUIContent ParallaxModeTip = new GUIContent("ParallaxMode", "视差模式");
            public static readonly string[] ParallaxModeToggleText = { "Off", "Parallax", "Steep_Parallax", "POM" };

            public static GUIContent ParallaxDepthBiasTip=new GUIContent("Parallax Depth Bias","视差深度偏移值");


            //@@@ PBR use
            public static GUIContent workflowModeText = new GUIContent("Workflow Mode",
    "Select a workflow that fits your textures. Choose between Metallic or Specular.");

            public static GUIContent specularMapText =
                new GUIContent("Specular Map", "Sets and configures the map and color for the Specular workflow.");

            public static GUIContent metallicMapText =
                new GUIContent("Metallic Map", "Sets and configures the map for the Metallic workflow.");

            public static GUIContent smoothnessText = new GUIContent("Smoothness",
                "Controls the spread of highlights and reflections on the surface.");

            public static GUIContent smoothnessMapChannelText =
                new GUIContent("Source",
                    "Specifies where to sample a smoothness map from. By default, uses the alpha channel for your map.");

            public static GUIContent highlightsText = new GUIContent("Specular Highlights",
                "When enabled, the Material reflects the shine from direct lighting.");

            public static GUIContent reflectionsText =
                new GUIContent("Environment Reflections",
                    "When enabled, the Material samples reflections from the nearest Reflection Probes or Lighting Probe.");

            public static GUIContent occlusionText = new GUIContent("Occlusion Map",
                "Sets an occlusion map to simulate shadowing from ambient lighting.");

            public static readonly string[] metallicSmoothnessChannelNames = { "Metallic Alpha", "Albedo Alpha" };
            public static readonly string[] specularSmoothnessChannelNames = { "Specular Alpha", "Albedo Alpha" };
            //
        }

        public struct ParallaxProperties
        {
            public MaterialProperty ParallaxModeToggle;
            public MaterialProperty HeightMap;
            public MaterialProperty HeightScale;
            public MaterialProperty ParrallaxDepthBias;

            public ParallaxProperties(MaterialProperty[] properties)
            {
                this.ParallaxModeToggle = BaseShaderGUI.FindProperty("_ParallaxMode", properties, false);

                this.HeightMap = BaseShaderGUI.FindProperty("_HeightMap", properties, false);
                this.HeightScale = BaseShaderGUI.FindProperty("_HeightScale", properties, false);
                this.ParrallaxDepthBias=BaseShaderGUI.FindProperty("_ParrallaxDepthBias", properties, false);
            }
        }

        public static void Inputs(ParallaxProperties properties, MaterialEditor materialEditor, Material material)
        {
            if (properties.HeightMap != null)
            {
                EditorGUI.BeginChangeCheck();
                var ParallaxModeToggleIndex = (int)properties.ParallaxModeToggle.floatValue;
                ParallaxModeToggleIndex = EditorGUILayout.Popup(Styles.ParallaxModeTip, ParallaxModeToggleIndex, Styles.ParallaxModeToggleText);
                if (EditorGUI.EndChangeCheck())
                    properties.ParallaxModeToggle.floatValue = ParallaxModeToggleIndex;
                if ((ParallaxMode)ParallaxModeToggleIndex != ParallaxMode.OFF)
                {
                    materialEditor.TexturePropertySingleLine(Styles.HeightMapTip, properties.HeightMap,
                        properties.HeightScale);
                    materialEditor.ShaderProperty(properties.ParrallaxDepthBias,Styles.ParallaxDepthBiasTip);
                }
            }
        }
        public static void SetMaterialKeywords(Material material)
        {
           
        }

    }
}
