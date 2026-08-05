# 硬件平台约束

## 1. Zynq7020-F (XC7Z020-CLG484-2)
- **PL 时钟**：50MHz 有源晶振。需通过 MMCM 生成 74.25MHz (720p30 像素时钟)、125MHz (RGMII)、200MHz (逻辑)。
- **HDMI OUT**：直连 PL 差分 IO，实现 DVI 数字视频输出，最高 1080p60。本项目使用 720p30。
- **MIPI**：2-lane CSI-2 接口，接 OV5641/AN5641。
- **PL ETH**：RTL8211F-CG PHY，RGMII 接口，125MHz 时钟。
- **DDR3**：1GB，32-bit，接 PS 端，本项目 PL 主要用 BRAM 做行缓存和 PIP 帧缓存。

## 2. KU5P-F (XCKU5P-2FFVB676I)
- **PL 时钟**：200MHz 差分晶振。
- **DDR4**：2GB (2片 MT40A512M16LY)，32-bit，最高 2666Mbps。使用 MIG 生成 AXI4 接口。
- **ETH**：RTL8211F-CG PHY，RGMII 接口。默认 IP 192.168.1.10。
- **无 PS 端**：纯 FPGA，所有控制通过以太网 UDP 或 JTAG/ILA 完成。