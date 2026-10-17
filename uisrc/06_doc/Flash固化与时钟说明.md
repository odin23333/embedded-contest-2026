# Flash 固化与时钟说明

2026-10-17 已将实测画质固件固化到 MLK-S200：EG4D20EG176，PROGRAM_FLASH，5MHz，16Mbits。硬件手册和原理图标明 W25Q16DVSN；实际读取厂商标识 EF。写入和自动回读校验通过，PROGRAM_FLASH success，100%，总耗时169.607018秒。

固件：`uisrc/05_boot/MLK_S200_TESTED.bit`，SHA256：`5605e066181803426239a70b37efe6d4e6a66fb787dba26c2708596709f3dda2`。重编译文件 `MLK_S200_REBUILT.bit` 仅是离线构建证据。上一已实测版 `MLK_S200_FEEDBACK_ROLLBACK.bit` 保留供回退。

## 再次固化步骤

1. 在 TD6.2.1 的 BitWriter 中连接 OneCable / AL-LINK-FT(Local Host)，核对器件 EG4D20EG176。
2. 添加并仅选中上述 TESTED.bit；选择 PROGRAM_FLASH、5MHz、16Mbits。容量不能沿用界面默认128Mbits。
3. Run 后保持供电和下载线连接，等待写入及自动校验完成，确认成功日志及100%。这会替换板上的启动程序。无需另外转换或重命名镜像。
4. 完成后断开全部电源和可能供电的 USB/JTAG，等指示灯全部熄灭约5秒，保留TF和HDMI，再接正常电源；不执行JTAG下载，检查自动启动和各功能。

## RTC 断电保持限制

本次断电重启后时间显示 `--:--:--`。用户表示CR1220电池没有安装或不确定；重新通过COM4校时至北京时间12:57:34，RTC回复4B成功，用户确认时间正确且秒数递增。读写及显示已恢复，现象符合缺少后备电源时的断电丢时；未实测电池安装、电压或保时能力，不能判定电池损坏。

需要真实时间在断电后保持时，应在断电状态核对板上电池座和极性标识，安装匹配CR1220电池，再上电校时一次并断电复验。未安装有效后备电池时，完全掉电后可能需要重新校时。当前不会用编译时间或开机运行时长冒充真实时间，也不会在启动时写入过期的固定时间。

校时：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/sync_clock.ps1 -Port COM4`。连接OneCable接口B并核对当前串口号；此操作仅写RTC，不重烧Flash。COM4是本机实测端口，更换电脑可能不同。

Flash写入/校验已通过；RTC校时后的显示恢复已通过。电池断电保持、其余冷启动功能的逐项检查、10次重启和连续两小时运行仍未完整验收。用户接受当前电池限制，不等于这些项目已实测通过。

详细证据：`flash_summary.json`、`quality_flash_download.log`、`cold_boot_clock_calibration.json`。日志中的原执行路径作为历史证据保留，独立工程的构建不依赖那些绝对路径。
