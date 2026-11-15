---
name: pob-timeless-jewel
description: 用自然语言查询/切换 PoE1 永恒珠宝。必须通过 PoeCharm3 以中文 PoB 运行，查询/预览结束后保持 PoB 打开。用户在 PoB 天赋树点亮珠宝孔和天赋后，AI 先确认珠宝类型/征服者、每个核心天赋可接受结果，再调用 PoB 精准规划插件搜索；结果可查看编号、下一个/上一个，并直接在 PoB 天赋树中预览。
---

# PoB 永恒珠宝自然语言查询

这个技能控制 PoB 里的 **「永恒珠宝精准规划」** 插件：

- 读取用户在天赋树中**已点亮**的珠宝孔、核心 notable、keystone、过路小点；
- 让 AI 用自然语言逐步确认查询条件；
- 把条件同步到 PoB 搜索面板；
- 搜索 seed；
- 用“查看编号 xxx / 下一个 / 上一个”直接切换珠宝并在天赋树中预览。

> 前置：`pob-bd-builder` 技能已安装，中文 PoB 已能启动。本技能通过它启动中文 PoB。
> 不修改现有 `Find Timeless Jewel`；所有配置只作用于新插件。

## 运行环境硬性规则

- **PoB 必须始终以中文化方式运行**：必须通过 PoeCharm3 的中文环境启动；禁止直接启动英文版 `Path of Building.exe`，禁止在英文 PoB 上继续查询或预览。
- **查询、配置、预览、搜索结束后不要关闭 PoB**：不要结束 `Path of Building` / `PoeCharm3` 进程，不要点关闭，不要调用 `Stop-Process`。查询完成后让 PoB 保持打开，用户可直接查看天赋树。
- 只有用户明确要求重启 PoB 时才允许重启；重启也必须使用中文 PoeCharm3。
- 如果发现当前 PoB 是英文版或没有中文界面：先停止本次查询，提示用户切换到中文 PoB，不要在英文环境继续。
- `planner.cmd` 只负责启动/连接中文 PoB，不负责退出 PoB；查询结束后不要执行任何清理进程的命令。

## 命令入口

```powershell
$P = "$env:USERPROFILE\.dsh\skills\pob-timeless-jewel\scripts\planner.cmd"

& $P scan
```

首次使用 / 每次扫描：

```powershell
& $P scan
```

`scan` 返回当前状态：

- `socketId` / `sockets`：已点亮珠宝孔；
- `jewelType` / `conqueror`：当前类型/征服者；
- `types`：珠宝类型选项；
- `conquerors`：当前类型的征服者选项；
- `core`：每个已点亮 notable，包含：
  - `id`、`name`
  - `selected`：已选结果 id
  - `options`：该节点**实际可达**的结果，含 `id`、`key`、`kind`、`label`、`primary`、`selected`
    - `kind="replacement"`：替换型；
    - `kind="addition"`：附加型，`id` 以 `add:` 开头；
    - `id` 可能已经是 `add:...`，写入 `coreOutcomes` 时直接使用该值；
- `keystone`：已点亮 keystone；
- `resultCount` / `firstSeeds` / `firstResults` / `previewSeed`；
  - `firstResults[]` 含 `seed`、`coreHits`、`coreTotal`、`socketId`。

如果 `socketId` 为空：告诉用户先在天赋树点亮珠宝孔；如果 `core` 为空：让用户点亮想替换的 notable。

## 用户确认信息必须中文

所有给用户看的确认、选项、摘要都必须用中文，不能直接把 `scan` 里的英文原样贴给用户。

- 珠宝类型用中文名，英文可放括号：
  ```text
  1. 光彩夺目（Glorious Vanity）
  2. 致命骄傲（Lethal Pride）
  ```
- 征服者用中文名：
  ```text
  1. 任意
  2. 多里亚尼（腐化之魂）
  3. 希巴夸（神圣血肉）
  4. 阿华纳（不朽野心）
  ```
- 核心天赋、keystone 名称用中文；必要时括号保留英文原名，例如：
  ```text
  灰烬、冰霜与风暴（Ash, Frost and Storm）
  死灵之契（Necromantic Aegis）
  ```
- 核心替换/附加结果用中文词缀；结果原名可放括号：
  ```text
  1. 诅咒效果（Ancient Hex）
  2. 火焰伤害（Flesh to Flames）
  ```
- 如果 `scan` 返回的是英文或原始 stat key，先翻译成中文再展示；不能只回复英文名或 `fire_damage_+%` 这类 key。
- 最终确认摘要必须全中文，例如：
  ```text
  珠宝类型：光彩夺目
  征服者：多里亚尼（腐化之魂）
  珠宝孔：Basic Jewel Socket [6230]
  核心：灰烬、冰霜与风暴 → 诅咒效果
  确认开始搜索？
  ```

## 稳定适配检查

每次开始查询、PoB 重启、切换 build、切换珠宝孔或切换珠宝类型后：

1. 先执行 `scan`，以本次返回的 `socketId`、`core[].id`、`options` 为准；
2. 不要复用上一次会话的节点 ID、核心选项或搜索结果；
3. 用户切换珠宝类型时：
   - 先只 `configure` 新的 `jewelTypeId` / `conquerorId`；
   - 再重新 `scan`；
   - 然后才配置核心；
4. 搜索返回 0 时，先检查：
   - 核心是否要求了多个不可能同时出现的结果；
   - 当前类型/孔位是否正确；
5. 预览后不要重新假设状态，直接 `scan` 或让用户继续“下一个/上一个”。

## 必须遵守的对话流程

### 第 1 步：扫描

先运行 `scan`，不要先假设职业、珠宝类型或孔位。

### 第 2 步：让用户确认珠宝类型或征服者

把 `types` 列成编号给用户选，例如：

```text
请选择珠宝类型：
1. 光彩夺目（Glorious Vanity）
2. 致命骄傲（Lethal Pride）
...
```

用户选定后，再列 `conquerors`（当前类型对应的征服者）让用户选：

```text
请选择征服者：
1. 任意
2. 多里亚尼（腐化之魂）
...
```

不要替用户默认选择；用户明确说“任意/你决定”才使用默认。

> 用户切换珠宝类型时，必须清空之前类型下的 `coreOutcomes` 和搜索结果，不能把旧类型的替换/附加结果带到新类型，避免不同珠宝属性互相干扰。
> 通过 `configure` 切换类型时，不要同时传旧的 `coreOutcomes`；应先只传 `jewelTypeId`（可带 `conquerorId`），让面板清空，再重新选择核心。

### 第 3 步：确认核心天赋替换属性

对 `core` 中每个已点亮 notable：

- 展示节点名和当前可选结果；
- 结果按 `primary` 分组，例如“火焰伤害”“诅咒效果”“力量”；
- `options[].kind` 可能是：
  - `replacement`：替换型核心结果；
  - `addition`：在原有天赋上附加属性，`id` 形如 `add:karui_notable_add_armour`，也必须作为可选项展示；
- 两类结果都可以多选；
- 用户说“不限制”则不配置该核心。

示例：

```text
祝圣之体 可选：
1. 火焰之息 [火焰伤害]
2. 熔岩之击 [火焰伤害]
3. 冰霜之触 [冰霜伤害]
请选择可接受的结果（可多选，或说“不限制”）。
```

只使用 `options` 中出现的 `id`，不要编造结果。

### 第 4 步：生成配置并同步面板

把确认结果写成 JSON 文件，例如：

```json
{
  "jewelTypeId": 1,
  "conquerorId": 2,
  "socketId": 36634,
  "coreOutcomes": {
    "36949": ["vaal_notable_x", "vaal_notable_y"]
  }
}
```

调用：

```powershell
& $P configure --args-file "$env:TEMP\pob-timeless-jewel.json"
```

`configure` 会：

- 更新 `build.timelessPlannerState`；
- 重新打开/刷新 PoB 精准规划面板；
- 让用户看到类型、征服者、核心的最新配置。

### 第 5 步：确认后搜索

先向用户确认摘要：

```text
珠宝类型 / 征服者 / 孔位
核心：...

确认开始搜索？
```

用户确认后：

```powershell
& $P search
```

搜索完成后：

- 返回 `resultCount`、`firstSeeds`、`firstResults`；
- 如果配置了多个核心：
  - 结果是按 `coreHits` 从多到少排序；
  - 结果行会显示 `命中 N/M 个核心`；
  - 只要求至少命中 1 个，不要求全部命中；
  - 不要声称所有核心都命中；
- 提醒用户：**回 PoB 面板查看结果**；
- 告诉用户可以在面板双击结果，或对 AI 说：
  - “查看编号 1234”
  - “下一个”
  - “上一个”

### 第 6 步：自然语言切换珠宝

用户说“查看编号 xxx”：

```powershell
& $P preview --seed xxx
```

效果：

- 该 seed 的临时珠宝放入当前孔；
- 关闭面板并切回天赋树；
- 用户直接看到该珠宝在树上的实际替换属性。

用户说“下一个”：

```powershell
& $P next
```

用户说“上一个”：

```powershell
& $P next --direction -1
```

这两个命令基于最近一次 `search` 的结果列表切换。

> 预览完成后保持 PoB 打开，不要关闭窗口或结束进程。用户可能继续用“下一个/上一个”切换。

## 配置 JSON 字段

```json
{
  "jewelTypeId": 1,
  "conquerorId": 2,
  "socketId": 36634,
  "coreOutcomes": { "36949": ["outcomeId1", "outcomeId2"] }
}
```

- `jewelTypeId`：`scan.types[].id`
- `conquerorId`：`scan.conquerors[].id`
- `socketId`：`scan.socketId` 或 `scan.sockets[].id`
- `coreOutcomes`：`nodeId -> [option.id, ...]`
  - 替换型直接用结果 id；
  - 附加型使用 `add:...` 前缀，保持与替换型区分；


未提供的字段保持当前状态。

## 错误处理

| 返回 | 对用户说 |
| --- | --- |
| `No lit jewel socket` | 先在天赋树点亮珠宝孔 |
| `core options` 为空 | 这个核心在当前孔/类型下没有可达替换或附加结果 |
| `No search results` | 条件太严，先减少核心多选或更换珠宝类型 |
| `Planner state missing` | 先打开一次精准规划面板 |
| bridge 连接失败 | 先运行 `pob-bd-builder` 的 `start-cn.cmd` |

## 禁止

- 不要直接启动英文版 `Path of Building.exe`；
- 不要在查询/预览结束后关闭 PoB，不要结束 `Path of Building` 或 `PoeCharm3` 进程；
- 不要修改现有 `Find Timeless Jewel` 设置；
- 不要把 `coreOutcomes` 里的结果换成不在 `options` 里的 id；
- 用户未确认前不要开始搜索；
- 用户说“下一个/上一个”前必须已经搜索过；否则先 `scan`/`search`。
