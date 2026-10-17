from pathlib import Path
import json,subprocess,sys,struct
root=Path(__file__).resolve().parents[1];report=root/'reports';tools=Path(json.loads((root/'scripts/tool_paths.json').read_text(encoding='utf-8'))['tool_root'])/'iverilog'
hdl=(root/'project/user_source/hdl_source/SD') if (root/'project').exists() else (root/'uisrc/01_rtl/SD');tb=(root/'tb') if (root/'tb').exists() else (root/'uisrc/02_sim/tb')
def coordinates(i,source,dest):
 n=(2*i+1)*source-dest;den=2*dest
 if n<=0:return 0,0,0
 a,rem=divmod(n,den)
 if a>=source-1:return source-1,source-1,0
 return a,a+1,(rem*256)//den

def sample(x,y):return ((x*17+y*5)&255,(x*3+y*23)&255,(x*11+y*7)&255)

def expected(w,h):
 if w*480>=h*640:fw,fh=640,max(1,h*640//w)
 else:fw,fh=max(1,w*480//h),480
 left,bottom=(640-fw)//2,(480-fh)//2
 xs=[coordinates(i,w,fw) for i in range(fw)];ys=[coordinates(i,h,fh) for i in range(fh)]
 out=[]
 for y in range(480):
  for x in range(640):
   if left<=x<left+fw and bottom<=y<bottom+fh:
    x0,x1,fx=xs[x-left];y0,y1,fy=ys[y-bottom]
    a,b,c,d=sample(x0,y0),sample(x1,y0),sample(x0,y1),sample(x1,y1)
    rgb=[]
    for ch in range(3):
     lo=(a[ch]*(256-fx)+b[ch]*fx+128)//256
     hi=(c[ch]*(256-fx)+d[ch]*fx+128)//256
     rgb.append((lo*(256-fy)+hi*fy+128)//256)
    out.append(''.join(f'{v:02x}' for v in rgb)+'\n')
   else:out.append('000000\n')
 return ''.join(out)

def bmp(w,h):
 stride=(w*3+3)&~3;raw=bytearray()
 for y in range(h):
  for x in range(w):raw.extend(sample(x,y)[::-1])
  raw.extend(b'\xa5'*(stride-w*3))
 return struct.pack('<2sIHHI',b'BM',54+len(raw),0,0,54)+struct.pack('<IiiHHIIiiII',40,w,h,1,24,0,len(raw),0,0,0,0)+raw
out=report/'quality_scaled_tb.vvp'
cmd=[str(tools/'bin/iverilog.exe'),'-B',str(tools/'lib/ivl'),'-g2012','-Wall','-s','quality_scaled_tb','-o',str(out),str(hdl/'bmp_scaled_read.v'),str(tb/'quality_scaled_tb.v')]
p=subprocess.run(cmd,capture_output=True,text=True,creationflags=0x08000000);(report/'quality_compile.log').write_text(p.stdout+p.stderr);assert p.returncode==0,p.stderr
sizes=[(7,5)] if '--quick' in sys.argv else [(7,5),(320,240),(800,300),(301,601),(640,480),(1280,720),(1,2048),(2048,1),(2,2),(1920,1080),(2048,2048)]
if '--large-only' in sys.argv:sizes=[(1920,1080),(2048,2048)]
def check_size(pair):
 w,h=pair
 folder=report/f'quality_{w}x{h}';folder.mkdir(exist_ok=True)
 data=bmp(w,h);data+=b'\0'*((-len(data))%512)
 (folder/'card.hex').write_text(''.join(f'{v:02x}\n' for v in data));(folder/'expected.hex').write_text(expected(w,h))
 cmd=[str(tools/'bin/vvp.exe'),'-M','-',str(out),'+CARD='+str(folder/'card.hex'),'+EXPECT='+str(folder/'expected.hex'),'+SIZE='+str(len(data))]
 p=subprocess.run(cmd,cwd=report,capture_output=True,text=True,creationflags=0x08000000,timeout=600)
 (folder/'simulation.log').write_text(p.stdout+p.stderr)
 ok=p.returncode==0 and 'PASS ' in p.stdout;result=dict(size=[w,h],result='PASS' if ok else 'FAIL',pixels=307200)
 print(f'{w}x{h}: '+p.stdout.strip(),flush=True)
 return result
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(check_size,sizes))
if '--large-only' in sys.argv:
 old=json.loads((report/'quality_tests.json').read_text());done={tuple(x['size']) for x in results};results=[x for x in old if tuple(x['size']) not in done]+results
(report/'quality_tests.json').write_text(json.dumps(results,indent=2))
assert all(x['result']=='PASS' for x in results),results
print('PASS QUALITY_MATRIX: '+str(len(results))+' exact full-frame pixel cases',flush=True)
