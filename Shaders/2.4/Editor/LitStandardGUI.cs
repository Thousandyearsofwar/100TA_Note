using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    public enum WorkflowMode
    {
        Specular = 0,
        Metallic
    }

    public enum SmoothnessMapChannel
    {
        SpecularMetallicAlpha,
        AlbedoAlpha,
    }

    public enum LightMode
    {
        Classic_Lighting = 0,
        //Further Version will update it
        PBR = 1

    }
    public static class LitStandardGUI
    {
        public static class Styles
        {
            public static GUIContent AlbedoMapTip = new GUIContent("AlbedoTex", "漫反射贴图");
            public static GUIContent NormalMapTip = new GUIContent("NormalTex", "法线贴图");
            public static GUIContent SpecularMapTip = new GUIContent("SpecularTex", "镜面反射贴图");
            public static GUIContent EmissionMapTip = new GUIContent("EmissionTex", "自发光贴图");

            public static GUIContent AlbedoTip = new GUIContent("Albedo", "漫反射率");
            public static GUIContent SpecularTip = new GUIContent("Specular", "镜面反射率");
            public static GUIContent NormalScaleTip = new GUIContent("NormalScale", "法线比例");
            public static GUIContent GlossTip = new GUIContent("Gloss", "高光度");

            public static GUIContent LightModeTip = new GUIContent("LightMode", "光照模型");
            public static readonly string[] LightModeToggleText = { "经典光照", "PBR" };

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

        public struct LitStandardProperties
        {
            public MaterialProperty LightModeToggle;
            public MaterialProperty AlbedoMap;
            public MaterialProperty NormalMap;
            public MaterialProperty SpecularMap;
            public MaterialProperty EmissionMap;
            public MaterialProperty Albedo;
            public MaterialProperty NormalScale;
            public MaterialProperty Gloss;
            //public MaterialProperty AnisotropicParam;

            //@@@ PBR use
            // Surface Option Props
            public MaterialProperty workflowMode;

            // Surface Input Props
            public MaterialProperty metallic;
            public MaterialProperty specColor;
            public MaterialProperty metallicGlossMap;
            public MaterialProperty specGlossMap;
            public MaterialProperty smoothness;
            public MaterialProperty smoothnessMapChannel;
            public MaterialProperty bumpMapProp;
            public MaterialProperty bumpScaleProp;
            public MaterialProperty occlusionStrength;
            public MaterialProperty occlusionMap;

            // Advanced Props
            public MaterialProperty highlights;
            public MaterialProperty reflections;
            //

            public LitStandardProperties(MaterialProperty[] properties)
            {
                this.LightModeToggle = BaseShaderGUI.FindProperty("_LightMode", properties, false);
                this.AlbedoMap = BaseShaderGUI.FindProperty("_AlbedoTexture", properties, false);
                this.NormalMap = BaseShaderGUI.FindProperty("_BumpMap", properties, false);
                this.SpecularMap = BaseShaderGUI.FindProperty("_SpecularTexture", properties, false);
                this.EmissionMap = BaseShaderGUI.FindProperty("_EmissionTexture", properties, false);

                this.Albedo = BaseShaderGUI.FindProperty("_Albedo", properties, false);
                this.NormalScale = BaseShaderGUI.FindProperty("_BumpScale", properties, false);
                this.Gloss = BaseShaderGUI.FindProperty("_Gloss", properties, false);
                //this.AnisotropicParam = BaseShaderGUI.FindProperty("_Anisotropic", parameters, false);

                //@@@PBR use
                // Surface Option Props
                workflowMode = BaseShaderGUI.FindProperty("_WorkflowMode", properties, false);
                // Surface Input Props
                metallic = BaseShaderGUI.FindProperty("_Metallic", properties);
                specColor = BaseShaderGUI.FindProperty("_SpecColor", properties, false);
                metallicGlossMap = BaseShaderGUI.FindProperty("_MetallicGlossMap", properties);
                specGlossMap = BaseShaderGUI.FindProperty("_SpecGlossMap", properties, false);
                smoothness = BaseShaderGUI.FindProperty("_Smoothness", properties, false);
                smoothnessMapChannel = BaseShaderGUI.FindProperty("_SmoothnessTextureChannel", properties, false);
                bumpMapProp = BaseShaderGUI.FindProperty("_BumpMap", properties, false);
                bumpScaleProp = BaseShaderGUI.FindProperty("_BumpScale", properties, false);
                occlusionStrength = BaseShaderGUI.FindProperty("_OcclusionStrength", properties, false);
                occlusionMap = BaseShaderGUI.FindProperty("_OcclusionMap", properties, false);
                // Advanced Props
                highlights = BaseShaderGUI.FindProperty("_SpecularHighlights", properties, false);
                reflections = BaseShaderGUI.FindProperty("_EnvironmentReflections", properties, false);
                //
            }

        }

        public static void Inputs(LitStandardProperties properties, MaterialEditor materialEditor, Material material)
        {
            EditorGUI.BeginChangeCheck();
            var LightModeToggleIndex = (int)properties.LightModeToggle.floatValue;
            LightModeToggleIndex = EditorGUILayout.Popup(Styles.LightModeTip, LightModeToggleIndex, Styles.LightModeToggleText);
            if (EditorGUI.EndChangeCheck())
                properties.LightModeToggle.floatValue = LightModeToggleIndex;

            if ((LightMode)LightModeToggleIndex == LightMode.Classic_Lighting)
            {
                var hasAlbedoMap = properties.AlbedoMap.textureValue != null;
                materialEditor.TexturePropertySingleLine(
                    hasAlbedoMap ? Styles.AlbedoMapTip : Styles.AlbedoTip,
                    properties.AlbedoMap,
                    properties.Albedo
                );

                materialEditor.TexturePropertySingleLine(
                    Styles.SpecularMapTip,
                    properties.SpecularMap,
                    properties.Gloss
                );

                materialEditor.TexturePropertySingleLine(
                    Styles.NormalMapTip,
                    properties.NormalMap,
                    properties.NormalScale
                );
                materialEditor.TexturePropertySingleLine(Styles.EmissionMapTip, properties.EmissionMap);
            }


            if ((LightMode)LightModeToggleIndex == LightMode.PBR)
            {
                var hasAlbedoMap = properties.AlbedoMap.textureValue != null;
                materialEditor.TexturePropertySingleLine(
                    hasAlbedoMap ? Styles.AlbedoMapTip : Styles.AlbedoTip,
                    properties.AlbedoMap,
                    properties.Albedo
                );
                DoMetallicSpecularArea(properties, materialEditor, material);
                BaseShaderGUI.DrawNormalArea(materialEditor, properties.bumpMapProp, properties.bumpScaleProp);

                if (properties.occlusionMap != null)
                {
                    materialEditor.TexturePropertySingleLine(Styles.occlusionText, properties.occlusionMap,
                        properties.occlusionMap.textureValue != null ? properties.occlusionStrength : null);
                }
            }
        }

        public static void DoMetallicSpecularArea(LitStandardProperties properties, MaterialEditor materialEditor, Material material)
        {
            string[] smoothnessChannelNames;
            bool hasGlossMap = false;
            if (properties.workflowMode == null ||
                (WorkflowMode)properties.workflowMode.floatValue == WorkflowMode.Metallic)
            {
                hasGlossMap = properties.metallicGlossMap.textureValue != null;
                smoothnessChannelNames = Styles.metallicSmoothnessChannelNames;
                materialEditor.TexturePropertySingleLine(Styles.metallicMapText, properties.metallicGlossMap,
                    hasGlossMap ? null : properties.metallic);
            }
            else
            {
                hasGlossMap = properties.specGlossMap.textureValue != null;
                smoothnessChannelNames = Styles.specularSmoothnessChannelNames;
                BaseShaderGUI.TextureColorProps(materialEditor, Styles.specularMapText, properties.specGlossMap,
                    hasGlossMap ? null : properties.specColor);
            }
            EditorGUI.indentLevel++;
            DoSmoothness(properties, material, smoothnessChannelNames);
            EditorGUI.indentLevel--;
        }

        public static void DoSmoothness(LitStandardProperties properties, Material material, string[] smoothnessChannelNames)
        {
            var opaque = ((BaseShaderGUI.SurfaceType)material.GetFloat("_Surface") ==
                          BaseShaderGUI.SurfaceType.Opaque);
            EditorGUI.indentLevel++;
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = properties.smoothness.hasMixedValue;
            var smoothness = EditorGUILayout.Slider(Styles.smoothnessText, properties.smoothness.floatValue, 0f, 1f);
            if (EditorGUI.EndChangeCheck())
                properties.smoothness.floatValue = smoothness;
            EditorGUI.showMixedValue = false;

            if (properties.smoothnessMapChannel != null) // smoothness channel
            {
                EditorGUI.indentLevel++;
                EditorGUI.BeginDisabledGroup(!opaque);
                EditorGUI.BeginChangeCheck();
                EditorGUI.showMixedValue = properties.smoothnessMapChannel.hasMixedValue;
                var smoothnessSource = (int)properties.smoothnessMapChannel.floatValue;
                if (opaque)
                    smoothnessSource = EditorGUILayout.Popup(Styles.smoothnessMapChannelText, smoothnessSource,
                        smoothnessChannelNames);
                else
                    EditorGUILayout.Popup(Styles.smoothnessMapChannelText, 0, smoothnessChannelNames);
                if (EditorGUI.EndChangeCheck())
                    properties.smoothnessMapChannel.floatValue = smoothnessSource;
                EditorGUI.showMixedValue = false;
                EditorGUI.EndDisabledGroup();
                EditorGUI.indentLevel--;
            }
            EditorGUI.indentLevel--;
        }

        public static SmoothnessMapChannel GetSmoothnessMapChannel(Material material)
        {
            int ch = (int)material.GetFloat("_SmoothnessTextureChannel");
            if (ch == (int)SmoothnessMapChannel.AlbedoAlpha)
                return SmoothnessMapChannel.AlbedoAlpha;

            return SmoothnessMapChannel.SpecularMetallicAlpha;
        }

        public static void SetMaterialKeywords(Material material)
        {
            // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
            // (MaterialProperty value might come from renderer material property block)
            var hasGlossMap = false;
            var isSpecularWorkFlow = false;
            var opaque = ((BaseShaderGUI.SurfaceType)material.GetFloat("_Surface") ==
                          BaseShaderGUI.SurfaceType.Opaque);

            if (material.HasProperty("_LightMode"))
            {
                LightMode lightModeType = (LightMode)material.GetInt("_LightMode");
                CoreUtils.SetKeyword(material, "_LightMode_Classic_Lighting", lightModeType==LightMode.Classic_Lighting);
                CoreUtils.SetKeyword(material, "_LightMode_PBR", lightModeType==LightMode.PBR);
            }

            var hasSpecularMap = material.GetTexture("_SpecularTexture") != null;
            CoreUtils.SetKeyword(material, "_SPECULARMAP",hasSpecularMap);

            if (material.HasProperty("_WorkflowMode"))
            {
                isSpecularWorkFlow = (WorkflowMode)material.GetFloat("_WorkflowMode") == WorkflowMode.Specular;
                if (isSpecularWorkFlow)
                    hasGlossMap = material.GetTexture("_SpecGlossMap") != null;
                else
                    hasGlossMap = material.GetTexture("_MetallicGlossMap") != null;
            }
            else
            {
                hasGlossMap = material.GetTexture("_MetallicGlossMap") != null;
            }

            CoreUtils.SetKeyword(material, "_SPECULAR_SETUP", isSpecularWorkFlow);

            CoreUtils.SetKeyword(material, "_METALLICSPECGLOSSMAP", hasGlossMap);

            if (material.HasProperty("_SpecularHighlights"))
                CoreUtils.SetKeyword(material, "_SPECULARHIGHLIGHTS_OFF",
                    material.GetFloat("_SpecularHighlights") == 0.0f);
            if (material.HasProperty("_EnvironmentReflections"))
                CoreUtils.SetKeyword(material, "_ENVIRONMENTREFLECTIONS_OFF",
                    material.GetFloat("_EnvironmentReflections") == 0.0f);
            if (material.HasProperty("_OcclusionMap"))
                CoreUtils.SetKeyword(material, "_OCCLUSIONMAP", material.GetTexture("_OcclusionMap"));

            if (material.HasProperty("_SmoothnessTextureChannel"))
            {
                CoreUtils.SetKeyword(material, "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A",
                    GetSmoothnessMapChannel(material) == SmoothnessMapChannel.AlbedoAlpha && opaque);
            }
        }

    }
}
