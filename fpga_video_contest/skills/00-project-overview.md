# 项目总览：双板异构实时视频增强与轻量 CNN 加速终端

## 1. 项目目标
基于 Zynq7020-F 和 KU5P-F 双板，实现 1280x720@30fps 的实时视频采集、双板以太网协同传输、KU5P 侧 CLAHE 与轻量 CNN 加速增强、Zynq 侧 PIP 画中画显示与 PC 上位机指标统计。

## 2. 硬件分工
- **Zynq7020-F (主控/显示)**：MIPI 采集、基础 ISP、千兆以太网 UDP 发送、接收 KU5P ROI、HDMI PIP 叠加显示、OSD 状态信息。
- **KU5P-F (算力加速)**：千兆以太网 UDP 接收、DDR4 帧缓存、CLAHE 算法、3层轻量 CNN 残差增强、ROI 截取与回传。
- **PC (上位机/Agent)**：接收完整增强帧、计算 PSNR/帧率、运行 LLM Agent 解析 HLS 报告并优化 Pragma。

## 3. 核心数据流
MIPI Sensor -> Zynq PL ISP -> Zynq ETH TX -> (GigE UDP) -> KU5P ETH RX -> KU5P DDR4 -> KU5P HLS Accel -> KU5P ETH TX -> (GigE UDP) -> Zynq ETH RX -> Zynq PIP BRAM -> HDMI TX.