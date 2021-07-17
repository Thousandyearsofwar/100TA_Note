using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.Universal.ShaderGUI{
    public static class LitAnisotropicGUI
    {

        public static class Styles{
            public static GUIContent AnisotropicTip=new GUIContent("Anisotropic","各向异性大小");
        }

        public struct LitAnisotropicParameter{
            public MaterialProperty AnisotropicParam;

            public LitAnisotropicParameter(MaterialProperty[]parameters){
                this.AnisotropicParam=BaseShaderGUI.FindProperty("_Anisotropic",parameters,false);
            }

        }
        public static void AnisotropicParameterCheck(LitAnisotropicParameter parameter,MaterialEditor materialEditor){
            materialEditor.ShaderProperty(parameter.AnisotropicParam,Styles.AnisotropicTip);
        }



    }


}
