# 基于 FPGA 的多声部触控数字钢琴系统

本项目以 Tang Mega 60K FPGA 和 LT7689 7 英寸串口触控屏为核心，实现触控琴键输入、24 音映射、DDS 音源、包络与谐波合成、多声部和弦混音、限幅滤波、I2S 音频输出和状态灯控制。

## 硬件与开发环境

- FPGA：Tang Mega 60K（GW5AT-LV60PG484AC1/I0）
- FPGA 工具：Gowin EDA Education V1.9.11.03
- 触控屏：LT7689 7 英寸串口屏，800×480
- 界面工具：UI Editor II V2.00
- 串口：115200 bit/s，8-N-1

## 目录结构

- `FPGA工程/audio440.gprj`：Gowin EDA 工程入口
- `FPGA工程/src`：Verilog 源码和 CST 引脚约束
- `FPGA工程/生成文件/audio440.fs`：已验证的 FPGA 位流
- `FPGA工程/生成文件/audio440.rpt.txt`：布局布线报告
- `FPGA工程/生成文件/audio440.pin.html`：引脚报告
- `触控屏工程`：UI Editor II 工程、界面素材和烧录文件
- `触控屏工程/UartTFT-II_Flash.bin`：串口屏界面烧录文件

## FPGA 数据通路

触控屏通过 UART 发送琴键和模式事件。FPGA 完成串口帧解析与音符映射，使用相位累加器和正弦查找表生成波形，再进行包络、谐波、和弦混音、平滑滤波和饱和限幅，最后通过 I2S 接口输出至板载音频电路。

## 使用方法

1. 使用 Gowin EDA 打开 `FPGA工程/audio440.gprj`。
2. 选择器件 `GW5AT-LV60PG484AC1/I0`，执行综合、布局布线并生成码流。
3. 调试时可以直接使用 `FPGA工程/生成文件/audio440.fs` 下载至 FPGA。
4. 使用 UI Editor II V2.00 打开触控屏工程并编译，生成 `UartTFT-II_Flash.bin` 后写入串口屏。

