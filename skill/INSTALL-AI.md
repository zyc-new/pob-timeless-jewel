# 20 给 AI 的永恒珠宝插件安装部署文档

> 目标：让 AI 帮助用户安装 `timeless-jewel-patch` 包。
> 适用：Windows、Path of Building Community **2.67.2**、PoE1 天赋树 **3.29**、中文 PoeCharm3。
> 本文件只描述安装，不描述功能开发。

## 1. AI 必须先确认的信息

安装前先定位 PoB 根目录。根目录应同时存在：

```text
Path of Building.exe
Launch.lua
Classes/TreeTab.lua
Modules/Build.lua
```

如果找不到，先让用户选择 PoB 根目录，不要猜测。

同时检查：

```text
Classes/TreeTab.lua
Modules/Build.lua
Launch.lua
Modules/AgentBridge.lua
```

## 2. 选择安装模式

### 模式 A：只安装面板插件

用户不需要 AI 自然语言查询，只需要：

```text
TreeTab.patch
Build.patch
new-files/
```

不要安装：

```text
Launch.patch
AgentBridge.patch
full-files/
```

### 模式 B：用户已有基础版 AgentBridge

用户需要 AI 查询，且存在：

```text
Modules/AgentBridge.lua
Launch.lua（已有 AgentBridge 启动钩子）
```

安装：

```text
TreeTab.patch
Build.patch
AgentBridge.patch
（如果没有 Launch 钩子：Launch.patch）
new-files/
```

### 模式 C：用户没有 AgentBridge

用户需要 AI 查询，但不存在：

```text
Modules/AgentBridge.lua
```

安装：

```text
TreeTab.patch
Build.patch
new-files/
full-files/Modules/AgentBridge.lua
full-files/Launch.lua
```

**不要**再应用 `AgentBridge.patch`，避免与完整文件重复。

## 3. 备份

在 PoB 根目录执行（先把 `$PoB` 改成实际路径）：

```powershell
$PoB = "<PoB根目录>"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $PoB "_backup\timeless-jewel-$stamp"
New-Item -ItemType Directory -Force -Path (Join-Path $backup "Classes"), (Join-Path $backup "Modules") | Out-Null

Copy-Item (Join-Path $PoB "Classes\TreeTab.lua") (Join-Path $backup "Classes\TreeTab.lua") -Force
Copy-Item (Join-Path $PoB "Modules\Build.lua") (Join-Path $backup "Modules\Build.lua") -Force
Copy-Item (Join-Path $PoB "Launch.lua") (Join-Path $backup "Launch.lua") -Force
if (Test-Path (Join-Path $PoB "Modules\AgentBridge.lua")) {
    Copy-Item (Join-Path $PoB "Modules\AgentBridge.lua") (Join-Path $backup "Modules\AgentBridge.lua") -Force
}
```

`$PoB` 必须替换为实际 PoB 根目录。

## 4. 复制新增文件

始终复制：

```text
new-files/Classes/TimelessJewelPlanner.lua  -> <PoB>/Classes/TimelessJewelPlanner.lua
new-files/Modules/TimelessPlannerSearch.lua -> <PoB>/Modules/TimelessPlannerSearch.lua
new-files/Modules/TimelessJewelTrade.lua    -> <PoB>/Modules/TimelessJewelTrade.lua
```

PowerShell：

```powershell
Copy-Item "<包目录>\new-files\Classes\TimelessJewelPlanner.lua" (Join-Path $PoB "Classes") -Force
Copy-Item "<包目录>\new-files\Modules\TimelessPlannerSearch.lua" (Join-Path $PoB "Modules") -Force
Copy-Item "<包目录>\new-files\Modules\TimelessJewelTrade.lua" (Join-Path $PoB "Modules") -Force
```

## 5. 应用补丁

进入 PoB 根目录：

```powershell
Set-Location $PoB

git apply --check "<包目录>\patches\TreeTab.patch"
git apply --check "<包目录>\patches\Build.patch"
```

两个检查都通过后再执行：

```powershell
git apply "<包目录>\patches\TreeTab.patch"
git apply "<包目录>\patches\Build.patch"
```

### 用户需要 AI 查询

模式 B：

```powershell
git apply --check "<包目录>\patches\AgentBridge.patch"
git apply "<包目录>\patches\AgentBridge.patch"
```

如果 `Launch.lua` 已有自定义修改、只缺 AgentBridge 钩子：

```powershell
git apply --check "<包目录>\patches\Launch.patch"
git apply "<包目录>\patches\Launch.patch"
```

模式 C：

```powershell
Copy-Item "<包目录>\full-files\Modules\AgentBridge.lua" (Join-Path $PoB "Modules") -Force
Copy-Item "<包目录>\full-files\Launch.lua" $PoB -Force
```

### 补丁失败时

不要强行覆盖。

- 如果 `TreeTab.patch` / `Build.patch` 失败：说明对方 PoB 版本或文件已有修改；
- 不要直接复制当前开发目录的完整 TreeTab/Build；
- 让用户提供 `git apply` 错误，或改用人工合并；
- 如果是 AgentBridge 缺失导致的失败，直接使用模式 C 的完整文件；
- 如果只是 `Launch.lua` 不匹配，优先使用 `Launch.patch`，不要覆盖自定义 Launch。

## 6. 安装后的静态检查

确认文件存在：

```powershell
Test-Path (Join-Path $PoB "Classes\TimelessJewelPlanner.lua")
Test-Path (Join-Path $PoB "Modules\TimelessPlannerSearch.lua")
Test-Path (Join-Path $PoB "Modules\TimelessJewelTrade.lua")
Select-String (Join-Path $PoB "Classes\TreeTab.lua") -Pattern "timelessPlanner"
Select-String (Join-Path $PoB "Modules\Build.lua") -Pattern "TimelessPlanner"
```

如果需要 AI 查询，再检查：

```powershell
Test-Path (Join-Path $PoB "Modules\AgentBridge.lua")
Select-String (Join-Path $PoB "Launch.lua") -Pattern "AgentBridge"
```

## 7. 启动与 UI 验证

必须通过中文 PoeCharm3 启动，不要直接启动英文版 `Path of Building.exe`。

如果已安装 `pob-bd-builder`：

```powershell
& "$env:USERPROFILE\.dsh\skills\pob-bd-builder\scripts\start-cn.cmd"
```

然后在 PoB 天赋树底部确认出现：

```text
精准规划
```

点击后应打开「永恒珠宝精准规划」面板。

## 8. AI Skill 安装（可选）

如果用户还要自然语言查询，把：

```text
pob-agent/pob-timeless-jewel/
```

复制到：

```text
%USERPROFILE%\.dsh\skills\pob-timeless-jewel\
```

依赖：

```text
pob-bd-builder 技能
中文 PoeCharm3
```

验证：

```powershell
$P = "$env:USERPROFILE\.dsh\skills\pob-timeless-jewel\scripts\planner.cmd"
& $P scan
```

`scan` 应返回 JSON，而不是：

```text
Unknown command: timeless_scan
```

## 9. 安装验收清单

```text
[ ] TreeTab.lua 存在 timelessPlanner 按钮
[ ] Build.lua 存在 TimelessPlanner 保存/加载
[ ] 新插件 3 个文件都在
[ ] 中文 PoB 可启动
[ ] 天赋树底部出现“精准规划”
[ ] 面板可打开
[ ] 选择珠宝类型/征服者后核心列表可刷新
[ ] 搜索能返回 seed
[ ] 双击 seed 能回到天赋树预览
[ ] PoB 安装后保持打开
```

## 10. 回滚

恢复备份：

```powershell
Copy-Item (Join-Path $backup "Classes\TreeTab.lua") (Join-Path $PoB "Classes\TreeTab.lua") -Force
Copy-Item (Join-Path $backup "Modules\Build.lua") (Join-Path $PoB "Modules\Build.lua") -Force
Copy-Item (Join-Path $backup "Launch.lua") $PoB -Force
if (Test-Path (Join-Path $backup "Modules\AgentBridge.lua")) {
    Copy-Item (Join-Path $backup "Modules\AgentBridge.lua") (Join-Path $PoB "Modules\AgentBridge.lua") -Force
}
```

删除新增文件：

```powershell
Remove-Item (Join-Path $PoB "Classes\TimelessJewelPlanner.lua") -Force
Remove-Item (Join-Path $PoB "Modules\TimelessPlannerSearch.lua") -Force
Remove-Item (Join-Path $PoB "Modules\TimelessJewelTrade.lua") -Force
```

然后重启中文 PoB。

## 11. 安全与行为约束

- **PoB 必须中文运行**；
- 安装/查询结束后不要关闭 PoB；
- `AgentBridge` 只监听 `127.0.0.1:49090`，没有 token 鉴权，不要暴露公网；
- 不要复制 `docs/`、`_backup/`、build XML、截图或 `__pycache__`；
- 不要覆盖用户自定义的 `Launch.lua`，优先应用 `Launch.patch`；
- 不要在没有备份的情况下强制覆盖 `TreeTab.lua` / `Build.lua`。
