from pathlib import Path
import subprocess,json,re,hashlib,shutil,sys,time
root=Path(__file__).resolve().parents[1];report=root/'reports'
cfg=json.loads((root/'scripts/tool_paths.json').read_text());td=Path(cfg['tool_root'])/'TD_6.2.1/bin/td_commands_prompt.exe'
def inputs():
    al=root/'fpga_prj.al'
    paths=[al]+[root/p for p in re.findall(r'<File Path="([^"]+)"',al.read_text())]
    paths+=list((root/'scripts').glob('*.cfg'))+[root/'scripts/td_flow.tcl']+list((root/'uisrc/03_ip').rglob('*.tcl'))
    return {p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
def build():
    before=inputs();start=time.time();logs=[]
    for stage in ['syn_1','phy_1']:
        run=root/'fpga_prj_Runs'/stage;run.mkdir(parents=True,exist_ok=True)
        text=(root/'fpga_prj.al').read_text()
        text=re.sub(r'(<File Path=")([^"]+)',lambda m:m[1]+'../../'+m[2],text)
        (run/'fpga_prj.prj').write_text(text,encoding='utf-8')
        shutil.copy2(root/'scripts/td_flow.tcl',run/'fpga_prj.tcl')
        shutil.copy2(root/'scripts'/f'{stage}.cfg',run/'settings.cfg')
        code='cd {'+run.as_posix()+'}\nif {[catch {source fpga_prj.tcl} result]} {puts stderr $result;exit 1}\nexit\n'
        p=subprocess.run([str(td)],input=code,capture_output=True,text=True,encoding='utf-8',errors='replace',creationflags=0x08000000,timeout=600)
        log=p.stdout+'\n'+p.stderr;logs.append(log);(report/f'{stage}.log').write_text(log,encoding='utf-8')
        if p.returncode or re.search(r'\bERROR:',log):raise RuntimeError('Build failed, see reports/'+stage+'.log')
    bit=root/'fpga_prj_Runs/phy_1/fpga_prj.bit';timing=bit.with_name('fpga_prj_pr.timing').read_text(errors='replace')
    info={'device':'EG4D20EG176','top':'top','fresh_bit':bit.stat().st_mtime>=start,'inputs_unchanged':before==inputs(),'input_hashes':before,'sha256':hashlib.sha256(bit.read_bytes()).hexdigest(),'critical_warnings':re.findall(r'^.*CRITICAL-WARNING:.*$', '\n'.join(logs),re.M),'physically_downloaded':False}
    for k in ['SWNS','HWNS']:info[k]=float(re.search(k+r':\s*([-\d.]+)ns',timing)[1])
    info['timing_pass']=info['SWNS']>=0 and info['HWNS']>=0
    assert info['timing_pass'] and info['fresh_bit'] and info['inputs_unchanged']
    assert all('PHY-7002' in w and 'u_ddr_sdram location' in w for w in info['critical_warnings'])
    shutil.copy2(bit,root/'uisrc/05_boot/MLK_S200_REBUILT.bit')
    (report/'standalone_build.json').write_text(json.dumps(info,indent=2))
    print(json.dumps({k:v for k,v in info.items() if k!='input_hashes'},indent=2))
if __name__=='__main__':build()
