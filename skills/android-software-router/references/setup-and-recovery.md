# Android Software Router：配置与排障

本流程面向满足兼容条件的 Android 设备。Android 提供热点地址分配、NAT 和路由，Shizzi 与 FlClash 使热点客户端的流量进入 VPN 处理链路，构成无需刷机的轻量软路由。它不承诺完整 OpenWrt 功能，也不意味着所有型号、系统或协议已测试。

## 兼容条件

- **本流程的固定版本基线**：Android 13+、arm64，Shizuku 13.6.0、Shizzi 0.4.0-rc.3、FlClash 0.8.99。真实验收设备是 Android 14 / ColorOS 14 的 OPPO A97；此处的范围是部署前提，不是每个组合的通过清单。
- Shizzi 兼容性页的 **Test network API / Prefer test networks** 均须支持；Shizuku 获得实际可用的 shell 权限。
- Wi-Fi 中继额外需要系统支持 Wi-Fi 客户端与热点同时运行。仅 SIM 共享不依赖这项并发能力。
- 新版 Shizzi 主分支可能声明更宽的 Android 版本范围；更换版本时必须检查对应发布标签、安装包 ABI、模块要求和本机兼容性，不把新版说明直接套到固定版本。Shizuku 的 Android 11+ 无线配对条件也不等于整套软路由只需 Android 11。
- 厂商权限开关、后台策略和调试行为可能不同。以下 ColorOS 项是案例经验，其他系统按实际提示处理，不照搬开关名称或方向。

## 首次建立方案

先读当前设备和已装版本，复用可用设置。以下为 2026-10-11 的成功基线；重新下载时以官方仓库核查版本与兼容性，不为“最新”而自动替换已有成功组合。

1. **组件来源**：官方 [Shizuku](https://github.com/RikkaApps/Shizuku/releases)、[Shizzi](https://github.com/carlelieser/shizzi/releases)、[FlClash](https://github.com/chen08209/FlClash/releases)。核对包名、ABI、APK 签名和发布方提供的摘要；没有官方摘要不能说完成了发布摘要比对。版本基线和原文件哈希见实测记录。
2. **Shizuku 权限**：免 Root 通过无线调试或 USB ADB 启动为 shell UID 2000。检查应用是否显示权限受限，而不仅是有服务进程。
3. **厂商权限限制（按需处理）**：出现权限受限时再查对应 ROM 的官方说明。ColorOS 本案界面是“禁止权限监控”，需要把这个开关打开。官方文档写“关闭权限监控”，两者语义相同；读取实际文案，不能把开关方向写反。其他系统不必寻找同名开关。保持开发者选项和 USB 调试开启。
4. **Shizzi**：授予 Shizuku 使用权限、通知和后台运行权限；检查 Test network API、Prefer test networks 均支持；将其 VPN 设置从 Auto 改为 Always，并读回确认。
5. **FlClash**：用户自行导入订阅，不要求将订阅发到对话。启动后确认真实 VPN 已连接。检查分应用设置有没有排除承载热点转发的 UID，原案全部主用户 UID 被 VPN 覆盖。保持原有规则策略，不能把“分享代理”擅自改成全局代理。
6. **后台与 USB**：允许必要组件后台运行；本案 Shizzi、FlClash 忽略电池优化。若 ROM 受 USB 模式切换影响，参考官方说明把默认 USB 配置设为“不用于数据传输 / 仅充电”。A97 本案从文件传输改为该模式时 Shizuku 停过，变更后重新检查和启动；运行稳定的其他设备不为复现案例反复切换模式。
7. **启动及验收**：FlClash VPN 已连接后，在 Shizzi 点 Start，查看 Connected / VPN CONNECTED / TUNNEL ACTIVE，再验收独立客户端。

原案没有修改硬件共享卸载开关，`tether_offload_disabled` 保持未设置（null）。不要把别的 Root 热点教程里的 offload、iptables、私有 DNS 或系统 VPN 全局设置当作本方案必需修改。

## 手机自身无线启动：首选

官方 Shizuku 的本机无线配对需要 Android 11+；整套方案仍按上面的兼容条件检查。本案验证组合是 Android 14 + 官方 Shizuku 13.6。先确认服务是否已运行，已经运行时无须为了无线配对重启服务。

首次配对：

1. 目标手机连接一个 Wi-Fi 或另一部手机的热点。目标手机自己提供热点不等于连接外部 Wi-Fi。
2. 在 Shizuku 进入“通过无线调试启动 → 配对”，按引导进入系统“无线调试”。开发者选项、USB 调试和无线调试开启。
3. 系统询问网络授权时，用户选择“始终允许此网络”。Wi-Fi 密码已保存不等于已允许该网络调试。
4. 在系统无线调试页选择“使用配对码配对设备”；从 Shizuku 通知输入六位码。返回 Shizuku 点“启动”，确认服务运行及权限正常。电脑曾获 USB 授权不等于 Shizuku 自己的密钥已配对。

再次启动：连接已授权 Wi-Fi，打开 Shizuku 点“启动”。13.6 在取得 `WRITE_SECURE_SETTINGS` 后可以自行打开无线调试；该权限由已运行的服务尝试授予管理端，先核实实际状态，不默认再加手动授权脚本。若搜索不到服务，才检查网络授权、通知/后台权限和无线调试开关。

服务成功后可断开辅助 Wi-Fi，目标手机转为自己的 SIM 上网；保留 USB 调试开关，无需数据线。**本案用户已在 A97 确认该过程不会使 Shizuku 停止，热点下游仍可访问外网。**新设备或固件变更后按该步骤验证，不把案例成功作为所有 Android 设备的保证。

Shizuku 通过独立进程运行，无需一直保留 ADB 客户端连接。Android 14 AOSP 只有 USB 和无线调试均关闭时才停止整个 adbd；OEM 行为仍可能不同。不要把旧式 `adb tcpip`（切换会重启 adbd）与 Android 11+ 的配对式无线调试混为一谈。

## 开机恢复与实际边界

- 手机重启后 Shizuku 需要重新启动；满足条件时可自动完成，否则用上述无线启动，不要求一定接电脑。
- 官方 13.6 的开机尝试要求 Android 13+、主用户、上次为 ADB 启动、必要设置权限和已配对密钥、可用可信 WLAN。源码中的发现等待窗口约 3 秒；它不是“任何时刻稍后连上 Wi-Fi 必然自动启动”的持续守护程序。
- 13.6 中文 UI 的开机启动文案可能仍带“root”，但该开关对应的接收器已有上述无 Root 分支。需要配置时按版本核实，不依据旧文案下结论。
- **A97 的开机自动启动尚无本案验收证据**。不要把用户说“其余流程相同”理解成他测试过手机重启、自动开启 VPN 和热点。
- 户外冷启动且没有任何辅助 Wi-Fi：当前官方流程未解决。ShizukuPlus 的 TCP 保活要求已有可用 ADB 监听；LADB / Termux 增加客户端不自动越过系统限制。Shizuku-Next 有依赖平台竞态的实验实现，但没有本案 A97 验证，不替换已经可用的官方版。

## 症状 → 处理

若用户已经手动开启普通系统热点并出现直连：先读取 Shizzi 当前状态；如仍显示旧会话运行，先在 Shizzi 点 Stop。再关闭仍然开启的普通系统热点，确认 FlClash VPN 正常后在 Shizzi 点 Start，读回隧道和上游状态。这次恢复会短暂断开客户端；不要在已有旧会话时机械重复点 Start。

| 观察 | 先检查 / 处理 | 不应作出的判断或操作 |
| --- | --- | --- |
| ADB 检测不到手机 | 插线、保持解锁、允许当前电脑 USB 调试；明确使用 USB 还是本机无线流程 | 不把“没插线”诊断成无线方案失败 |
| Shizuku 正在运行但权限受限 | 按实际 ROM 检查额外调试权限；ColorOS 案例检查“禁止权限监控”是否开启，重新查看提示 | 不仅凭 PID 宣布成功，不要求其他 ROM 存在同名开关 |
| Shizzi 提示未授权或 API 不支持 | Shizuku 状态、Shizzi 授权、两个兼容性检测项 | 不直接切 Root 或套别机型结果 |
| 手机本身能访问，热点客户端不能 | Shizzi 状态、热点实际上游、VPN 覆盖的 UID、客户端是否隔离自身网络 | 不让客户端安装代理掩盖透明共享失败 |
| 停 VPN 后热点关了 | 先恢复 FlClash，再 Shizzi Start | 不直接重开系统“个人热点” |
| 重开热点后出口为本地直连 | 查是否人工打开系统热点绕过 Shizzi；核对目标规则与当前出口 | 不未经排查便称为 Shizzi 自动回退直连 |
| USB 模式切换后服务停了 | 默认不用于数据传输、调试开关仍开；重新激活并检查权限 | 不反复切 USB 模式或因此重新安装 |
| 无线启动后关 Wi-Fi 导致另一台设备上的 Shizuku 停止 | 保留 USB 调试、核实是 Wi-Fi 关闭还是调试关闭，核对 OEM / 版本及 adbd 是否重启 | 不把 A97 成功结论当成所有设备保证 |
| trace 页面不知道怎么看 | 让用户在测试客户端浏览器地址栏打开完整链接，找到纯文字中的 `ip=` / `loc=` | 不要求用户提供订阅或无关私人页面 |

## 工具观察与 UI 操作

仅在设备已可访问且任务需要时使用 ADB。读取当前型号和包版本；网络诊断可以有针对性地读取 `dumpsys connectivity`、`dumpsys tethering`，检查 VPN 的 CELLULAR/WIFI 上游、当前测试隧道及热点转发统计。这些输出可含网络标识，应提取必要字段，分享前去除标识。

通用操作原则与 A97 案例中的界面问题：

- **顺序执行 UI 修改**：一次打开页面、刷新 UI、按当前包名和唯一文案定位，再点击并读回。不要并发点击，不复用旧页面坐标。工作区历史 `phone_ui.py` / `phone_tap.py` 内嵌设备标识，不可原样移植。
- ColorOS 通用开发者设置 intent 曾停留在错误页面。必要时可用已确认组件 `com.android.settings/.Settings$DevelopmentSettingsDashboardActivity`，调用时保护 `$` 不被 PowerShell 展开；新 ROM 先核实组件。
- 本案 shell 执行 `cmd wifi stop-softap` 因缺少 `MAINLINE_NETWORK_STACK` 失败。改用当前 UI 的热点开关完成已授权停止操作，不为这一步获取额外系统权限。
- 热点设置 UI 可能直接展示密码；不要输出原始页面全文或把此类截图收入经验包。

## Windows USB 备用脚本

提供 `scripts/Start-Android-Shizuku.ps1` 和 `.cmd`，CMD 调用 PS1 并停留显示结果。脚本没有内嵌个人设备序列号或账号，不再限定 OPPO 型号。它只启动官方 Shizuku，不能替代 Shizzi 兼容检查与下游验收。

- 默认先查找 `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`，再从 `PATH` 查找 `adb`；安装位置不同可通过 `-AdbPath` 显式提供。
- 只有一个无歧义的已授权目标时可以省略 `-Serial`；存在多个设备时必须用 `-Serial` 指定目标。没有可用目标或目标未授权时停止，不按发现顺序随意选取。
- 读取目标设备与官方 `moe.shizuku.privileged.api` 包信息。服务已运行时，只读取 PID 并跳过启动器定位与执行；服务未运行时，通过实际 `nativeLibraryDir` 或 `legacyNativeLibraryDir` 定位 `libshizuku.so`，检查启动器可访问和执行权限，不写死 APK 的随机安装目录或手机型号。
- 脚本的 Android API 23+ 检查仅针对 Shizuku 启动器；完整软路由方案仍按 Android 13+ / arm64 基线与 Shizzi 兼容性判断。
- `-CheckOnly` 只检查设备、包和服务状态；仅服务未运行时检查启动器。它不改变手机设置、不启动 Shizuku。
- 正常调用在服务已运行时直接跳过启动，在服务未运行时才执行启动器；**仅在用户任务已包含启动操作时调用**。之后检查服务 PID，但仍需在手机上查看权限提示并验收热点。
- 不自动安装、导入订阅、启动 VPN 或开启热点。包或启动器布局不能可靠识别时停止并重新核查官方启动方式，不猜路径。更广的型号与 ABI 支持属于通用化实现，仍需在目标设备验收。

PowerShell 使用示例（设备标识和路径由当前环境提供）：

```powershell
.\scripts\Start-Android-Shizuku.ps1 -CheckOnly
.\scripts\Start-Android-Shizuku.ps1 -Serial '<目标设备标识>' -CheckOnly
.\scripts\Start-Android-Shizuku.ps1 -Serial '<目标设备标识>' -AdbPath 'C:\Android\platform-tools\adb.exe'
```

前两条仅检查；最后一条会按需启动 Shizuku。不要把示例占位符作为实际设备标识。

## 停用与回滚

仅在用户要求撤销时执行：先停止 Shizzi，再停止 FlClash；卸载前保留用户需要的订阅资料。只撤销本次实际修改的权限和 USB 默认模式；原案“禁止权限监控”原为关闭。不要把卸载、清应用数据或回滚设为普通排障的第一步。

## 一手资料

- [Android Tethering 模块](https://source.android.com/docs/core/ota/modular-system/tethering)：地址分配、NAT 与热点转发职责。
- [Shizzi 项目](https://github.com/carlelieser/shizzi)与[本案固定版本](https://github.com/carlelieser/shizzi/releases/tag/v0.4.0-rc.3)：核对测试网络、转发方式及对应版本兼容性。
- [官方配对和 ColorOS / USB 设置说明](https://shizuku.rikka.app/zh-hans/guide/setup/)：页面较旧，开机能力以对应版本发行说明和源码为准。
- [Shizuku 13.6 发布说明](https://github.com/RikkaApps/Shizuku/releases/tag/v13.6.0)
- [13.6 无线启动按钮](https://github.com/RikkaApps/Shizuku/blob/v13.6.0/manager/src/main/java/moe/shizuku/manager/home/AdbDialogFragment.kt)
- [13.6 开机接收器](https://github.com/RikkaApps/Shizuku/blob/v13.6.0/manager/src/main/java/moe/shizuku/manager/receiver/BootCompleteReceiver.kt)
- [13.6 服务进程启动实现](https://github.com/RikkaApps/Shizuku/blob/v13.6.0/manager/src/main/jni/starter.cpp)
- [Android 14 ADB 服务开关](https://github.com/aosp-mirror/platform_frameworks_base/blob/android14-release/services/core/java/com/android/server/adb/AdbService.java)
- [维护者区分旧 TCP 与配对式无线调试](https://github.com/RikkaApps/Shizuku/issues/311#issuecomment-1584588951)
- [Next 实验实现，固定到已研究提交](https://github.com/rushiranpise/Shizuku-Next/blob/1206714f73db0f52dd345164f88a1e8a532c2892/manager/src/main/java/moe/shizuku/manager/start/ForcedWirelessDebugging.kt)：只作边界参考，不是本案部署组件。
