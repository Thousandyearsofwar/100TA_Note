using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    public static class FlowMapGUI
    {
        public static class Styles
        {
            //@@@Flow Map
            public static GUIContent FlowMapTip = new GUIContent("Flow Map", "flow map");
            public static GUIContent FlowSpeedTip= new GUIContent("Time Speed","时间速度");
        }

        public struct FlowMapProperties
        {

            public MaterialProperty FlowMap;
            public MaterialProperty FlowSpeed;
            //

            public FlowMapProperties(MaterialProperty[] properties)
            {
                this.FlowMap = BaseShaderGUI.FindProperty("_FlowMap", properties, false);
                this.FlowSpeed=BaseShaderGUI.FindProperty("_TimeSpeed",properties,false);
            }

        }

        public static void Inputs(FlowMapProperties properties, MaterialEditor materialEditor, Material material)
        {
            materialEditor.TexturePropertySingleLine( Styles.FlowMapTip ,properties.FlowMap);
            materialEditor.ShaderProperty(properties.FlowSpeed,Styles.FlowSpeedTip); 
        }

        public static void SetMaterialKeywords(Material material)
        {

        }

    }
}
