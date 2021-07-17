using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    public class FlowMapLitStandardShader : LitStandardShader
    {
        public static bool m_CustomFoldout = true;
        private ParallaxLitStandardGUI.ParallaxProperties parallaxProperties;
        private FlowMapGUI.FlowMapProperties flowMapProperties;

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            parallaxProperties = new ParallaxLitStandardGUI.ParallaxProperties(properties);
            flowMapProperties = new FlowMapGUI.FlowMapProperties(properties);
        }

        public override void MaterialChanged(Material material)
        {
            if (material == null)
                Debug.LogError("AnisotropicMat is miss!");
            SetMaterialKeywords(material, LitStandardGUI.SetMaterialKeywords);
        }

        public override void DrawSurfaceOptions(Material material)
        {
            base.DrawSurfaceOptions(material);
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
        }

        public override void DrawAdditionalFoldouts(Material material)
        {
            m_CustomFoldout = EditorGUILayout.BeginFoldoutHeaderGroup(m_CustomFoldout, ParallaxStyles.ParallaxInputs);
            if (m_CustomFoldout)
            {
                ParallaxLitStandardGUI.Inputs(parallaxProperties, materialEditor, material);
                EditorGUILayout.Space();
                FlowMapGUI.Inputs(flowMapProperties, materialEditor, material);
                EditorGUILayout.Space();
            }
            EditorGUILayout.EndFoldoutHeaderGroup();
        }

        public override void DrawAdvancedOptions(Material material)
        {
            base.DrawAdvancedOptions(material);
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            base.AssignNewShaderToMaterial(material, oldShader, newShader);
        }
    }
}