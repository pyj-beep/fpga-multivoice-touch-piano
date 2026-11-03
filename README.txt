基于 FPGA 的多声部触控数字钢琴系统

一、目录说明

1. FPGA工程
   - audio440.gprj：Gowin EDA 工程文件
   - src：Verilog 源码及引脚约束文件
   - 生成文件/audio440.fs：已验证可用的 FPGA 位流文件
   - 生成文件/audio440.rpt.txt：布局布线资源报告
   - 生成文件/audio440.pin.html：引脚报告

2. 触控屏工程
   - PianoScreen_2OctModes：双音区触控钢琴界面工程
   - UartTFT-II_Flash.bin：串口屏界面烧录文件
   - PianoScreen.uiprj、PianoScreen_full.uiprj：UI Editor II 工程入口

二、开发环境

- FPGA：Tang Mega 60K，GW5AT-60B
- FPGA 工具：Gowin EDA Education V1.9.11.03
- 触控屏：LT7689 7 英寸串口屏，800×480
- 界面工具：UI Editor II V2.00
- 串口通信：115200 bit/s，8-N-1

三、使用说明

使用 Gowin EDA 打开 FPGA工程/audio440.gprj，可重新综合和布局布线。
调试时可使用 FPGA工程/生成文件/audio440.fs 下载至 FPGA SRAM。
触控屏界面工程由 UI Editor II 打开并编译，生成 UartTFT-II_Flash.bin 后写入屏幕。

工程包含 UART 触控事件解析、24 音映射、DDS 音源、包络、和弦混音、限幅滤波、I2S 音频输出及状态灯控制模块。
