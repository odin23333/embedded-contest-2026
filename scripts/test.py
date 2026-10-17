from pathlib import Path
import subprocess,json
root=Path(__file__).resolve().parents[1];cfg=json.loads((root/'scripts/tool_paths.json').read_text());tools=Path(cfg['tool_root']);report=root/'reports'
rtl=root/'uisrc/01_rtl';ip=root/'uisrc/03_ip/generated';tb=root/'uisrc/02_sim/tb';fixture=root/'uisrc/02_sim/fixtures'
suites={'scaled_bmp_tb':[rtl/'SD/bmp_scaled_read.v'],'scaled_fault_tb':[rtl/'SD/bmp_scaled_read.v'],'write_start_tb':[rtl/'SD/frame_read_write.v',rtl/'SD/frame_fifo_write.v',rtl/'SD/frame_fifo_read.v',ip/'afifo_16_32_256.v',ip/'afifo_32_16_256.v']}
suites['error_recovery_tb']=[rtl/'control/error_recovery.v']
suites['playback_feedback_tb']=[rtl/'control/playback_scheduler.v',rtl/'control/playback_osd.v']
suites['quality_fifo_tb']=suites['write_start_tb']
suites['quality_osd_tb']=[rtl/'control/error_recovery.v']
results=[]
for name,files in suites.items():
    out=report/(name+'.vvp')
    p=subprocess.run([str(tools/'iverilog/bin/iverilog.exe'),'-B',str(tools/'iverilog/lib/ivl'),'-g2012','-Wall','-I',str(rtl/'SD'),'-s',name,'-o',str(out),*[str(f) for f in files],str(tb/(name+'.v'))],cwd=(report if name in ['error_recovery_tb','playback_feedback_tb'] else fixture),capture_output=True,text=True,creationflags=0x08000000)
    (report/(name+'_compile.log')).write_text(p.stdout+p.stderr)
    assert p.returncode==0,name
    p=subprocess.run([str(tools/'iverilog/bin/vvp.exe'),'-M','-',str(out)],cwd=(report if name in ['error_recovery_tb','playback_feedback_tb'] else fixture),capture_output=True,text=True,creationflags=0x08000000,timeout=180)
    (report/(name+'_simulation.log')).write_text(p.stdout+p.stderr)
    assert p.returncode==0 and 'PASS ' in p.stdout,name
    results.append({'test':name,'result':'PASS','scope':'fresh independent package source'})
    print(p.stdout.strip(),flush=True)
(report/'standalone_tests.json').write_text(json.dumps(results,indent=2))

# Default-quality pixel smoke uses its independent generated oracle.
import sys
p=subprocess.run([sys.executable,str(root/'scripts/quality_tests.py'),'--quick'],cwd=root,creationflags=0x08000000)
if p.returncode:raise SystemExit(p.returncode)
if '--unit-only' in sys.argv:raise SystemExit(0)

# FAT32 fixtures are generated locally; no real TF card or raw disk is accessed.
args=[sys.executable,str(root/'scripts/fat32_tests.py')]
if '--storage-only' in sys.argv:args+=['--storage-only']
p=subprocess.run(args,cwd=root,creationflags=0x08000000)
if p.returncode:raise SystemExit(p.returncode)
