下面重写一次，统一采用：

$$
\boxed{\theta = \text{azimuth 方位角}}
$$

$$
\boxed{\phi = \text{elevation 俯仰角}}
$$

其中阵列在 $x$-$y$ 平面，boresight 指向 $+z$ 方向。

---

## 1. 阵列几何

考虑一个 $M_x \times M_y$ 的 uniform rectangular array, URA。

第 $(m,n)$ 个阵元的位置是

$$
\mathbf r_{m,n} =
\begin{bmatrix}
m d_x \\
n d_y \\
0
\end{bmatrix},
\qquad
m=0,\dots,M_x-1,
\quad
n=0,\dots,M_y-1.
$$

目标方向由 azimuth $\theta$ 和 elevation $\phi$ 描述。

方向单位向量为

$$
\mathbf u(\theta,\phi) =
\begin{bmatrix}
\cos\phi\cos\theta \\
\cos\phi\sin\theta \\
\sin\phi
\end{bmatrix}.
$$

这里：

$$
\theta = 0
$$

表示目标在 $+x$ 方向的垂直平面内；

$$
\theta = 90^\circ
$$

表示目标在 $+y$ 方向的垂直平面内；

$$
\phi = 0
$$

表示目标在阵列平面方向，也就是 horizon；

$$
\phi = 90^\circ
$$

表示目标正对 boresight，也就是 $+z$ 方向。

---

## 2. Direction cosines

定义两个 direction cosines：

$$
\xi = \cos\phi\cos\theta,
$$

$$
\eta = \cos\phi\sin\theta.
$$

因为阵列只分布在 $x$-$y$ 平面，所以空间相位只和 $\mathbf u$ 在 $x$-$y$ 平面的投影有关。

第 $(m,n)$ 个阵元相对参考阵元的 path difference 是

$$
\mathbf r_{m,n}^T \mathbf u
=
m d_x \cos\phi\cos\theta
+
n d_y \cos\phi\sin\theta.
$$

因此 steering response 是

$$
a_{m,n}(\theta,\phi)
=
\exp\left[
j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi\cos\theta
+
n d_y \cos\phi\sin\theta
\right)
\right].
$$

等价地，

$$
a_{m,n}(\theta,\phi)
=
\exp\left[
j\frac{2\pi}{\lambda}
\left(
m d_x \xi
+
n d_y \eta
\right)
\right].
$$

---

## 3. 2D steering vector

沿 $x$ 方向的 steering vector 是

$$
\mathbf a_x(\theta,\phi)
=
\begin{bmatrix}
1 \\
e^{j\frac{2\pi}{\lambda}d_x\cos\phi\cos\theta} \\
\vdots \\
e^{j\frac{2\pi}{\lambda}(M_x-1)d_x\cos\phi\cos\theta}
\end{bmatrix}.
$$

沿 $y$ 方向的 steering vector 是

$$
\mathbf a_y(\theta,\phi)
=
\begin{bmatrix}
1 \\
e^{j\frac{2\pi}{\lambda}d_y\cos\phi\sin\theta} \\
\vdots \\
e^{j\frac{2\pi}{\lambda}(M_y-1)d_y\cos\phi\sin\theta}
\end{bmatrix}.
$$

整个 URA 的 steering vector 可以写成 Kronecker product：

$$
\mathbf a(\theta,\phi)
=
\mathbf a_y(\theta,\phi)
\otimes
\mathbf a_x(\theta,\phi).
$$

注意这里 stack 顺序取决于你怎么把二维阵列 reshape 成一维向量。如果你先 stack $x$ 再 stack $y$，就用上面这个形式；如果顺序反过来，Kronecker product 的顺序也要反过来。

---

## 4. 单目标 continuous-time received signal

假设雷达发射 baseband waveform $s(t)$，载频为 $f_c$，波长为

$$
\lambda = \frac{c}{f_c}.
$$

一个目标的参数是

$$
(R, v, \theta, \phi, \alpha),
$$

其中

$$
R = \text{range},
$$

$$
v = \text{radial velocity},
$$

$$
\theta = \text{azimuth},
$$

$$
\phi = \text{elevation},
$$

$$
\alpha = \text{complex target reflectivity}.
$$

Round-trip delay 是

$$
\tau = \frac{2R}{c}.
$$

Doppler frequency 是

$$
f_D = \frac{2v}{\lambda}.
$$

第 $p$ 个 pulse 的 slow-time 是

$$
t_p = pT_{\mathrm{PRI}}.
$$

那么第 $(m,n)$ 个接收阵元上的 baseband echo 可以写成

$$
x_{m,n,p}(t)
=
\alpha
s(t-\tau)
e^{j2\pi f_D pT_{\mathrm{PRI}}}
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi\cos\theta
+
n d_y \cos\phi\sin\theta
\right)}
+
w_{m,n,p}(t).
$$

这就是最核心的 2D phased array radar model。

三个相位结构分别是：

$$
\boxed{
s(t-\tau)
}
$$

对应 range；

$$
\boxed{
e^{j2\pi f_D pT_{\mathrm{PRI}}}
}
$$

对应 Doppler；

$$
\boxed{
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi\cos\theta
+
n d_y \cos\phi\sin\theta
\right)}
}
$$

对应 2D angle。

---

## 5. 多目标模型

对 $Q$ 个目标，有

$$
x_{m,n,p}(t)
=
\sum_{q=1}^{Q}
\alpha_q
s(t-\tau_q)
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi_q\cos\theta_q
+
n d_y \cos\phi_q\sin\theta_q
\right)}
+
w_{m,n,p}(t).
$$

其中

$$
\tau_q = \frac{2R_q}{c},
$$

$$
f_{D,q} = \frac{2v_q}{\lambda}.
$$

也可以写成 direction-cosine 形式：

$$
\xi_q = \cos\phi_q\cos\theta_q,
$$

$$
\eta_q = \cos\phi_q\sin\theta_q.
$$

于是

$$
x_{m,n,p}(t)
=
\sum_{q=1}^{Q}
\alpha_q
s(t-\tau_q)
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \xi_q
+
n d_y \eta_q
\right)}
+
w_{m,n,p}(t).
$$

---

## 6. Matched filter 后的离散模型

经过 matched filtering 和 range sampling 后，令 range bin index 为 $k$，则

$$
x_{m,n,p,k}
=
\sum_{q=1}^{Q}
\alpha_q
h[k-k_q]
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi_q\cos\theta_q
+
n d_y \cos\phi_q\sin\theta_q
\right)}
+
w_{m,n,p,k}.
$$

这里

$$
h[k-k_q]
$$

是 range matched-filter response，

$$
k_q \approx \frac{2R_q}{cT_s}
$$

是目标对应的 range bin。

如果目标刚好落在某个 range bin，可以简化成

$$
x_{m,n,p,k}
=
\sum_{q\in\mathcal Q_k}
\alpha_q
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi_q\cos\theta_q
+
n d_y \cos\phi_q\sin\theta_q
\right)}
+
w_{m,n,p,k}.
$$

---

## 7. 向量形式

把所有阵元 stack 成一个向量：

$$
\mathbf x_{p,k}
\in
\mathbb C^{M_xM_y}.
$$

则

$$
\mathbf x_{p,k}
=
\sum_{q=1}^{Q}
\alpha_q
h[k-k_q]
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
\mathbf a(\theta_q,\phi_q)
+
\mathbf w_{p,k}.
$$

其中

$$
\mathbf a(\theta_q,\phi_q)
$$

就是 2D URA steering vector。

---

## 8. Space-time model

定义 Doppler steering vector：

$$
\mathbf b(f_D)
=
\begin{bmatrix}
1 \\
e^{j2\pi f_DT_{\mathrm{PRI}}} \\
\vdots \\
e^{j2\pi f_D(P-1)T_{\mathrm{PRI}}}
\end{bmatrix}.
$$

把所有 pulses stack 起来，可以得到

$$
\mathbf X_k
=
\sum_{q=1}^{Q}
\alpha_q
h[k-k_q]
\mathbf a(\theta_q,\phi_q)
\mathbf b^T(f_{D,q})
+
\mathbf W_k.
$$

所以每个 point target 在某个 range bin 里，对应一个 rank-1 space-time component：

$$
\mathbf a(\theta_q,\phi_q)
\mathbf b^T(f_{D,q}).
$$

---

## 9. 加入 transmit phased-array beamforming

如果发射端也用 2D phased array，并使用 transmit beamforming vector

$$
\mathbf w_T,
$$

那么目标方向上的 transmit gain 是

$$
G_T(\theta,\phi)
=
\mathbf w_T^H
\mathbf a_T(\theta,\phi).
$$

接收模型变成

$$
\mathbf x_{p,k}
=
\sum_{q=1}^{Q}
\alpha_q
G_T(\theta_q,\phi_q)
h[k-k_q]
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
\mathbf a_R(\theta_q,\phi_q)
+
\mathbf w_{p,k}.
$$

其中

$$
\mathbf a_T(\theta,\phi)
$$

是 transmit steering vector，

$$
\mathbf a_R(\theta,\phi)
$$

是 receive steering vector。

如果 transmit 和 receive 使用同一个 URA，则通常

$$
\mathbf a_T(\theta,\phi)
=
\mathbf a_R(\theta,\phi)
=
\mathbf a(\theta,\phi).
$$

---

## 10. Tensor data-cube model

完整的 radar data cube 可以写成

$$
x[m,n,p,k].
$$

其中：

$$
m = \text{x-array index},
$$

$$
n = \text{y-array index},
$$

$$
p = \text{pulse / slow-time index},
$$

$$
k = \text{range-bin index}.
$$

模型是

$$
x[m,n,p,k]
=
\sum_{q=1}^{Q}
\alpha_q
h[k-k_q]
e^{j2\pi f_{D,q}pT_{\mathrm{PRI}}}
e^{j\frac{2\pi}{\lambda}
\left(
m d_x \cos\phi_q\cos\theta_q
+
n d_y \cos\phi_q\sin\theta_q
\right)}
+
w[m,n,p,k].
$$

这次的角度定义是：

$$
\boxed{
\theta_q = \text{azimuth 方位角}
}
$$

$$
\boxed{
\phi_q = \text{elevation 俯仰角}
}
$$

所以要估计的目标参数是：

$$
\boxed{
(R_q, v_q, \theta_q, \phi_q, \alpha_q)
}
$$

也就是：

$$
\boxed{
\text{range, radial velocity, azimuth, elevation, complex reflectivity}
}
$$

一个很重要的直觉是：URA 实际测的是两个 spatial frequencies：

$$
\omega_x
=
\frac{2\pi d_x}{\lambda}
\cos\phi\cos\theta,
$$

$$
\omega_y
=
\frac{2\pi d_y}{\lambda}
\cos\phi\sin\theta.
$$

从它们可以反推出 azimuth/elevation：

$$
\theta
=
\operatorname{atan2}(\omega_y/d_y,\omega_x/d_x),
$$

$$
\cos\phi
=
\sqrt{
\left(\frac{\lambda \omega_x}{2\pi d_x}\right)^2
+
\left(\frac{\lambda \omega_y}{2\pi d_y}\right)^2
}.
$$

所以 2D phased array 本质上是在估计目标方向向量在阵列平面上的投影。
