# MLK-S200 独立播放器工程

在TD 6.2.1中通过File → Open Project打开根目录fpga_prj.al，确认器件EG4D20EG176、顶层top，执行Run All。源码、IP和ADC/SDC已全部添加，采用相对路径；解压后保留完整目录，可放到短英文路径。

包含TF图片按比例缩放（HDMI固定640×480）、下一张预加载、渐暗渐亮、真实HH:MM:SS、应急中文画面/声音同步闪烁和静音恢复。支持底向上、无压缩24位BMP，宽高1–2048，最多四张连续扇区图片；采用最近邻缩放。

KEY1下一张，KEY2自动轮播，KEY3应急切换，KEY4静音，KEY16复位。首次读卡和未缓存图片仍需加载；换卡后复位。TF测试素材位于uisrc/02_sim/media，当前实板混合尺寸卡保持现状即可；普通拷贝造成文件碎片时原始扇区扫描不保证读取，尚未实现FAT目录解析。

uisrc/05_boot/MLK_S200_TESTED.bit为用户实际验证通过的缩放保护版（1b076ea0…）。编译生成的fpga_prj_Runs/phy_1/fpga_prj.bit是新构建，仅经离线验证，不可称已通过实板验证。BitWriter选择EG4D20EG176、PROGRAM_SRAM，实测固件下载，OneCable使用接口A WinUSB和AL-LINK-FT(Local Host)。不自动写Flash。

scripts/tool_paths.json仅配置自动化依赖路径，更换电脑时修改tool_root/python；直接在TD打开.al无需修改该JSON。scripts/sync_clock.ps1可配合串口校时。长期运行、Flash固化、断电启动和RTC电池保持仍待实测。历史33播放器套件记录包含未在此版本全量重跑的结果，具体范围见06_doc；独立打包后编译和精选测试另存reports。


2026-10-14 独立目录从零构建通过：SWNS 0.549 ns，HWNS 0.003 ns；仅有两条继承的DDR PHY-7002位置提示。源码输入哈希保持不变。独立包新增缩放逐像素、异常BMP、真实FIFO启动三项测试全部通过；历史全量结果未重跑。自动化：python scripts/build.py；python scripts/test.py。
