# 基础夯实

+ ## 数学基础

  + <font size=4>**1.向量运算**</font>
  + <font size=4>**2.矩阵运算**</font>
  + <font size=4>**3.MVP矩阵推导**</font>
    + MVP矩阵代表：Model，View，Projection三个矩阵，将模型的顶点坐标通过这三个矩阵转换到
    世界空间，观察空间，裁剪空间，最后经过视口变换[ViewPortTransform]变成屏幕空间坐标
    + M矩阵：
      + 模型空间=>世界空间
        3dmax右手坐标系
        U3d左手坐标系
        M矩阵：$Transform*Rotate_y*Rotate_x*Rotate_z*Scale$
    + V矩阵：
      + 世界空间=>观察空间
        求View矩阵过程:
        第一种思路：
          计算观察空间的三个坐标轴在世界空间中的表示，构建出世界空间到观察空间的变换矩阵
          思路跟LearnOpengl中的LookAt矩阵构建一样
          [http://learnopengl.com/#!Getting-started/Camera]
          $M_{W\rightarrow V}=
          \begin{bmatrix}
          1&0&0&0\\
          0&1&0&0\\
          0&0&-1&0\\
          0&0&0&1\\
          \end{bmatrix}
          *
          \begin{bmatrix}
          -&x_v[世界空间]&-&0\\
          -&y_v[世界空间]&-&0\\
          -&z_v[世界空间]&-&0\\
          0&0&0&1\\
          \end{bmatrix}
          *
          \begin{bmatrix}
          1&0&0&-p_x\\
          0&1&0&-p_y\\
          0&0&1&-p_z\\
          0&0&0&1\\
          \end{bmatrix}
          $
        第二种思路
        平移整个观察空间，使得摄像机的原点回归到世界坐标系的原点，旋转坐标轴与世界坐标轴重合
        **使用的是右手坐标系，摄像机的正前方指的是-z方向,所以Z分量需要取反**
    + P矩阵：
      + 观察空间=>裁剪空间
      + 目的：判断顶点是否在可见范围内
      对x,y,z分量进行缩放，用w分量做范围值。如果x,y,z都在w范围之内，那么该点在裁剪空间内
      + 投影方式：正交投影，透视投影
      + 透视投影参数：Near，Far，FOV，Aspect
      $nearClipPlaneHeight=2 \cdot Near \cdot tan(\frac{FOV}{2}) $
      $farClipPlaneHeight=2 \cdot Far \cdot tan(\frac{FOV}{2}) $
      $FOV=FieldOfView$
      $Aspect=\frac{nearClipPlaneWidth}{nearClipPlaneHeight}/\frac{farClipPlaneWidth}{farClipPlaneHeight}$
        + P矩阵：
          $\begin{bmatrix}
          \frac{cot{\frac{FOV}{2}}}{Aspect}&0&0&0\\
          0&cot{\frac{FOV}{2}}&0&0\\
          0&0&\frac{Far+Near}{Far-Near}&\frac{-2NearFar}{Far-Near}\\
          0&0&-1&0\\
          \end{bmatrix}$
      + 正交投影参数：Near，Far，Size
        $size=视锥体的高度的一半$
        $nearClipPlaneHeight=2 Size $
        $farClipPlaneHeight=nearClipPlaneHeight $
        $nearClipPlaneWidth=Aspect \cdot nearClipPlaneHeight $
        $farClipPlaneWidth= nearClipPlaneWidth $
        + P矩阵：
          $\begin{bmatrix}
          \frac{1}{Aspect \cdot Size}&0&0&0\\
          0&\frac{1}{Size}&0&0\\
          0&0&-\frac{2}{Far-Near}&-\frac{Far+Near}{Far-Near}\\
          0&0&0&1\\
          \end{bmatrix}$
  + <font size=4>**4.傅里叶变换**</font>
  + <font size=4>**5.其他**</font>

[1]:https://learnopengl-cn.github.io/01%20Getting%20started/09%20Camera
