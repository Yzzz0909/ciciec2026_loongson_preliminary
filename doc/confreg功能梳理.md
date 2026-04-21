# confreg 功能梳理

这份文档用于把当前 `confreg` RTL 实现、软件访问地址、以及阶段二联调重点整理到一起。

## 1. 当前结论

当前 `confreg` 已经完成了 **AXI 接入**，并且已经在 `soc_top.v` 中实例化。

但从 [confreg.v](/C:/Users/naozh/Desktop/Task/3-2/Loogarch/ciciec2026_loongson_preliminary/rtl/ip/confreg/confreg.v) 来看，最关键的 **中断控制逻辑** 仍未完成：

```verilog
//-------------------------------{int_ctrl}begin----------------------------//
//add your code
//--------------------------------{int_ctrl}end-----------------------------//
```

所以当前状态可以概括为：

- `confreg` 基础寄存器读写框架已存在
- LED / 数码管 / 开关 / 计时器寄存器已有主体实现
- 中断状态与 `confreg_int` 输出逻辑还没有补全
- 阶段二真正卡点在 `int_ctrl`

## 2. 地址映射总表

`confreg` 基地址对应软件虚地址 `0xbf20_0000` 段，当前实际使用的寄存器如下。

| 模块 | RTL 偏移 | 软件访问地址 | 当前 RTL 状态 | 软件是否使用 |
|---|---:|---:|---|---|
| 中断使能 `confreg_int_en` | `0xf000` | `0xbf20f000` | 已有寄存器 | 是 |
| 中断边沿 `confreg_int_edge` | `0xf004` | `0xbf20f004` | 已有寄存器 | 是 |
| 中断极性 `confreg_int_pol` | `0xf008` | `0xbf20f008` | 已有寄存器 | 是 |
| 中断清除 `confreg_int_clr` | `0xf00c` | `0xbf20f00c` | 已有寄存器 | 是 |
| 中断置位 `confreg_int_set` | `0xf010` | `0xbf20f010` | 已有寄存器 | 目前未明显使用 |
| 中断状态 `confreg_int_state` | `0xf014` | `0xbf20f014` | 只声明未完成逻辑 | 是 |
| 计时器计数值 `sys_timer` | `0xf100` | `0xbf20f100` | 已实现 | 是 |
| 计时器比较值 `sys_timer_cmp` | `0xf104` | `0xbf20f104` | 已实现 | 是 |
| 计时器使能 `sys_timer_en` | `0xf108` | `0xbf20f108` | 已实现 | 是 |
| 数码管控制 `digital_ctrl` | `0xf200` | `0xbf20f200` | 已实现 | 间接使用 |
| 数码管数据 `digital_data` | `0xf204` | `0xbf20f204` | 已实现 | 间接使用 |
| LED 数据 `led_data` | `0xf300` | `0xbf20f300` | 已实现 | 有驱动支持 |
| 拨码开关 `switch_data` | `0xf400` | `0xbf20f400` | 已实现 | 可读 |
| 仿真标志 `simu_flag` | `0xf500` | `0xbf20f500` | 已实现 | 是 |

## 3. 软件侧实际依赖

### `int_test`

[int_test main.c](/C:/Users/naozh/Desktop/Task/3-2/Loogarch/ciciec2026_loongson_preliminary/sdk/software/examples/int_test/main.c) 当前依赖这些 `confreg` 能力：

- 读取 `0xbf20f500` 判断是否为仿真环境
- 写 `0xbf20f004` 配置按钮中断边沿
- 写 `0xbf20f008` 配置中断极性
- 写 `0xbf20f00c` 清除中断
- 写 `0xbf20f000` 打开中断使能
- 写 `0xbf20f104` 设置定时器比较值
- 写 `0xbf20f108` 打开/重启计时器
- 读 `0xbf20f014` 获取中断状态

也就是说，`int_test` 要想跑通，下面这几项必须正确：

- `confreg_int_state` 真的能反映“哪个中断来了”
- 按键和定时器中断能置位状态位
- 写 `clr` 后状态位能被清掉
- `confreg_int` 能输出给 CPU

### `pinball_game`

[pinball_game main.c](/C:/Users/naozh/Desktop/Task/3-2/Loogarch/ciciec2026_loongson_preliminary/sdk/software/examples/pinball_game/main.c) 对 `confreg` 的依赖和 `int_test` 类似，另外还会依赖 DVI。

所以阶段二的依赖链其实是：

`confreg 中断寄存器正确 -> confreg_int 输出正确 -> CPU 中断链正确 -> int_test 正常 -> pinball_game 正常`

## 4. 当前 RTL 已完成部分

从 [confreg.v](/C:/Users/naozh/Desktop/Task/3-2/Loogarch/ciciec2026_loongson_preliminary/rtl/ip/confreg/confreg.v) 看，下面这些部分已经有主体实现：

- AXI-lite 风格的单次读写握手
- 读寄存器多路选择 `rdata_d`
- 写响应 `s_bvalid`
- 读响应 `s_rvalid`
- LED 寄存器 `led_data`
- 开关输入 `switch_data`
- 数码管控制/数据寄存器
- `simu_flag`
- `sys_timer` / `sys_timer_cmp` / `sys_timer_en`

这意味着：

- `hello_world` 阶段不依赖中断时，`confreg` 接入不会阻塞主线
- 阶段二可以从“补中断控制逻辑”直接开始，而不用重写整个模块

## 5. 当前缺口

### 5.1 中断状态逻辑未完成

当前虽然声明了：

- `confreg_int_en`
- `confreg_int_edge`
- `confreg_int_pol`
- `confreg_int_clr`
- `confreg_int_set`
- `confreg_int_state`
- `timer_int`
- `touch_btn_data`
- `dma_finish`
- `fft_finish`

但没有看到真正把它们组合起来的逻辑。

也就是说，下面这些行为目前大概率还没有实现完整：

- 按键上升沿 / 电平检测
- 定时器中断置位
- DMA / FFT 完成中断置位
- `clr` 清除中断
- `set` 软件置位中断
- `confreg_int_state` 输出
- `confreg_int` 总中断输出

### 5.2 CPU 端中断还没接上真实输入

当前在 [soc_top.v](/C:/Users/naozh/Desktop/Task/3-2/Loogarch/ciciec2026_loongson_preliminary/rtl/soc_top.v) 中，CPU 中断还是常量：

```verilog
wire [7:0] cpu_intrpt;
assign cpu_intrpt = 8'h00;
```

这保证了阶段一不会因为悬空而出错，但阶段二必须改成真实连接。

## 6. 阶段二第一步建议

现在最值得优先做的，不是先碰 DVI，而是：

1. 在 `confreg.v` 里补完 `int_ctrl`
2. 让 `confreg_int_state` 能正确反映按钮/定时器状态
3. 让 `confreg_int` 输出一个总中断请求
4. 在 `soc_top.v` 中把 `cpu_intrpt` 改成真实连接
5. 再去跑 `int_test`

## 7. 最小可执行 TODO

### P0 必做

- 补 `confreg_int_state` 的产生逻辑
- 补 `confreg_int` 的输出逻辑
- 让 `confreg_int_clr` 真正能清状态
- 确认 `timer_int` 能进状态位
- 确认 `touch_btn` 能进状态位

### P1 紧接着做

- 修改 `soc_top.v`，把 `cpu_intrpt` 改为接真实中断位
- 明确 `confreg_int` 对应 CPU 哪一位中断
- 用 `int_test` 做第一轮仿真联调

### P2 后续做

- 接入 `axi_dvi`
- 跑通 `pinball_game`

## 8. 现在最推荐的下一步

下一步就做这一件事：

**补 `confreg.v` 里的 `int_ctrl`。**

这是阶段二真正的起点，也是后面 `int_test` 能不能跑起来的决定性条件。

## 9. 关于是否单独拆成 `int_ctrl.v`

当前仓库里没有单独的 `int_ctrl.v` 文件，现有中断控制逻辑是直接写在 `confreg.v` 内部完成的。

从当前项目推进角度，建议采用下面的策略：

- 当前阶段先不拆分成独立 `int_ctrl.v`
- 先保持现有 `confreg.v` 内嵌实现，继续完成 `pinball_game` 仿真和后续上板验证
- 等阶段二主线稳定后，如果还有时间，再考虑把中断控制逻辑重构成单独模块

这样安排的原因是：

- 当前实现已经通过 `int_test` 的 timer 和 button 中断验证
- 现在拆模块容易引入新的连线错误，打断阶段二推进节奏
- 比赛现阶段更重要的是“功能跑通”，不是“文件拆分得最漂亮”

所以当前可以把这个决定理解为：

- `int_ctrl` 功能已经完成
- 只是暂时以内嵌形式存在于 `confreg.v`
- 当前不强制要求单独拆成 `int_ctrl.v`
