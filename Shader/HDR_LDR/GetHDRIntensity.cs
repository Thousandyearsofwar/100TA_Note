using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
 
public class GetHDRIntensity : MonoBehaviour
{
    [ColorUsage(true, true)]
    public Color color;
 
    private void Start()
    {
        Color32 color32;
        float exp;
        DecomposeHdrColor(color, out color32, out exp);
        Debug.Log(exp);
    }
 
    private const byte k_MaxByteForOverexposedColor = 191;
    public static void DecomposeHdrColor(Color linearColorHdr, out Color32 baseLinearColor, out float exposure)
    {
        baseLinearColor = linearColorHdr;
        var maxColorComponent = linearColorHdr.maxColorComponent;
        // replicate Photoshops's decomposition behaviour
        if (maxColorComponent == 0f || maxColorComponent <= 1f && maxColorComponent >= 1 / 255f)
        {
            exposure = 0f;
            baseLinearColor.r = (byte)Mathf.RoundToInt(linearColorHdr.r * 255f);
            baseLinearColor.g = (byte)Mathf.RoundToInt(linearColorHdr.g * 255f);
            baseLinearColor.b = (byte)Mathf.RoundToInt(linearColorHdr.b * 255f);
        }
        else
        {
            // calibrate exposure to the max float color component
            var scaleFactor = k_MaxByteForOverexposedColor / maxColorComponent;
            exposure = Mathf.Log(255f / scaleFactor) / Mathf.Log(2f);
            // maintain maximal integrity of byte values to prevent off-by-one errors when scaling up a color one component at a time
            baseLinearColor.r = Math.Min(k_MaxByteForOverexposedColor, (byte)Mathf.CeilToInt(scaleFactor * linearColorHdr.r));
            baseLinearColor.g = Math.Min(k_MaxByteForOverexposedColor, (byte)Mathf.CeilToInt(scaleFactor * linearColorHdr.g));
            baseLinearColor.b = Math.Min(k_MaxByteForOverexposedColor, (byte)Mathf.CeilToInt(scaleFactor * linearColorHdr.b));
        }
    }
}