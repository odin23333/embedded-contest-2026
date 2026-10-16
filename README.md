# 最新：FAT32文件读取已实板通过（2026-10-16）

读取/MLK_TEST或根目录BMP并沿簇链读取，保留640×480输出、缩放、预加载、渐变、时间戳和应急声画联动。当前卡全部功能实板正常；离线34个FAT32用例与播放器集成通过，原有33项套件本次也重新通过（执行根为MLK_FAT32，相关源码原样同步）。真实碎片卡尚未单独上板验证，Flash和长期运行仍待验收。

# MLK-S200 独立播放器工程

在TD 6.2.1中通过File → Open Project打开根目录fpga_prj.al，确认器件EG4D20EG176、顶层top，执行Run All。源码、IP和ADC/SDC已全部添加，采用相对路径；解压后保留完整目录，可放到短英文路径。

包含TF图片按比例缩放（HDMI固定640×480）、下一张预加载、渐暗渐亮、真实HH:MM:SS、应急中文画面/声音同步闪烁和静音恢复。支持底向上、无压缩24位BMP，宽高1–2048，最多四张FAT32目录BMP图片（支持碎片簇链）；采用最近邻缩放。

KEY1下一张，KEY2自动轮播，KEY3应急切换，KEY4静音，KEY16复位。首次读卡和未缓存图片仍需加载；换卡后复位。将BMP普通复制到FAT32卡的MLK_TEST文件夹；文件夹不存在时读取根目录。支持碎片文件和目录，最多读取目录顺序前四张图。修改卡内容后重新插卡并KEY16复位，详细范围见uisrc/06_doc/FAT32读取说明.md。原始及混合尺寸素材分别在uisrc/02_sim/media和mixed_resolution。

uisrc/05_boot/MLK_S200_TESTED.bit为用户实际验证通过的FAT32实测版（610de0e1…），原缩放版保留为MLK_S200_SCALING_ROLLBACK.bit。编译生成的fpga_prj_Runs/phy_1/fpga_prj.bit是新构建，仅经离线验证，不可称已通过实板验证。BitWriter选择EG4D20EG176、PROGRAM_SRAM，实测固件下载，OneCable使用接口A WinUSB和AL-LINK-FT(Local Host)。不自动写Flash。

scripts/tool_paths.json仅配置自动化依赖路径，更换电脑时修改tool_root/python；直接在TD打开.al无需修改该JSON。scripts/sync_clock.ps1可配合串口校时。长期运行、Flash固化、断电启动和RTC电池保持仍待实测。历史33播放器套件记录包含未在此版本全量重跑的结果，具体范围见06_doc；独立打包后编译和精选测试另存reports。


2026-10-14 独立目录从零构建通过：SWNS 0.549 ns，HWNS 0.003 ns；仅有两条继承的DDR PHY-7002位置提示。源码输入哈希保持不变。独立包新增缩放逐像素、异常BMP、真实FIFO启动三项测试全部通过；历史全量结果未重跑。自动化：python scripts/build.py；python scripts/test.py。


FAT32复现：python scripts/fat32_tests.py；包含34个文件系统用例和实际存储控制集成。python scripts/test.py运行原精选三项加完整FAT32测试；加--storage-only则原精选三项加FAT32存储集成。只生成reports下虚拟扇区文件，不操作真实磁盘。后文2026-10-14编译证据为历史；最新构建见reports/standalone_build.json。
