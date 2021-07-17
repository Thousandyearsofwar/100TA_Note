using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GammaCorrectionRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
        public Material material;
        public int matPassIndex = -1;
    }
    public Setting setting = new Setting();

    class GammaCorrectionRenderPass : ScriptableRenderPass
    {
        public Material passMaterial = null;
        public int passMaterialIndex = 0;
        public FilterMode passFilterMode { get; set; }
        public RenderTargetIdentifier passSource { get; set; }
        RenderTargetHandle passTempleColorTex;
        string passTag;

        public GammaCorrectionRenderPass(RenderPassEvent passEvent, Material material, int passMatIndex, string tag) {
            this.renderPassEvent = passEvent;
            this.passMaterial = material;
            this.passMaterialIndex = passMatIndex;
            this.passTag = tag;
        }

        public void setup(RenderTargetIdentifier source) {
            this.passSource = source;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(passTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;

            cmd.GetTemporaryRT(passTempleColorTex.id,opaqueDesc,passFilterMode);
            Blit(cmd, passSource, passTempleColorTex.Identifier(), passMaterial, passMaterialIndex);
            Blit(cmd, passTempleColorTex.Identifier(), passSource);
            context.ExecuteCommandBuffer(cmd);

            CommandBufferPool.Release(cmd);
            cmd.ReleaseTemporaryRT(passTempleColorTex.id);
        }
    }

    GammaCorrectionRenderPass renderPass;

    public override void Create()
    {
        int passCount = setting.material == null ? 1 : setting.material.passCount-1;

        setting.matPassIndex = Mathf.Clamp(setting.matPassIndex,-1,passCount);

        renderPass = new GammaCorrectionRenderPass(setting.passEvent, setting.material, setting.matPassIndex, name);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var src = renderer.cameraColorTarget;
        renderPass.setup(src);
        renderer.EnqueuePass(renderPass);
        
    }

    
}
