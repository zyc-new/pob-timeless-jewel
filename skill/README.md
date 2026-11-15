# PoB Timeless Jewel Skill

仓库：https://github.com/zyc-new/pob-timeless-jewel

自然语言查询/切换永恒珠宝的 DSH 技能。

## 依赖

- `pob-bd-builder` 技能（负责启动中文 PoB）；
- PoB 中的 `Classes/TimelessJewelPlanner.lua`、`Modules/TimelessPlannerSearch.lua`；
- Python 3.10+（只用标准库）。

## 安装

把整个目录放到：

```text
%USERPROFILE%\.dsh\skills\pob-timeless-jewel\
```

命令：

```powershell
$P = "$env:USERPROFILE\.dsh\skills\pob-timeless-jewel\scripts\planner.cmd"
& $P scan
```

## 对话流程

1. 用户在 PoB 天赋树点亮珠宝孔和核心/过路点；
2. AI 调用 `scan`；
3. AI 列出珠宝类型/征服者选项，让用户选；
4. AI 列出每个核心实际可达结果，让用户多选；
5. AI 问过路点出现/不出现属性；
6. `configure` 同步面板；
7. 用户确认后 `search`；
8. 用户回 PoB 查看，或用：
   - `preview --seed 1234`
   - `next`
   - `next --direction -1`

## 注意

- PoB 必须通过中文 PoeCharm3 启动，禁止英文版；
- 查询/预览结束后不要关闭 PoB，保持客户端打开；
- 预览会临时替换当前珠宝孔的珠宝；原珠宝仍在物品列表，但不会自动恢复。
