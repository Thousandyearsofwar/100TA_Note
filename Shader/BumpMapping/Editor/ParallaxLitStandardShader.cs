using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    public static class ParallaxStyles
    {
        public static readonly GUIContent ParallaxInputs = new GUIContent("Custom Inputs", "自定义输入");

    }
    public class ParallaxLitStandardShader : LitStandardShader
    {
        public static bool m_ParallaxFoldout = true;

        private ParallaxLitStandardGUI.ParallaxProperties parallaxProperties;

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            parallaxProperties = new ParallaxLitStandardGUI.ParallaxProperties(properties);
        }

        public override void MaterialChanged(Material material)
        {
            if (material == null)
                Debug.LogError("AnisotropicMat is miss!");
            SetMaterialKeywords(material, LitStandardGUI.SetMaterialKeywords);
        }

        public override void DrawSurfaceOptions(Material material)
        {
            //SurfaceType, RenderType, Alpha Clipping ,ReceiveShadow
            base.DrawSurfaceOptions(material);
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
        }

        public override void DrawAdditionalFoldouts(Material material)
        {
            m_ParallaxFoldout = EditorGUILayout.BeginFoldoutHeaderGroup(m_ParallaxFoldout, ParallaxStyles.ParallaxInputs);
            if (m_ParallaxFoldout)
            {
                ParallaxLitStandardGUI.Inputs(parallaxProperties, materialEditor, material);
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