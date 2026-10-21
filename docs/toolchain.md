# Verilog 工具链

这是 macOS 上的轻量 RTL 开发环境，包含编辑、静态检查、仿真、波形查看和通用综合检查。
当前默认项目是 8 位 ALU 与 FSM 控制器；接口、运算和时序讲解见 [项目 README](../README.md)。
原有 D 触发器保留为独立环境检查，可以用专门的 smoke 命令运行。

## 已安装工具

| 工具 | 本机版本 | 用途 |
| --- | --- | --- |
| VS Code + Verilog-HDL/SystemVerilog 扩展 | 扩展 1.29.0 | 编辑、高亮、补全、Icarus 即时语法检查 |
| Icarus Verilog / vvp | 13.0 | 编译并运行自检测试平台 |
| Surfer | 0.7.0 | 查看 VCD 波形 |
| Verilator | 5.052 | 检查可综合 RTL 的语法、位宽等问题 |
| Yosys | 0.70 | 通用综合、结构检查、导出网表 |
| make / Git | 系统已有 | 统一运行命令、管理源文件 |

在已安装 Homebrew 的 macOS 上安装命令行工具：

```sh
brew install icarus-verilog surfer verilator yosys
```

可用 `iverilog -V`、`vvp -V`、`surfer --version`、`verilator --version`、`yosys -V` 检查版本。
本机还有 `~/Applications/Surfer.app` 启动入口，指向 Homebrew 安装的 Surfer。

## VS Code 配置

在仓库根目录运行 `code .`，打开整个项目文件夹。
扩展是 [Verilog-HDL/SystemVerilog](https://marketplace.visualstudio.com/items?itemName=mshr-h.VerilogHDL)，推荐记录在 `.vscode/extensions.json`。
`.vscode/settings.json` 选择 Icarus 作为即时语法检查器，并按 Verilog-2005 检查 `.v` 文件。
本机工具路径为 `/opt/homebrew/bin`，模块搜索参数为 `-Wall -y rtl -y rtl/smoke`；换机器时按安装位置调整。
Makefile 默认编译选项为 `-g2005 -Wall`，使用传统 Verilog，不要求学习 SystemVerilog 新语法。

按 `Cmd+Shift+B` 运行默认 ALU 仿真任务。
从“终端 → 运行任务”可选择 compile、lint、synthesize、check all 或 clean。
`simulate and view waves` 先仿真再看波形，`view last waves` 只打开已有波形。
这些任务定义在 `.vscode/tasks.json`，实际调用仓库的 make 命令。

## 常用命令

所有命令在仓库根目录执行。直接运行 `make` 等同于 `make sim`。

```sh
make compile       # 仅编译 ALU 测试平台
make sim           # 编译并运行 ALU 自检，生成 VCD
make wave          # 先运行 ALU 仿真，再打开 Surfer
make view          # 只打开上次的 ALU 波形
make lint          # Verilator 只检查可综合 RTL
make synth         # Yosys 只读取 RTL，执行通用综合与结构检查
make check         # ALU lint、sim、synth，加上 DFF 仿真
make smoke         # 单独运行原有 D 触发器自检
make smoke-check   # D 触发器 lint、sim、synth
make smoke-wave    # 先运行 D 触发器仿真，再打开其波形
make clean         # 删除整个 sim/ 生成目录
```

默认测试顶层为 `tb_alu_controller`，可综合顶层为 `alu_controller`。
RTL 源文件为 `rtl/alu8.v rtl/alu_controller.v`，测试平台为 `tb/tb_alu_controller.v`。
Icarus 编译、vvp 执行测试；自检失败时 `$stop` 配合 `vvp -N` 返回非零退出码。
日常修改后先看终端 PASS/FAIL，再用波形解释每一拍的行为。

## 波形查看

| 项目 | VCD 文件 | Surfer 显示预设 |
| --- | --- | --- |
| ALU | `sim/alu_controller.vcd` | `tb/alu_controller.sucl` |
| D 触发器 | `sim/smoke.vcd` | `tb/smoke/smoke.sucl` |

例如，直接打开 ALU 波形：

```sh
surfer sim/alu_controller.vcd --command-file tb/alu_controller.sucl
```

`make wave` 和 `make view` 会在前台等待 Surfer，关闭查看器后任务才结束，这是正常行为。
预设保存在 `tb/`，清理 `sim/` 不会删除它；若 `make view` 提示缺少 VCD，先运行 `make sim`。

- 单击波形移动时间游标，查看该时刻信号的值。
- `+` / `-` 放大或缩小；`Shift+F` 显示完整时间范围。
- 修改源码并重新运行 `make sim` 后，在 Surfer 中按 `R` 重新读取 VCD。
- 按空格打开命令栏，可输入 `zoom_fit`、`reload` 或 `show_controls`。
- 从左侧测试平台层级中添加信号；ALU 可先看 `clk/rst/start/busy/done`，再对照数据。

详细操作见 [Surfer 命令文档](https://docs.surfer-project.org/book/commands/index.html)。
波形只是上一次仿真的记录，编辑源码不会自动改变已生成的 VCD。

## 生成文件与综合范围

`sim/` 在运行时自动创建，整个目录被 Git 忽略，保存 VVP、VCD、日志和综合网表。
ALU 综合日志为 `sim/alu_controller_synth.log`，D 触发器日志为 `sim/smoke_dff_synth.log`。
通用网表保存为 `sim/<RTL_TOP>_netlist.v` 与 `.json`；`make clean` 删除这些文件，之后可重新生成。
源代码、测试平台、Makefile、编辑器配置和 `.sucl` 预设需要保留。

Yosys 的检查说明 RTL 能转换为通用硬件结构，通过综合不代表功能或目标硬件时序一定正确。
真正上 FPGA 还需要选定器件、引脚与时钟约束、厂商工具、布局布线、时序检查和下载验证。
