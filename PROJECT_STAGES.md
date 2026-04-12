# 项目阶段说明

这份文档用于把 `doc/2026集创赛龙芯中科杯初赛.pdf` 中的任务要求，整理成适合实际开发推进的项目阶段说明。

它不是原始赛题手册的替代品，而是给当前仓库配的一份“开工导航”。

## 1. 这个项目本质上要做什么

这个仓库不是普通软件项目，而是一套 LoongArch32R SoC 实验工程。

目标是把实验环境已经提供的这些模块真正拼成一台能工作的“小计算机系统”：

- CPU：`openLA500`
- 总线：`AXI Crossbar`
- 主存：`BaseRAM / ExtRAM`
- 串口：`UART`
- 板级控制外设：`confreg`
- 视频输出：`DVI`

最终让 `sdk/` 中的软件程序能够：

- 在 Vivado 功能仿真中运行
- 在 FPGA 板卡上运行
- 通过串口、按键、数码管、LED、DVI 等外设表现出正确结果

## 2. 赛题原始任务划分

根据 PDF，正式任务分成两个阶段：

### 阶段任务一：搭建基础 SoC

目标：

- 基于实验环境提供的 CPU、AXI、SRAM、UART 搭建基础 SoC
- 完成 Vivado 仿真与 FPGA 验证
- 正确运行 `Hello World`
- 串口输出 `Hello Loongarch32r!`

这一阶段对应 PDF 第 2 章。

### 阶段任务二：外部中断控制器实验之弹球游戏

目标：

- 在基础 SoC 上补充 `confreg` 中的外部中断控制器
- 添加 `DVI` 控制器
- 跑通中断测试程序 `int_test`
- 在 FPGA 上运行 `pinball_game`

这一阶段对应 PDF 第 3 章。

## 3. 结合当前代码状态后的推荐阶段划分

从当前仓库状态看，建议不要直接按“任务一/任务二”两段硬切，而是按下面 3 个阶段推进更稳妥。

### 阶段 0：理解工程与现状对齐

这一阶段不是比赛明确要求，但对当前项目很重要。

原因是当前仓库里的 `soc_top.v` 还没有完成系统集成，而 `sim/mycpu_tb.v` 已经按“完整 SoC”在写。

这一阶段的目标是：

- 理清 `rtl / sim / fpga / sdk` 四部分关系
- 弄清楚 `soc_top.v` 当前缺哪些实例
- 弄清楚测试台默认假定了哪些模块已经存在
- 弄清楚软件依赖了哪些硬件地址和功能

阶段完成标志：

- 能说清楚这个 SoC 应该包含哪些模块
- 能说清楚基础链路先接什么、后接什么
- 能列出 `soc_top.v` 里缺失的关键实例

### 阶段 1：搭建基础 SoC

这是 PDF 第 2 章的核心内容。

目标：

- 把最小可运行 SoC 搭起来
- 让 CPU 能从 SRAM 取指执行
- 让 UART 输出可用
- 跑通 `hello_world`

这个阶段需要打通的主链路是：

```text
core_top
 -> Axi_CDC
 -> AxiCrossbar_2x8
    -> SRAM
    -> UART
```

阶段完成标志：

- `hello_world` 能成功编译出 `axi_ram.mif`
- Vivado 功能仿真通过
- 仿真控制台能看到 `Hello Loongarch32r!`
- FPGA 串口能看到相同输出

### 阶段 2：补充中断与显示功能

这是 PDF 第 3 章的核心内容。

目标：

- 补全 `confreg`
- 添加外部中断控制器
- 接入 `DVI`
- 跑通 `int_test`
- 最终运行 `pinball_game`

这个阶段需要把基础 SoC 扩展成：

```text
CPU
 -> Crossbar
    -> SRAM
    -> UART
    -> confreg
    -> DVI
```

阶段完成标志：

- `int_test` 串口输出正确
- 定时器中断与按键中断都能进入中断处理函数
- DVI 能出图
- `pinball_game` 能在 FPGA 上运行

## 4. 每个阶段到底在写什么

### 阶段 0 主要做什么

这个阶段主要是阅读、对照和确认，不急着写代码。

需要确认的重点：

- `soc_top.v` 末尾还停在 `// add your code`
- `sim/mycpu_tb.v` 假设 `u_axi_uart_controller` 已存在
- `sdk/hello_world` 依赖 UART
- `sdk/int_test` 依赖 confreg、定时器和按键中断
- `sdk/pinball_game` 依赖 DVI、按键、数码管

建议阅读顺序：

1. `rtl/soc_top.v`
2. `sim/mycpu_tb.v`
3. `rtl/config.h`
4. `rtl/ip/open-la500/README.md`
5. `sdk/software/examples/hello_world/main.c`
6. `sdk/software/examples/int_test/main.c`

### 阶段 1 主要写什么

这一阶段本质上是在 `rtl/soc_top.v` 里完成基础 SoC 的模块集成。

需要重点补的模块包括：

- `core_top`
- `Axi_CDC`
- `AxiCrossbar_2x8`
- `axi_wrap_ram_sp_external`
- `axi_uart_controller`

这一阶段主要实现的功能：

- CPU 能发 AXI 访问
- AXI 请求能跨时钟域同步到系统总线
- 总线能根据地址把访问路由到 SRAM / UART
- 软件写 UART 地址后，串口可以输出字符

这一阶段尽量不要一开始就引入 DVI、游戏、中断等复杂功能，先把最小闭环打通。

### 阶段 2 主要写什么

这一阶段在基础 SoC 上继续补全外设。

重点包括：

- 在 `confreg` 中补完整外部中断控制器逻辑
- 把外部中断送到 CPU 的 `HWI0`
- 添加 `axi_dvi`
- 跑通中断驱动和显示驱动

这一阶段主要实现的功能：

- 处理按键中断
- 处理外部定时器中断
- 控制 LED、数码管
- DVI 画矩形和圆
- 支撑弹球游戏运行

## 5. 推荐开发顺序

建议你们按下面顺序推进，而不是同时铺开。

1. 先完成阶段 0，彻底弄清工程结构
2. 只做基础 SoC，不碰 DVI 和游戏
3. 先跑通 `hello_world`
4. 再补 `confreg`
5. 再补外部中断控制器
6. 再接入 `DVI`
7. 先跑 `int_test`
8. 最后跑 `pinball_game`

## 6. 每个阶段的验收方式

### 阶段 0 验收

- 能画出系统主链路
- 能说清楚各目录用途
- 能列出 `soc_top.v` 尚未补齐的实例

### 阶段 1 验收

软件：

- `sdk/software/examples/hello_world` 编译通过

仿真：

- Vivado 仿真通过
- 控制台出现 `Hello Loongarch32r!`

上板：

- FPGA 下载 bit 和 bin 后
- 串口输出 `Hello Loongarch32r!`

### 阶段 2 验收

软件：

- `sdk/software/examples/int_test`
- `sdk/software/examples/pinball_game`

仿真：

- 能看到 `timer int`
- 能看到 `button1 int` 到 `button4 int`
- DVI 相关信号有正确活动

上板：

- `int_test` 能正常响应按键和定时器
- `pinball_game` 能运行

## 7. 当前项目最适合先做的事

基于当前仓库现状，最优先做的不是“写全部功能”，而是先把阶段 1 的基础链路补齐。

当前最关键的问题是：

- `soc_top.v` 还没有完成基础模块实例化
- 测试台已经默认 `u_axi_uart_controller` 存在

因此，当前最优先的工作顺序应当是：

1. 在 `soc_top.v` 中补基础 SoC 实例
2. 修复仿真 elaboration 错误
3. 跑通 `hello_world`
4. 再继续下一阶段

## 8. 开工前的简版 TODO

### 阶段 0

- 阅读 `soc_top.v`
- 阅读 `mycpu_tb.v`
- 对照 PDF 第 2 章与第 3 章
- 明确基础 SoC 和扩展功能的边界

### 阶段 1

- 实例化 CPU
- 实例化 CDC
- 实例化 Crossbar
- 实例化 SRAM 控制器
- 实例化 UART 控制器
- 跑通 `hello_world`

### 阶段 2

- 接入 confreg
- 添加外部中断控制器
- 接入 DVI
- 跑通 `int_test`
- 跑通 `pinball_game`

## 9. 一句话总结

这个项目最合理的推进方式是：

先把“CPU + RAM + UART”的基础 SoC 跑起来，再在这个基础上添加中断控制器和 DVI，最后完成中断测试和弹球游戏。
