# CSIG Sales OS — Design System V2.0

- 文档状态：Approved Design Specification
- 日期：2026-07-20
- 产品定位：个人 AI Solution Sales 工作空间
- 适用范围：CSIG Sales OS 全部 Web、Tablet 与 Mobile 页面
- 上游约束：不改变已冻结的数据模型

## 1. Design System 的职责

Design System V2.0 是所有页面的唯一视觉与交互来源。页面负责组合内容与业务流程，不得自行创造颜色、字号、间距、圆角、阴影、动画或组件变体。

系统应让用户感到正在打开：

- 一本私人高管工作手记；
- 一间安静的策略工作室；
- 一个现代、温暖、编辑式的个人知识空间。

它不是传统 Dashboard，不模拟 Salesforce、企业 OA、项目管理工具或通用聊天产品。

## 2. 核心设计原则

### 2.1 Editorial Workspace

页面应像阅读一份精心编辑的刊物。使用排版、留白、行长和 Divider 建立层级，不依赖彩色模块和容器堆叠。

### 2.2 Action Before Metrics

行动优先于指标。只有需要用户判断、打开、完成或推进的对象可以使用 Card。指标采用编辑式数字和文字，不形成 KPI 卡片墙。

### 2.3 Typography First

层级主要来自字号、字体、间距和字重。颜色只表达状态、强调和时间氛围。

### 2.4 Quiet AI

AI 以编辑、陪练和上下文助手的方式出现。使用 Daily Brief、Editor’s Note、Suggested Questions、Writing Assistant 和 Discovery Companion 等语言，不使用 Chatbot 叙事。

### 2.5 UI Disappears

界面装饰应退后，让用户注意客户、知识、行动与反思。所有视觉效果必须有功能理由。

## 3. Design Token 命名

所有页面使用语义令牌，不直接使用原始颜色或任意像素值。

令牌命名分为：

- `color.*`：颜色语义；
- `type.*`：字体、字号、行高与字重；
- `space.*`：间距；
- `radius.*`：圆角；
- `divider.*`：分隔线；
- `layout.*`：页面网格；
- `motion.*`：持续时间、距离和缓动。

## 4. Color System

### 4.1 Day Theme

| Token | Value | 用途 |
|---|---|---|
| `color.canvas` | `#F7F4EE` | 页面底色，暖纸张感 |
| `color.paper` | `#FBFAF7` | 可读内容面、输入与行动 Card |
| `color.ink` | `#2D2D2D` | 主要文字与高强调按钮 |
| `color.muted` | `#6B6B6B` | 辅助文字、时间和说明；由 AA 对比度验收从 `#727272` 微调 |
| `color.border` | `#DDD8CF` | Divider、边框和输入轮廓 |
| `color.accent` | `#7B93A7` | 当前重点、链接、AI 建议和焦点 |
| `color.success` | `#7D9580` | 已完成、健康和正向反馈 |
| `color.highlight` | `#B3945B` | 稀少的重点标记和珍贵记忆 |
| `color.danger` | `#A46F68` | 删除、阻塞和错误 |

Day Theme 的浅色 Accent 与 Danger 保留用于焦点、进度、边框和非文字强调。小尺寸文字分别使用 `color.accent-ink: #596F80` 与 `color.danger-ink: #8B5752`，避免牺牲 WCAG AA 对比度。

Day Theme 禁止使用高饱和腾讯蓝、微软蓝或大面积金色。

### 4.2 Night Theme

| Token | Value | 用途 |
|---|---|---|
| `color.canvas` | `#1E2230` | 夜间底色，不使用纯黑 |
| `color.paper` | `#242938` | 夜间内容面 |
| `color.ink` | `#F1EEE8` | 暖白主要文字 |
| `color.muted` | `#AEB1BC` | 次级文字 |
| `color.border` | `#3A4152` | Divider 与边框 |
| `color.accent` | `#9A92C7` | 当前重点、链接和焦点 |
| `color.success` | `#819C8A` | 正向状态 |
| `color.highlight` | `#D0B16F` | 稀少的记忆与重点标记 |
| `color.danger` | `#C58A82` | 删除、阻塞和错误 |

Night Theme 的小尺寸强调文字使用 `color.accent-ink: #B8B0E2` 与 `color.danger-ink: #D9A29B`。

Night Theme 禁止纯黑、OLED 黑、霓虹紫、发光描边和科技感渐变。

### 4.3 主题行为

- 默认采用 Auto。
- 06:00–18:00 使用 Day Theme。
- 18:00–06:00 使用 Night Theme。
- 时间判断采用用户本地时区。
- 用户手动选择 Day 或 Night 后暂停 Auto，直到重新开启 Auto。
- 主题切换不能改变布局、组件尺寸或信息层级。
- 主题加载时避免先闪现错误主题。

## 5. Typography

### 5.1 字体家族

| 角色 | 英文 | 中文 |
|---|---|---|
| Display / Heading | Source Serif 4 | Noto Serif SC |
| Body / Interface | Inter | PingFang SC |
| Fallback | Georgia | 系统宋体 / 系统无衬线 |

标题可在品牌授权和加载条件允许时采用 Canela，但不可依赖未授权字体。Cormorant Garamond 可作为展示性备选，不作为默认中文标题字体。

### 5.2 字体层级

| Token | Size / Line Height | Weight | 用途 |
|---|---|---|---|
| `type.display-xl` | 42 / 47 | 400 | 问候和页面主叙事 |
| `type.heading-1` | 34 / 41 | 400 | 页面标题 |
| `type.heading-2` | 25 / 33 | 400 | 主 Section 标题 |
| `type.heading-3` | 18 / 26 | 400 | 子节标题 |
| `type.body-lg` | 16 / 28 | 400 | 长文和重要说明 |
| `type.body-md` | 14 / 23 | 400 | 默认正文 |
| `type.body-sm` | 12 / 19 | 400 | 次级说明 |
| `type.control` | 13 / 20 | 500 | Button、Input 和可操作文字 |
| `type.label` | 10 / 15 | 500 | Uppercase Section Label |
| `type.metadata` | 11 / 17 | 400 | 日期、状态、来源 |

`type.label` 使用 `0.13em` 字距和大写英文。中文 Label 不强制字符间加空格。

### 5.3 排版规则

- 默认不使用 600 以上字重。
- 正文最佳行长为 52–76 个英文字符或约 26–38 个中文字符。
- 长文本使用 `type.body-lg` 或 `type.body-md`，不得使用 Metadata 尺寸承载正文。
- 标题与正文的层级优先通过间距和字号建立。
- Highlight Color 不得替代标题层级。

## 6. Spacing System

| Token | Value | 典型用途 |
|---|---|---|
| `space.1` | 4 | 紧密图标与文字 |
| `space.2` | 8 | 控件内部小间距 |
| `space.3` | 12 | 相关字段和元信息 |
| `space.4` | 16 | Card 内部基础间距 |
| `space.5` | 24 | 组件组间距 |
| `space.6` | 32 | 小 Section 间距 |
| `space.7` | 48 | 页面内容组间距 |
| `space.8` | 64 | 主 Section 间距 |
| `space.9` | 80 | 首页和阅读页 Section 间距 |
| `space.10` | 120 | 大型叙事分区 |

页面不能使用 18、22、30、36 等未定义间距。需要新间距时必须修改 Design System。

## 7. Border Radius System

| Token | Value | 用途 |
|---|---|---|
| `radius.none` | 0 | 编辑式 Section、表格和 Divider |
| `radius.control` | 8 | Button、Input、Menu Item |
| `radius.floating` | 12 | Popover、AI 浮层、小型 Sheet |
| `radius.card` | 18 | 可行动 Card、Empty State |
| `radius.full` | 999 | 极少数中性状态或头像 |

- Card 可在空间允许时使用 18–20px，但实现令牌固定为 18px。
- 页面不得创建独立的 6、10、14、16、24px 圆角。
- 状态 Pill 不得依靠多色背景形成 Badge 墙。

## 8. Divider Rules

所有 Divider 为 1px：

| Token | 规则 | 用途 |
|---|---|---|
| `divider.section` | Full width solid | 主 Section 开始或结束 |
| `divider.row` | Inset solid | Timeline、列表与 Context Item |
| `divider.vertical` | Full-height solid | 三栏布局分隔 |
| `divider.empty` | Dashed | Empty State 边界，唯一允许的虚线 |

不得使用双线、粗线、发光线或彩色渐变线。

## 9. Surface and Card Specification

### 9.1 Surface

- 页面 Canvas 使用 `color.canvas`。
- 阅读内容可直接位于 Canvas 上。
- 输入、可操作区域和需要背景图隔离的内容使用 `color.paper`。
- Day 和 Night 均使用极弱纸张或织物纹理，视觉透明度不超过 3%。
- 禁止通用阴影、发光和卡片内部渐变。

### 9.2 Card

Card 只用于：

- 今日行动；
- 需要点击进入的客户、商机、知识或 Insight 对象；
- Empty State 的行动提示；
- 浮动 AI 入口和临时弹层。

Card 规范：

- Background：`color.paper`；
- Border：`1px solid color.border`；
- Radius：`radius.card`；
- Shadow：none；
- 内边距：16 或 24；
- Hover：上移 1px，并轻微提高 Border 对比；
- 不使用彩色顶部条、渐变、发光或装饰图标。

普通报告、Timeline、指标、文章和表格不能包在 Card 中。

## 10. Layout Grid

### 10.1 Desktop 1440

| 区域 | 宽度 | 说明 |
|---|---|---|
| Left Navigation | 224 | 持久化个人工作室索引 |
| Center Shell | 968 | 包含左右各 48px 内边距 |
| Center Reading Column | 872 | 实际阅读和工作宽度，低于 920px 上限 |
| Right Context | 248 | Today’s Context |

三栏之间使用 `divider.vertical`，不使用悬浮侧栏 Card。

### 10.2 Wide Desktop ≥ 1536

- Left 最大 240px；
- Center Reading Column 最大 920px；
- Right 最大 280px；
- 多余宽度分配到外部留白，不无限拉宽正文。

### 10.3 Tablet 834

- Navigation 缩为 72px 导航入口或 Drawer；
- Center 占据剩余宽度；
- Right Context 隐藏，通过 Context Sheet 打开；
- 不在 Tablet 同时展示三栏。

### 10.4 Mobile 390

- 左右侧栏均隐藏；
- 使用固定 Bottom Navigation；
- 页面水平内边距 20px；
- Section 保持大间距和标题层级；
- Card 垂直排列；
- AI、Context 和筛选使用 Bottom Sheet；
- 正文不因移动端而缩小到 Metadata 尺寸。

## 11. Wallpaper System

### 11.1 三层结构

1. Layer 1：User Wallpaper Image；
2. Layer 2：Theme Overlay、Brightness 与 Blur；
3. Layer 3：Workspace Content。

### 11.2 默认参数

| 参数 | Day | Night |
|---|---|---|
| Wallpaper Visibility | 15%–20% | 15%–20% |
| Blur | 20–30px | 20–30px |
| Overlay | White 80% | Deep Navy 75% |
| Brightness | 95%–110% | 55%–80% |

### 11.3 用户控制

- Upload；
- Replace；
- Remove；
- Opacity；
- Blur；
- Brightness；
- Restore Defaults。

### 11.4 安全与可读性

- Wallpaper 不能成为业务信息来源。
- Main Content 必须保持可读对比。
- 图片只能在 Header 边缘和页面空白处略微显现。
- 用户移除图片后立即恢复主题 Canvas。
- 上传错误、超限或不支持格式时保留当前背景，不产生空白状态。

## 12. Component Library

### 12.1 Button

Variants：

- Primary：高强调确认动作；
- Secondary：普通操作；
- Text：导航或低强调动作；
- Destructive：删除和不可逆动作。

Sizes：

- Standard：36px；
- Large：44px。

States：Default、Hover、Focus、Pressed、Loading、Disabled。

规则：

- Radius 使用 `radius.control`；
- Primary 使用 Ink 填充，不使用亮蓝；
- 同一区域最多一个 Primary Button；
- Loading 不改变按钮宽度；
- Icon 只在含义比文字更清晰时使用。

### 12.2 Card

Variants：

- Action Card；
- Entity Card；
- Empty State Card。

所有变体继承第 9 节 Card 规范。页面不得创建 Metric Card、Glass Card 或任意颜色 Card。

### 12.3 Timeline

用途：Memory Timeline、Interaction History、Account Plan Version History。

结构：

- Time；
- Event Type；
- Title；
- Optional Context；
- Source Link。

Timeline 使用行与 Divider，不使用 Card。事件颜色默认继承 Ink；仅 Event Type 使用 Accent。

### 12.4 Section Header

结构：

- Serif Title；
- Optional Description；
- Optional Text Action；
- Optional Metadata。

Section Header 不能包含大型按钮组、KPI 或 Badge。

### 12.5 Navigation

- 默认无图标；
- Section Label 使用 `type.label`；
- Item 使用 `type.body-sm` 或 `type.control`；
- Active Item 使用 Ink 和一个 4px Accent Dot；
- 不使用整行彩色背景；
- Bottom Profile 与导航之间使用 Divider。

### 12.6 Context Panel

统一名称：Today’s Context。

允许内容：

- Current Customer；
- Current Opportunity；
- Current Capability；
- Editor’s Note；
- Suggested Actions。

Context Panel 不包含聊天记录、Prompt 输入框或长期内容。AI 对话由 Floating AI Entry 打开。

### 12.7 Input

类型：Text、Search、Textarea、Select、Date、File。

States：Default、Hover、Focus、Filled、Error、Disabled、Read-only。

规则：

- Background 使用 Paper；
- Border 使用 Border Token；
- Focus 使用 Accent Border 和低透明度 Focus Ring；
- Error 必须同时提供文字说明，不能只靠颜色；
- Label 始终可见，不以 Placeholder 替代 Label。

### 12.8 Progress

- 默认使用 2px Linear Progress；
- 使用 Accent 作为完成段；
- 必须同时显示 Level 或文字含义；
- 不使用彩色分段、环形进度或游戏化经验值；
- 未知进度使用文字状态，不使用无限循环动画。

### 12.9 Empty State

结构：

- Serif Title；
- 一句解释；
- 一个推荐动作；
- Optional Text Link。

规则：

- 不使用大型插画和五颜六色图标；
- 语言应邀请用户开始记录，不制造错误感；
- Empty State 使用 `divider.empty` 或 Card Border。

### 12.10 Floating AI Entry

- 固定于桌面右下角或移动端安全区上方；
- 使用 Primary 或 Accent 的低调样式；
- 文案优先为 Ask Your Editor；
- 打开 AI Sheet 或 Panel；
- 不持续闪动、脉冲或显示未读红点；
- Level 3 数据处理必须遵守 AI Context Snapshot 规则。

## 13. Motion Specification

| Token | Value | 用途 |
|---|---|---|
| `motion.fast` | 160ms | Focus、Pressed |
| `motion.base` | 220ms | Hover、Menu |
| `motion.theme` | 300–400ms | Theme 颜色变化 |
| `motion.reveal` | 500ms | Scroll Reveal |
| `motion.distance` | 12px | Reveal 起始位移 |
| `motion.easing` | `cubic-bezier(0.22,1,0.36,1)` | 标准缓动 |

允许：

- opacity；
- translateY；
- Border 和 Background 过渡；
- Panel 平缓进入和退出。

禁止：

- Bounce；
- Spring Physics；
- Neon Glow；
- Particle；
- Scan Line；
- 永久循环动画；
- 通过动效制造紧迫或游戏化体验。

`prefers-reduced-motion` 下关闭位移动画，只保留必要的即时状态变化。

## 14. Language System

优先采用个人工作手记语言：

| 避免 | 使用 |
|---|---|
| Dashboard | Home / Today |
| Todo | Today’s Work |
| Recent Activity | Memory Timeline |
| Metrics | Weekly Reflection |
| AI Chatbot | Editor / Companion |
| AI Recommendation | Editor’s Note |
| Database | Collection / Library |
| Record | Note / Entry / Story，必要时使用业务名称 |

业务术语 Customer、Opportunity、Interaction、Account Plan 可保留，不能为了文艺感损害销售专业性。

## 15. Accessibility

- 正文和控制文字满足 WCAG AA 对比度。
- Focus 状态始终可见。
- 交互不能只依靠 Hover。
- 状态不能只使用颜色表达。
- 最小触摸目标 44×44px。
- 键盘顺序遵循视觉和语义顺序。
- Motion 支持 Reduced Motion。
- Wallpaper 设置不能降低内容可读性。
- Serif 不用于小尺寸控制文字和密集表格。

## 16. Design Governance

### 16.1 页面必须

- 使用语义颜色 Token；
- 使用统一 Typography Scale；
- 使用统一 Spacing 和 Radius；
- 使用 Layout Primitive；
- 使用 Divider 和留白分区；
- 复用已定义组件及其状态；
- 同时支持 Day、Night 和 Reduced Motion；
- 在 Desktop、Tablet、Mobile 中保持语义一致。

### 16.2 页面禁止

- 直接使用 Page-specific Hex；
- 创建新间距、圆角、阴影或动画；
- 把普通内容包装为 Card；
- 创建彩色 Badge 集合；
- 创建 Glassmorphism、Neon 或 CRM Dashboard；
- 将 Context Panel 变成常驻聊天窗口；
- 绕过组件状态自行绘制交互控件；
- 用图表和 KPI 填满首屏。

### 16.3 新组件流程

当现有组件无法支持真实业务需求时：

1. 说明无法使用现有组件的原因；
2. 定义新组件职责和使用边界；
3. 定义 Day/Night、Responsive、Accessibility 和所有状态；
4. 更新 Design System 文档；
5. 通过设计评审后，页面才可使用。

## 17. Responsive Component Behavior

| Component | Desktop | Tablet | Mobile |
|---|---|---|---|
| Navigation | 224px Sidebar | 72px / Drawer | Bottom Navigation |
| Context Panel | 248px Right Rail | Context Sheet | Bottom Sheet |
| Card Grid | 2–3 Columns | 2 Columns | 1 Column |
| Timeline | Three-column Row | Three-column Row | Time above content when needed |
| Section Header | Title + right metadata | Same | Stack when width insufficient |
| AI Entry | Bottom-right | Bottom-right | Above Bottom Navigation |
| Input Group | Inline where suitable | Wrap | Vertical |
| Progress | Horizontal | Horizontal | Horizontal |

## 18. Error and Loading Behavior

### 18.1 Loading

- 使用与最终内容相同结构的低对比 Skeleton；
- 不使用全屏 Spinner；
- 页面骨架不能因加载完成发生大幅位移；
- AI 长任务显示安静的文字阶段和取消操作。

### 18.2 Error

- 保留用户已经输入的内容；
- 在发生错误的组件附近说明问题和恢复动作；
- 不使用只包含错误代码的 Toast；
- Level 3 或 AI 安全拦截必须解释“为什么不能处理”和可用替代方案。

### 18.3 Empty and Zero Data

- Empty State 不等同于 Error；
- 实习初期没有客户数据时，Home 自动提高 Learning、Knowledge 和 Reflection 权重；
- 不用零值 KPI 填满页面。

## 19. Design System 验收标准

Design System V2.0 冻结前必须满足：

- Day 和 Night 均有完整语义 Token；
- Typography、Spacing、Radius、Divider 和 Grid 无未定义值；
- 每个组件有职责、结构、状态和边界；
- Desktop、Tablet、Mobile 行为明确；
- Wallpaper 不损害可读性；
- Motion 有 Reduced Motion 策略；
- Loading、Error 和 Empty State 有统一规则；
- 页面能够在不创建新样式的情况下组合出主要业务体验；
- 规范没有 Glassmorphism、Neon、KPI Wall 或传统 CRM Dashboard 倾向。
