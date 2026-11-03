# MLK-S200 FPGA 图片播放器

## 2026-11-03 整合固件更新

最新整合固件：[MLK_PLAYER_MEDIA_COMPLETE_CANDIDATE.bit](uisrc/05_boot/media_complete_20261103/MLK_PLAYER_MEDIA_COMPLETE_CANDIDATE.bit)，用于 MLK-S200 / EG4D20EG176，TD 6.2.1、640×480。

包含视频进度、坏文件跳过、统一界面和四项设置断电保存，以及此前的浏览/视频/缩放/预加载等整合功能。2026-11-03 已下载 SRAM 并完成部分实板验收；原稳定 Flash 固件保留。

- [本轮实板验收汇总](uisrc/06_doc/media_complete_20261103/本轮验收汇总.md)
- [功能与操作说明](uisrc/06_doc/media_complete_20261103/功能与操作说明.md)
- [固件哈希](uisrc/05_boot/media_complete_20261103/SHA256SUMS.txt) · [版本信息](uisrc/05_boot/media_complete_20261103/release.json)

KEY15 重播存在短暂黑屏后自行恢复的体验限制；坏文件测试由用户跳过，长时测试和新固件 Flash 独立启动待测。请先使用 PROGRAM_SRAM / 5MHz 验证，不将部分验收视为全部通过。

**本次仅提交固件及验收材料；根目录 fpga_prj.al 和源码仍对应下文的画质基线，不能用它们复现这份整合固件。** 新固件的编译输入哈希和构建结果保存在同目录 build.json；未覆盖 MLK_S200_TESTED.bit 或其他回退固件。

---

米联客MLK-S200 / EG4D20EG176，板载25MHz输入，TD6.2.1。按米联客教程组织为独立工程，根目录 `fpga_prj.al` 使用相对路径；保持完整目录，可放在短英文路径重新打开编译。

## 当前功能

- FAT32目录与簇链读取：优先MLK_TEST文件夹，否则根目录，按目录顺序最多四张BMP。
- 支持1–2048宽高、底向上24位无压缩BMP，双线性等比例缩放、居中黑边；HDMI固定640×480。640×480原尺寸像素保持一致。
- 下一张预加载、渐暗渐亮、手动/自动轮播、图片编号/缓存反馈和真实HH:MM:SS。
- 应急中文、警报声画同步闪烁、静音恢复、错误码及按键重试。

KEY1下一张，KEY2轮播，KEY3应急，KEY4静音，KEY6重试，KEY16整机复位。将BMP普通复制到FAT32卡即可，换卡或改文件后按KEY6。首次或未缓存图片仍可能等待；不支持JPEG/PNG、压缩BMP或负高度BMP。

## 固件与 Flash 状态

`uisrc/05_boot/MLK_S200_TESTED.bit` 是用户实板通过且已Flash固化、自动回读校验通过的画质版，SHA256：`5605e066181803426239a70b37efe6d4e6a66fb787dba26c2708596709f3dda2`。

BitWriter设置：EG4D20EG176、PROGRAM_FLASH、5MHz、16Mbits。固化步骤、日志和RTC情况见 [Flash固化与时钟说明](uisrc/06_doc/Flash固化与时钟说明.md)。PROGRAM_SRAM仍可用于临时验证。

断电后RTC曾显示--:--:--，校时后显示正确、秒数递增。CR1220电池未安装或不确定，断电保时尚未验证；没有有效后备电池时，完全掉电后可能需重新校时。其余冷启动功能、10次重启及长期运行尚未完整验收。

`MLK_S200_REBUILT.bit` 是独立工程复编产物，未替代实测固件；`MLK_S200_FEEDBACK_ROLLBACK.bit` 是上一已实测版本。可选亮度扩展与新画质组合布线失败，未发布可用的新亮度固件；默认播放器未启用该扩展。

## 打开与复现

在TD6.2.1选择File → Open Project打开 `fpga_prj.al`，确认器件EG4D20EG176及顶层top，执行Run All。直接GUI编译不依赖Python；自动化工具路径由 `scripts/tool_paths.json` 配置。

```text
python scripts/build.py
python scripts/test.py --unit-only
python scripts/quality_tests.py
python scripts/fat32_tests.py
```

独立工程默认复编与时序通过：SWNS0.209ns/HWNS0.003ns；存在继承的DDR PHY-7002位置提示，详见reports/standalone_build.json。最近补跑7项选测及默认双线性7×5整帧核对通过。画质任务共有20项新跑播放器套件、23项历史记录，共43项；11尺寸完整像素对照及34个FAT用例另有明细，不能称全部记录都是本次重新执行。此次Flash记录整合未修改RTL、引脚、时序约束或固件，没有重新编译。

串口校时使用 `scripts/sync_clock.ps1`，本机接口B为COM4。源码/IP/仿真/约束/固件/文档分别在uisrc的01_rtl至06_doc。完整开发历史见 [当前开发进度](uisrc/06_doc/当前开发进度.md)，画质范围见 [缩放画质优化](uisrc/06_doc/缩放画质优化.md)。冻结W7_RC2及week8归档保持不变。
