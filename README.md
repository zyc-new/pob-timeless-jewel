# PoB Timeless Jewel Planner

Path of Building Community 的永恒珠宝精准查询插件。

适用版本：

```text
Path of Building Community 2.67.2
PoE1 天赋树 3.29
```

## 功能

- 只读取已点亮的珠宝孔、核心 notable、keystone 和过路小点；
- 核心支持替换型和附加型结果；
- 附加型结果使用 `add:` 前缀，例如深渊珠宝和致命骄傲的附加属性；
- 多个核心按 `coreHits` 从多到少排序，结果显示 `命中 N/M 个核心`；
- 支持过路点出现/不出现属性；
- 支持 seed 分页、勾选、加入 BD、生成购买链接；
- 双击 seed 在天赋树中预览；
- 提供自然语言 Skill：类型/征服者确认、核心/过路点确认、查看编号、下一个/上一个。

## 下载

- [插件补丁包](downloads/timeless-jewel-patch.zip)
- [自然语言 Skill 包](downloads/pob-timeless-jewel-skill.zip)

## 安装

### 只安装面板插件

应用：

```text
patches/TreeTab.patch
patches/Build.patch
```

复制：

```text
new-files/Classes/TimelessJewelPlanner.lua
new-files/Modules/TimelessPlannerSearch.lua
new-files/Modules/TimelessJewelTrade.lua
```

### 安装 AI 查询

- 已有基础版 AgentBridge：应用 `patches/AgentBridge.patch`；
- 没有 AgentBridge：复制：
  ```text
  full-files/Modules/AgentBridge.lua
  full-files/Launch.lua
  ```
- 安装 `skill/` 到 DSH 技能目录：
  ```text
  %USERPROFILE%\.dsh\skills\pob-timeless-jewel\
  ```

详细安装步骤见 [INSTALL-AI.md](INSTALL-AI.md)。

## 版本与补丁

- `TreeTab.patch`：天赋树入口按钮和布局；
- `Build.patch`：`<TimelessPlanner>` 配置保存/加载；
- `Launch.patch`：启动时加载 AgentBridge；
- `AgentBridge.patch`：已有基础版 AgentBridge 时使用；
- `full-files/`：没有 AgentBridge 的新用户使用完整文件。

不要同时应用 `AgentBridge.patch` 和完整 `AgentBridge.lua`。

## 安全

- PoB 必须使用中文 PoeCharm3 启动；
- 查询/预览结束后不要关闭 PoB；
- AgentBridge 只监听 `127.0.0.1:49090`，当前没有 token 鉴权；
- 不要把 AgentBridge 暴露到公网；
- 本仓库不包含个人 build、截图、备份或本机绝对路径。
