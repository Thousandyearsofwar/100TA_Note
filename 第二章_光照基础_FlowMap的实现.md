# 光照基础
+ ## 颜色空间
+ ## 模型与材质
+ ## 基础语法介绍
+ ## 传统经验光照模型
+ ## Bump Map的改进
+ ## 伽马矫正
+ ## LDR与HDR
+ ## FlowMap的实现
  + ### FlowMap是什么
    + FlowMap
      + 一张记录了2D向量信息的纹理
      + FlowMap上的颜色信息(RG通道)记录该处向量场的方向，让模型上某一点表现出定量流动的特征。
      + 通过在shader中偏移UV再对纹理进行采样，来模拟流动效果。
      ![图 1](https://i.loli.net/2021/07/04/u8SjPmiGVrlTvW5.png)  
      ![图 2](https://i.loli.net/2021/07/04/Roz8iDUVlsvjB9m.png)
      ps:图形API不一致，UV坐标V轴方向相反。
    + 为什么要使用FlowMap
      + 类似于UV动画非顶点动画，仅在Fragment Shader中运算容易实现，运算开销小。
      + 任何流动效果都能使用FlowMap进行模拟[GDC14 顽皮狗流动SkyBoxShader]
      ![图 3](https://i.loli.net/2021/07/04/fvoulXR9kbxPpjN.png)  
  + ### FlowMap Shader
    + 要点：
      + 采样FlowMap获取向量场信息
      + 用向量场信息，使采样贴图时的UV随时间变换
      + 对同一贴图以半个周期的相位差采样两次，并予以线性插值，使得贴图流动连续。
    + issue
      + 流动方向的获取
        + 由于FlowMap的颜色值在[0,1]范围内，需要Remap到[-1,1]
          + float3 flowDir=SAMPLE_TEXTURE2D(flowmap,Sampler_flowMap,input.uv)*2-1;
      + 周期性变化
        +  float phase=frac(_Time);
      + frac带来跳变的解决
        + 使用相位相差半个周期的两个函数做插值混合
          + float phase0=frac(_Time* 0.1*_TimeSpeed);
          + float phase1=frac(_Time* 0.1*_TimeSpeed+0.5); 
          + float t=abs(phase0*2-1);
          + float4 SampleRes0=SAMPLE_XXX...(xxx,uv-flowDir.xy*phase0)
          + float4 SampleRes1=SAMPLE_XXX...(xxx,uv-flowDir.xy*phase1)
          + float4 res=lerp(SampleRes0,SampleRes1,t);
  + ### FlowMap的制作
    + Flowmap Painter
    + Houdini Labs
      + Flow Map相关节点
      FlowMap:使用法线,梯度,方向生成FlowMap</br>
      ![图 2](https://i.loli.net/2021/07/17/Vy2WN8R17cgkIBh.png)  
      FlowMap Visualize:FlowMap可视化</br>
      ![图 3](https://i.loli.net/2021/07/17/2WTQIfSiZmy95lr.png)  
      Guide FlowMap:使用曲线引导FlowMap</br>
      strength:影响力度</br>
      EffectWidth:影响宽度</br>
      FallOff:衰减</br>
      GuideSampleCount：曲线采样次数</br>
      ![图 4](https://i.loli.net/2021/07/17/krI9igzpd61GyB8.png) 
      Flowmap obstacle:根据模型对flowmap流动产生阻挡效果
      Strength:阻挡力度大小</br>
      DivisionSize:模型导入后转换成体素的大小</br>
      DilateVolume:转换成体素之后外扩程度，大于零往外扩，小于零往里缩</br>
      BlurStrength:模糊程度大小</br>
      ![图 5](https://i.loli.net/2021/07/17/5LnKFw18ORPiHlM.png)  
      Flowmap to color</br>
      Flip Green Channel 错误不用管</br>
      ![图 6](https://i.loli.net/2021/07/17/NFsg7LZAYyUCIqR.png)  
      Maps baker:贴图烘焙</br>
      ![图 7](https://i.loli.net/2021/07/18/WNIM71nuATQVOEh.png)  
  + ### FlowMap Skybox
    ![图 1](https://i.loli.net/2021/07/17/Gtf8VCxo7uSZT3I.png)  
    https://github.com/Thousandyearsofwar/100TA_Note/blob/main/Shader/FlowMap/SkyBoxShader/SkyBox_FlowMap.shader
+ ## 待续