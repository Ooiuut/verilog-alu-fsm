# 8 位 ALU 与有限状态机

这是一个可以用入门数字电路知识讲清楚的小项目：组合逻辑负责运算，寄存器保存数据，Moore 有限状态机决定每一拍做什么。
先理解加减法、逻辑门、触发器和状态机，就能逐块读懂它；不需要处理器架构知识。
接口与时序的完整约定见 [设计规格](alu8-design.md)，工具安装和编辑器细节见 [工具链说明](toolchain.md)。

## 先运行起来

在仓库根目录执行：

```sh
make sim       # 编译并运行自检，生成 sim/alu_controller.vcd
make wave      # 先仿真，再用 Surfer 打开波形
make check     # ALU 静态检查、仿真、通用综合，再运行 DFF 环境检查
make smoke     # 单独运行原有的 D 触发器环境检查
```

当前验证结果（可运行 `make check` 复现）：

```text
PASS: 131 output checks, 38 completed operations
PASS: smoke D flip-flop (7 checks)
```

ALU 仿真在 1276 ns 结束；Verilator `-Wall` 检查通过，Yosys `check -assert` 报告 0 个问题。
自检失败会输出 `FAIL`，并以非零退出码结束。
`make` 默认等同于 `make sim`。生成文件都在 `sim/`，不作为源文件提交。

## 这个电路怎样分工

```text
         operand_a[7:0]  operand_b[7:0]  opcode[2:0]
                |              |             |
                v              v             v
             +----------------------------------+
             | A/B/opcode 输入寄存器             | <-- 接收请求时保存
             +----------------------------------+
                         |
                         v
                   +------------+
                   | alu8       |    组合逻辑：按 opcode 运算
                   +------------+
                         |
                         v
             +----------------------------------+
             | result 与三个标志寄存器          | <-- 运算完成时保存
             +----------------------------------+
                         |
                         v
                result / carry / borrow / overflow

  clk, rst, start --> +------------------------+
                     | 状态寄存器 + 控制逻辑  |
                     | IDLE -> EXECUTE -> DONE |
                     +------------------------+
                         |               |
                   控制上面的保存动作    busy, done
```

`alu_controller` 包含整张图，是对外使用的顶层；`alu8` 是其中的一块组合电路。
数据通路回答“算什么”，控制器回答“什么时候保存输入、什么时候保存结果”。

## 模块端口

`alu8` 没有时钟，也没有复位。它的输入改变后，输出随组合逻辑传播而改变。

| 端口 | 方向 | 位宽 | 含义 |
| --- | --- | --- | --- |
| `operand_a` | 输入 | 8 | 操作数 A |
| `operand_b` | 输入 | 8 | 操作数 B |
| `opcode` | 输入 | 3 | 选择八种运算之一 |
| `result` | 输出 | 8 | 运算结果的低 8 位 |
| `carry` | 输出 | 1 | 加法进位，或移位移出的那一位 |
| `borrow` | 输出 | 1 | 无符号减法是否借位 |
| `overflow` | 输出 | 1 | 有符号加减法是否溢出 |

`alu_controller` 的全部端口如下，输入都与 `clk` 同步。

| 端口 | 方向 | 位宽 | 含义 |
| --- | --- | --- | --- |
| `clk` | 输入 | 1 | 时钟，在上升沿更新寄存器 |
| `rst` | 输入 | 1 | 高电平有效的同步复位 |
| `start` | 输入 | 1 | 空闲时为 1，申请一次运算 |
| `operand_a`、`operand_b` | 输入 | 各 8 | 本次运算的操作数 |
| `opcode` | 输入 | 3 | 本次运算的选择码 |
| `result` | 输出 | 8 | 最近一次完成的结果 |
| `carry`、`borrow`、`overflow` | 输出 | 各 1 | 与该结果对应的标志 |
| `busy` | 输出 | 1 | 状态不是 IDLE 时为 1 |
| `done` | 输出 | 1 | 状态为 DONE 时为 1，持续一拍 |

控制器里的每组寄存器都有具体用途：

| 寄存器 | 位数 | 为什么要保存 |
| --- | --- | --- |
| A、B 输入寄存器 | 各 8 | 请求接收后，即使外部输入改变，本次运算仍使用原来的数 |
| opcode 输入寄存器 | 3 | 把运算种类与这组 A、B 一起保存 |
| result 寄存器 | 8 | 保存完成的结果，空闲和接收下一次请求时仍保持 |
| carry、borrow、overflow 寄存器 | 各 1 | 保存与 result 同一次运算的标志 |
| 状态寄存器 | 2 | 用不同编码记住 IDLE、EXECUTE、DONE 三个阶段 |

`busy` 和 `done` 由当前状态直接决定，不需要再各放一个寄存器。

## 八种运算

这里的 A、B 指已经保存的输入。`8'hFF` 表示 8 位十六进制数 FF，即无符号的 255。

| opcode | 名称 | result | carry | borrow | overflow |
| --- | --- | --- | --- | --- | --- |
| `3'd0` | ADD 加法 | A + B 的低 8 位 | 和的第 9 位 | 0 | 有符号加法溢出 |
| `3'd1` | SUB 减法 | A - B 的低 8 位 | 0 | 无符号 A < B 时为 1 | 有符号减法溢出 |
| `3'd2` | AND 按位与 | `A & B` | 0 | 0 | 0 |
| `3'd3` | OR 按位或 | `A \| B` | 0 | 0 | 0 |
| `3'd4` | XOR 按位异或 | `A ^ B` | 0 | 0 | 0 |
| `3'd5` | NOT 按位取反 | `~A` | 0 | 0 | 0 |
| `3'd6` | SHL 左移一位 | `A << 1`，右侧补 0 | 原来的 A[7] | 0 | 0 |
| `3'd7` | SHR 右移一位 | `A >> 1`，左侧补 0 | 原来的 A[0] | 0 | 0 |

NOT、SHL、SHR 不使用 B。移位次数固定为 1，SHR 是补零的逻辑右移。
八个二进制 opcode 都有定义。仿真中若 opcode 含 X/Z 而未匹配，`case` 的默认分支输出全零；这不是硬件中的未知值检测器。

## 进位、借位和溢出是三件事

8 位结果只能保留 256 种位模式，超出的部分会丢弃，结果按模 256 回绕。
同一位模式可以按无符号数 0～255 理解，也可以按二进制补码有符号数 -128～127 理解。
`carry`、`borrow` 按无符号数判断，`overflow` 按有符号数判断。

| 手算 | 8 位结果 | carry | borrow | overflow | 怎样理解 |
| --- | --- | --- | --- | --- | --- |
| `FF + 01 = 100` | `00` | 1 | 0 | 0 | 无符号 255+1 有第 9 位；有符号 -1+1=0 没溢出 |
| `7F + 01 = 80` | `80` | 0 | 0 | 1 | 无符号 127+1 没进位；有符号 +128 超过 127 |
| `00 - 01 = -1` | `FF` | 0 | 1 | 0 | 无符号 0 不够减 1，需要借位；有符号 -1 可表示 |

还可以手算 `80 - 01`：有符号 -128-1=-129，超出范围，保留的结果为 `7F`，所以 overflow=1。
但无符号 128-1=127 不需要借位，所以 borrow=0。
不要把“最高位为 1”“有进位”“有符号溢出”混为一谈。

## 按时钟读懂状态机

这是 Moore 状态机：`busy`、`done` 只由当前状态决定。
下面假设没有复位，请求在第 N 个上升沿被接收；表中数值均指该沿更新完成以后。

| 上升沿 | 状态变化 | 这一拍发生什么 | busy | done |
| --- | --- | --- | --- | --- |
| N，start=1 | IDLE → EXECUTE | 保存 A、B、opcode；保留旧结果和旧标志 | 1 | 0 |
| N+1 | EXECUTE → DONE | 保存 ALU 结果和三个标志 | 1 | 1 |
| N+2 | DONE → IDLE | 保留结果，回到空闲 | 0 | 0 |
| N+3，start=1 | IDLE → EXECUTE | 最早可以在这里接收下一次请求 | 1 | 0 |

从接收请求到新结果和 done 有效，相隔一个时钟周期。DONE 也属于 busy：done=1 时 busy 同时为 1。
在 EXECUTE 或 DONE 状态遇到的 start 会被忽略，没有请求队列。
start 是在 IDLE 的上升沿按电平判断；如果始终保持为 1，就会每三拍重新接收一次请求。
通常在 busy=0 时准备输入，并让 start 覆盖一个接收上升沿，随后拉低。

同步使用结果时，应在看到 done=1 的上升沿采样，例如外部使用者可以写：

```verilog
always @(posedge clk) begin
    if (rst)
        saved_result <= 8'h00;
    else if (done)
        saved_result <= result;
end
```

这里 `saved_result` 是外部使用者自己的 8 位寄存器。
在 N+1 上升沿，控制器通过非阻塞赋值更新结果与状态；同一上升沿的其他时序块仍读取更新前的值。
因此上面的使用者会在 N+2 上升沿读到原本已保持一整拍的 done=1 和新结果。
不要假设它能在 N+1 的同一个上升沿立即读取刚更新的 done。

## 复位与赋值写法

`rst=1` 只在上升沿生效，优先于 start 和运算完成：状态回到 IDLE，所有输入、结果和标志寄存器清零，busy=0、done=0。
执行过程中复位会取消该次运算。两个上升沿之间拉高 rst，不会立即改变寄存器。
仿真刚开始且尚未经过复位上升沿时，寄存器可能是 X。

- 组合逻辑使用 `always @*`、`case` 和阻塞赋值 `=`，表达“由当前输入计算当前输出”。
- 每个组合输出先给默认值，避免某个分支漏赋值而意外记住旧值。
- 时序逻辑使用 `always @(posedge clk)` 和非阻塞赋值 `<=`，表达“在这一沿统一保存新值”。
- Verilog 的 `reg` 表示可以在过程块中赋值；组合块中的 `reg` 不一定会综合成触发器。

例如 `next_state` 是组合逻辑算出的下一状态，`arithmetic_result` 是保留第 9 位的组合计算中间值；它们虽声明为 `reg`，却不保存跨时钟的数据。
`localparam` 是模块内部的具名常量，例如用 IDLE 代替 `2'd0`，用 OP_ADD 代替 `3'd0`，让代码容易读。
测试平台中的 `task` 是可重复调用的一组测试步骤，例如统一完成“发请求、等时钟、检查结果”；它不属于被综合的 ALU 电路。

## 文件、工具和命令

| 文件 | 阅读重点 |
| --- | --- |
| `rtl/alu8.v` | 组合运算、位宽与标志 |
| `rtl/alu_controller.v` | 输入/输出寄存器、三个状态的动作 |
| `tb/tb_alu_controller.v` | 激励、预期结果与自动检查 |
| `tb/alu_controller.sucl` | Surfer 信号显示预设 |
| `rtl/smoke/`、`tb/smoke/` | 原有独立 D 触发器环境示例 |
| `sim/` | 自动生成的 VVP、VCD、日志与综合网表 |

本机工具版本：Icarus Verilog/vvp 13.0、Surfer 0.7.0、Verilator 5.052、Yosys 0.70。
源码使用传统 `.v` 和 Verilog-2005；默认编译选项是 `-g2005 -Wall`。

```sh
make compile       # 仅编译 ALU 测试平台
make sim           # 编译并运行自检
make view          # 打开已有波形，不重新仿真
make lint          # Verilator，仅检查可综合 RTL
make synth         # Yosys，输出日志和通用网表到 sim/
make check         # ALU lint、sim、synth，加上 DFF 仿真
make smoke-check   # 对原有 D 触发器运行 lint、sim、synth
make smoke-wave    # 仿真并打开原有 D 触发器波形
make clean         # 删除 sim/ 中全部生成文件
```

默认仿真顶层是 `TOP=tb_alu_controller`，综合顶层是 `RTL_TOP=alu_controller`。
默认 RTL 为 `rtl/alu8.v rtl/alu_controller.v`，测试平台为 `tb/tb_alu_controller.v`。
波形为 `sim/alu_controller.vcd`，显示预设为 `tb/alu_controller.sucl`。
ALU 综合日志为 `sim/alu_controller_synth.log`，网表为 `sim/alu_controller_netlist.v` 和 `.json`。
如以后确实需要，可单次运行 `make sim IVERILOG_FLAGS='-g2012 -Wall'`；本例不需要 SystemVerilog 新语法。

测试平台检查八种运算、算术边界、X/Z opcode 的默认分支、输入保存、结果保持、忙时请求忽略且不排队、done 脉冲、连续请求、start 持续为高和各状态复位。
激励在下降沿改变，输出在上升沿非阻塞赋值更新后检查；失败使用 `$stop`，搭配 `vvp -N` 返回失败退出码。
看波形时，先跟踪 `clk/rst/start/busy/done`，再对照输入、状态和 result；修改源码后先重新仿真，再重新加载波形。

## 向导师讲解的顺序

先画数据通路：输入寄存器记住 A、B 和操作码，组合 ALU 算出结果，输出寄存器保存结果与标志。再沿时钟讲 IDLE、EXECUTE、DONE：空闲时接收，下一拍完成，再下一拍回到空闲。最后手算 FF+1、7F+1 和 00-1，说明进位、溢出、借位的区别，并用波形验证输入改变不会影响已经接收的运算。

本项目只使用同一时钟下的输入、固定一位移位和单次运算控制；没有队列或流水线。
Yosys 检查的是通用综合结构。具体 FPGA 的器件映射、引脚约束、布局布线、时序收敛和上板验证需另行完成。
