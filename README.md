# ciciec2026_loongson_preliminary

## 0. 文档入口

这份仓库现在已经整理成“一个总入口 README + 几份中文辅助文档”的结构，建议按下面方式使用：

- `README.md`：项目总览、目录说明、常用操作
- `doc/项目导读.md`：从代码结构角度理解整个工程
- `doc/开发阶段与当前进度.md`：看任务阶段、当前卡点和下一步重点
- `doc/Vivado文件列表.txt`：Vivado 工程 / 仿真使用的文件清单
- `doc/IVerilog文件列表.txt`：Icarus Verilog 使用的文件清单

龙芯杯初赛工程模板，包含 LA32R 处理器核、SoC 顶层、仿真环境、FPGA 工程脚本以及软件 SDK。

这份仓库更像一套“比赛平台骨架”，不是单一软件项目。阅读时建议把它拆成 4 个部分理解：

- `rtl/`：SoC RTL 与各类 IP
- `sim/`：功能仿真测试台
- `fpga/`：Vivado 工程脚本与约束
- `sdk/`：交叉编译工具链、BSP 与软件示例

## 1. 项目目标

整体目标是围绕一个 LoongArch32R SoC 进行设计、仿真和上板验证。

当前项目状态可以先概括为：

- 阶段一 `hello_world` 已完成仿真验证
- 阶段二 `int_test` 已完成 timer / button 中断验证
- `pinball_game` 已在 FPGA 板上完成实际运行验证
- 当前工程已经不只是“仿真能跑”，而是已经具备板级可运行结果

顶层文件是 [rtl/soc_top.v](rtl/soc_top.v)，它对外暴露了：

- 时钟与复位
- 视频输出 `video_*`
- 按键 `touch_btn`
- 拨码开关 `dip_sw`
- LED 与数码管
- BaseRAM / ExtRAM
- UART

从 [rtl/ip/open-la500/README.md](rtl/ip/open-la500/README.md) 可以看出，CPU 核使用的是 `openLA500`，是一个 LA32R 五级流水核，带 I/D Cache、TLB 和 AXI 接口。

## 2. 顶层结构

### 2.1 SoC 顶层

[rtl/soc_top.v](rtl/soc_top.v) 是整个系统的硬件入口。

文件开头标了当前外设地址分布：

- `0x1f00_0000`：APB / UART
- `0x1f10_0000`：DVI
- `0x1f20_0000`：confreg
- `0x1f30_0000`：DMA

这个文件里主要做了几件事：

- 根据 `SIMULATION` 参数选择仿真时钟或板上 PLL
- 划分 `cpu_clk` 和 `sys_clk` 两个时钟域
- 声明 CPU、RAM、UART、DVI、confreg、DMA、FFT 等 AXI 信号
- 使用 `AxiCrossbar_2x8` 进行总线互连

需要特别注意：

- 当前这份 `soc_top.v` 末尾保留了 `// add your code`
- 文件里已经把很多从设备接口预留出来了
- 但 DMA / FFT / reserved slave 目前还是桩信号

也就是说，这份工程大概率是“待补全的比赛模板”，后续开发重点很可能就在 `soc_top.v` 的集成与扩展上。

### 2.2 CPU 核

CPU 核目录在 [rtl/ip/open-la500](rtl/ip/open-la500)。

值得优先看的文件：

- [rtl/ip/open-la500/mycpu_top.v](rtl/ip/open-la500/mycpu_top.v)：CPU 顶层
- [rtl/ip/open-la500/if_stage.v](rtl/ip/open-la500/if_stage.v)：取指级
- [rtl/ip/open-la500/id_stage.v](rtl/ip/open-la500/id_stage.v)：译码级
- [rtl/ip/open-la500/exe_stage.v](rtl/ip/open-la500/exe_stage.v)：执行级
- [rtl/ip/open-la500/mem_stage.v](rtl/ip/open-la500/mem_stage.v)：访存级
- [rtl/ip/open-la500/wb_stage.v](rtl/ip/open-la500/wb_stage.v)：写回级
- [rtl/ip/open-la500/icache.v](rtl/ip/open-la500/icache.v)
- [rtl/ip/open-la500/dcache.v](rtl/ip/open-la500/dcache.v)
- [rtl/ip/open-la500/csr.v](rtl/ip/open-la500/csr.v)
- [rtl/ip/open-la500/tlb_entry.v](rtl/ip/open-la500/tlb_entry.v)

如果后续要改 CPU 行为，基本都会落在这个目录里。

### 2.3 其他 IP

`rtl/ip/` 下除了 CPU 以外，还有 SoC 级外设与基础模块：

- `APB_UART/`：UART 控制器
- `Bus_interconnects/`：AXI 互连、CDC、AXI 转 SRAM
- `confreg/`：板级控制寄存器，通常挂按键、拨码、LED、数码管、计时器、中断
- `DVI/`：视频输出相关
- `ram_wrap/`：SRAM 包装模块
- `rst_sync/`：复位同步
- `PLL_*`：Vivado PLL IP

## 3. 仿真结构

### 3.1 测试台入口

仿真顶层是 [sim/mycpu_tb.v](sim/mycpu_tb.v)。

它主要做了这些事：

- 产生时钟和复位
- 产生触摸按键信号与拨码输入
- 实例化 `soc_top`
- 挂接两片仿真 SRAM
- 监听 UART 写操作并把字符打印到仿真控制台
- 通过 `debug_wb_pc == 32'h1c000200` 判断测试结束

这意味着：

- 软件程序如果通过 UART 输出 `printf`，仿真里能直接看到字符
- 程序结束依赖固定 PC 条件，不是通用“自动识别退出”

### 3.2 仿真 SRAM

[sim/sram.v](sim/sram.v) 提供了简单的单口 SRAM 模型：

- 支持 `Init_File` 初始化
- 使用 `$readmemb` 从 `.mif` 文件加载内容
- BaseRAM 和 ExtRAM 在仿真里都是它的实例

[rtl/config.h](rtl/config.h) 中定义了：

- `SRAM_Init_File = "../../../../../../sdk/axi_ram.mif"`

也就是说，软件编译后生成的 `sdk/axi_ram.mif` 会直接作为仿真程序镜像。

## 4. FPGA 结构

### 4.1 Vivado 工程脚本

[fpga/create_project.tcl](fpga/create_project.tcl) 是建立工程的入口脚本。

它会：

- 新建 `xc7a200tfbg676-1` 工程
- 加入 `rtl/` 目录源码
- 加入 PLL IP
- 加入 `sim/` 仿真文件
- 加入约束 `fpga/constraints/`

当前脚本中设置：

- 综合顶层：`soc_top`
- 仿真顶层：`tb_top`

### 4.1.1 Vivado 创建工程

在 Vivado 的 Tcl Console 中执行下面两条命令即可创建工程：

```tcl
cd C:/Users/naozh/Desktop/Task/3-2/Loogarch/ciciec2026_loongson_preliminary/fpga
source create_project.tcl
Run Simulation -> Run Behavioral Simulation
```

### 4.2 板级约束

[fpga/constraints/soc.xdc](fpga/constraints/soc.xdc) 包含大量引脚与时序约束，覆盖：

- `clk`
- `reset`
- `UART_TX / UART_RX`
- `video_*`
- `leds`
- `dpy0 / dpy1`
- `dip_sw`
- `touch_btn`
- `base_ram_*`
- `ext_ram_*`

并且还定义了：

- `cpu_clk` / `sys_clk` 生成时钟
- 两个时钟域异步关系
- SRAM 输入输出时序约束

如果后续改顶层端口，`soc.xdc` 基本也需要同步检查。

## 5. 软件 SDK 结构

### 5.1 目录分布

`sdk/` 主要有两部分：

- `toolchains/`：交叉编译工具链、picolibc、newlib
- `software/`：BSP 与示例程序

### 5.2 BSP

公共 BSP 代码在 [sdk/software/bsp](sdk/software/bsp)。

其中：

- `include/`：驱动头文件
- `drivers/`：驱动实现
- `env/start.S`：启动代码
- `env/trap_handler.S`：异常/中断入口
- `env/script.lds`：链接脚本
- `common.mk`：各示例共用的构建规则

[sdk/software/bsp/common.mk](sdk/software/bsp/common.mk) 是软件构建最关键的文件之一。

它负责：

- 指定 `loongarch32r-linux-gnusf-*` 工具链
- 加入 BSP 的启动文件和驱动
- 链接 `picolibc`
- 生成 `.elf`、`.bin`、反汇编 `.s`
- 调用 `convert` 把 bin 转为 `axi_ram.mif`
- 把生成物复制到 `sdk/`

### 5.3 示例程序

示例目录在 [sdk/software/examples](sdk/software/examples)：

- `hello_world`
- `int_test`
- `lenet`
- `pinball_game`
- `coremark`
- `dhrystone`
- `fireye`
- `c_prg`

建议第一次上手先看：

- [sdk/software/examples/hello_world](sdk/software/examples/hello_world)
- [sdk/software/examples/int_test](sdk/software/examples/int_test)

`hello_world` 比较适合理解：

- 如何定义板级全局变量
- 如何使用 `printf`
- 编译后程序如何进入仿真内存

`int_test` 比较适合理解：

- confreg 相关寄存器
- 定时器与按键中断
- 软件和外设寄存器的交互方式

## 6. 一个软件程序是怎样跑起来的

以 `hello_world` 为例，流程大致如下：

1. 在 `sdk/software/examples/hello_world` 中执行 `make`
2. 交叉编译生成 `hello_world.elf` 和 `hello_world.bin`
3. `convert` 把 `bin` 转换为 `axi_ram.mif`
4. `axi_ram.mif` 被复制到 `sdk/axi_ram.mif`
5. 仿真时 [sim/sram.v](sim/sram.v) 通过 `$readmemb` 读入这个镜像
6. `soc_top` 取指执行程序
7. UART 输出在 [sim/mycpu_tb.v](sim/mycpu_tb.v) 里被打印到控制台

这一条链路把 `sdk/` 和 `sim/` 很自然地串起来了。

## 7. 当前工程里值得注意的点

### 7.1 当前阶段性结论

目前可以把项目完成度总结为：

- `CPU + Axi_CDC + AxiCrossbar + RAM + UART` 主线已经跑通
- `confreg` 已接入并完成基本中断控制功能
- `cpu_intrpt` 已接入真实中断输入
- `axi_dvi` 已接入 SoC，并已支撑显示相关程序运行
- `int_test` 已完成按键和定时器中断验证
- `pinball_game` 已在板上完整运行

这意味着当前工作的重点已经从“把功能做出来”切换到“整理提交材料与保留稳定版本”。

### 7.1 这是模板，不是完整成品

从目前代码状态看：

- `soc_top.v` 已经把系统骨架搭好了
- 互连和地址空间也已经规划好
- 但末尾仍留有 `// add your code`
- 部分从设备还是占位实现

如果你在阅读时感觉“信号很多，但实例不完整”，这是正常的。

### 7.2 仿真与上板都依赖同一个顶层端口定义

所以很多变更会同时影响：

- [rtl/soc_top.v](rtl/soc_top.v)
- [sim/mycpu_tb.v](sim/mycpu_tb.v)
- [fpga/constraints/soc.xdc](fpga/constraints/soc.xdc)

### 7.3 软件和硬件耦合度比较高

例如软件中的这些变量：

- `UART_BASE`
- `CONFREG_TIMER_BASE`
- `CORE_CLOCKS_PER_SEC`

都直接依赖硬件地址映射和时钟设定，因此改 SoC 地址或时钟后，软件侧通常也需要同步调整。

## 8. 推荐阅读顺序

如果是第一次接手，建议按下面顺序读：

1. [rtl/soc_top.v](rtl/soc_top.v)
2. [sim/mycpu_tb.v](sim/mycpu_tb.v)
3. [rtl/config.h](rtl/config.h)
4. [rtl/ip/open-la500/README.md](rtl/ip/open-la500/README.md)
5. [rtl/ip/open-la500/mycpu_top.v](rtl/ip/open-la500/mycpu_top.v)
6. [sdk/software/bsp/common.mk](sdk/software/bsp/common.mk)
7. [sdk/software/examples/hello_world/main.c](sdk/software/examples/hello_world/main.c)
8. [sdk/software/examples/int_test/main.c](sdk/software/examples/int_test/main.c)
9. [fpga/create_project.tcl](fpga/create_project.tcl)
10. [fpga/constraints/soc.xdc](fpga/constraints/soc.xdc)
