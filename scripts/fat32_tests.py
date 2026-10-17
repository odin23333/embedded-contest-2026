from pathlib import Path
import struct,subprocess,json,sys
root=Path(__file__).resolve().parents[1];report=root/'reports';report.mkdir(exist_ok=True)
tools=Path(json.loads((root/'scripts/tool_paths.json').read_text(encoding='utf-8'))['tool_root'])/'iverilog'
hdl=(root/'project/user_source/hdl_source/SD') if (root/'project').exists() else (root/'uisrc/01_rtl/SD')
tb=(root/'tb') if (root/'tb').exists() else (root/'uisrc/02_sim/tb')
def u16(b,o,v):struct.pack_into('<H',b,o,v)
def u32(b,o,v):struct.pack_into('<I',b,o,v)
def bmp(w,h):
 stride=(w*3+3)&~3;raw=bytearray()
 for y in range(h):
  for x in range(w):raw.extend(((x*11+y*7)&255,(x*3+y*23)&255,(x*17+y*5)&255))
  raw.extend(b'\xa5'*(stride-w*3))
 return struct.pack('<2sIHHI',b'BM',54+len(raw),0,0,54)+struct.pack('<IiiHHIIiiII',40,w,h,1,24,0,len(raw),0,0,0,0)+raw
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

def nearest_expected(w,h):
 if w*480>=h*640:fw,fh=640,max(1,h*640//w)
 else:fw,fh=max(1,w*480//h),480
 left,bottom=(640-fw)//2,(480-fh)//2
 out=[]
 for y in range(480):
  for x in range(640):
   if left<=x<left+fw and bottom<=y<bottom+fh:
    xx=((2*(x-left)+1)*w)//(2*fw);yy=((2*(y-bottom)+1)*h)//(2*fh)
    out.append(f'{(xx*17+yy*5)&255:02x}{(xx*3+yy*23)&255:02x}{(xx*11+yy*7)&255:02x}\n')
   else:out.append('000000\n')
 return ''.join(out)

def entry(name,attr,c=0,size=0):
 b=bytearray(32);b[:11]=name.encode();b[11]=attr;u16(b,20,c>>16);u16(b,26,c&65535);u32(b,28,size);return b
def deleted():
 b=bytearray(512)
 for i in range(16):b[i*32]=0xe5
 return b
def fixture(name,spc=1,mbr=True,active=0,folder=True,fault=None,extra_files=0,nfats=2,nearest=False):
 card={};part=131072 if mbr else 0;reserved=32;fats=600;clusters=70000;total=reserved+nfats*fats+clusters*spc;data=part+reserved+nfats*fats
 def clba(c):return data+(c-2)*spc
 def putfat(c,v):
  a=part+reserved+active*fats+c//128;b=card.setdefault(a,bytearray(512));u32(b,(c%128)*4,v)
 b=bytearray(512);b[:3]=b'\xeb\x58\x90';b[3:11]=b'MSWIN4.1';u16(b,11,512);b[13]=spc;u16(b,14,reserved);b[16]=nfats;b[21]=0xf8
 u32(b,32,total);u32(b,36,fats);u16(b,40,0x80|active if active else 0);u32(b,44,2);b[82:90]=b'FAT32   ';b[510:]=b'\x55\xaa';card[part]=b
 if mbr:
  m=bytearray(512);m[462+4]=0x0c;u32(m,462+8,part);u32(m,462+12,total);m[510:]=b'\x55\xaa';card[0]=m
 files=[bmp(33,17),bmp(7,5)];chains=[[5,261,130,390][:((len(files[0])+511)//512+spc-1)//spc],[11]]
 for content,chain in zip(files,chains):
  for i,c in enumerate(chain):
   putfat(c,(chain[i+1] if i+1<len(chain) else 0x0fffffff)|0xa0000000)
   for s in range(spc):
    offset=(i*spc+s)*512
    if offset<len(content):card[clba(c)+s]=bytearray(content[offset:offset+512].ljust(512,b'\0'))
 entries=[entry('VOLUME  BMP',8),entry('HIDDEN  BMP',0x22,9999,600),entry('DELETED BMP',0x20,9999,600),entry('SUBDIR  BMP',0x10,9999),entry('LFNENTRYBMP',0x0f),entry('01_FIRSTBMP',0x20,chains[0][0],len(files[0])),entry('LONGNA~1BMP',0x20,chains[1][0],len(files[1]))]
 entries[2][0]=0xe5
 for n in range(extra_files):entries.append(entry(f'EXTRA{n:03d}BMP',0x20,chains[1][0],len(files[1])))
 # Fragmented directory chains, except large clusters where a first-sector folder
 # avoids walking a deliberately bounded number of irrelevant directory sectors.
 if folder:
  if spc<=2:
   putfat(2,400);putfat(400,0x0fffffff)
   for s in range(spc):card[clba(2)+s]=deleted()
   rb=bytearray(512);rb[:32]=entry('MLK_TEST   ',0x10,7);card[clba(400)]=rb
  else:
   putfat(2,0x0fffffff);rb=bytearray(512);rb[:32]=entry('MLK_TEST   ',0x10,7);card[clba(2)]=rb
  if spc<=2:
   putfat(7,270);putfat(270,0x0fffffff)
   for s in range(spc):card[clba(7)+s]=deleted()
   directory=clba(270)
  else:putfat(7,0x0fffffff);directory=clba(7)
 else:putfat(2,0x0fffffff);directory=clba(2)
 db=bytearray(512)
 for i,e in enumerate(entries):db[i*32:(i+1)*32]=e
 card[directory]=db
 error,stage,variant=0,0,0
 if fault=='signature':card[0][510]=0;error=0x10
 if fault=='bps':u16(b,11,1024);error=0x12
 if fault=='spc':b[13]=3;error=0x12
 if fault=='fat16':u16(b,22,20);error=0x12
 if fault=='version':u16(b,42,1);error=0x12
 if fault=='fat_short':u32(b,36,1);error=0x13
 if fault=='root_range':u32(b,44,80000);error=0x13
 if fault=='active_range':u16(b,40,0x82);error=0x12
 if fault=='mirror_low_bits':u16(b,40,1)
 if fault=='partition_size':u32(card[0],462+12,total-1);error=0x13
 if fault=='no_partition':card[0][462+4]=0xee;error=0x11
 if fault=='empty':card[directory]=bytearray(512);error=0x17
 if fault in ['free','bad','reserved','out_of_range','early_eoc','cycle']:
  value={'free':0,'bad':0x0ffffff7,'reserved':0x0ffffff1,'out_of_range':80000,'early_eoc':0x0fffffff,'cycle':chains[0][0]}[fault]
  putfat(chains[0][0],value);error=0x22 if fault=='early_eoc' else 0x23;stage=1
 if fault=='two_node_cycle':putfat(chains[0][1],chains[0][0]);error=0x23;stage=1
 if fault=='directory_cycle':
  putfat(2,400);putfat(400,2)
  for c in [2,400]:
   for s in range(spc):card[clba(c)+s]=deleted()
  error=0x16
 if fault=='directory_bound':
  chain=list(range(1000,1010));u32(b,44,chain[0])
  for i,c in enumerate(chain):putfat(c,chain[i+1] if i+1<len(chain) else 0x0fffffff);card[clba(c)]=deleted()
  error=0x14
 if fault=='directory_short_file':u32(card[directory],5*32+28,27);error=0x21;stage=1
 if fault=='header_file_size':u32(card[directory],5*32+28,512);error=0x26;stage=1
 if fault=='bmp_signature':card[clba(chains[0][0])][0]=0;error=0x30;stage=1
 if fault in ['short_sector','long_sector','read_timeout']:
  variant={'short_sector':1,'long_sector':2,'read_timeout':3}[fault];error=0x03 if variant==3 else 0x02
 out=report/('fat32_'+name);out.mkdir(exist_ok=True)
 sectors=sorted(card.items());assert len(sectors)<=256
 (out/'bytes.hex').write_text(''.join(''.join(f'{v:02x}\n' for v in block) for _,block in sectors))
 (out/'lbas.hex').write_text(''.join(f'{a:08x}\n' for a,_ in sectors))
 reference=nearest_expected if nearest else expected
 (out/'expected0.hex').write_text(reference(33,17));(out/'expected1.hex').write_text(reference(7,5))
 return out,len(sectors),error,stage,variant

cmd=[str(tools/'bin/iverilog.exe'),'-B',str(tools/'lib/ivl'),'-g2012','-Wall','-s','fat32_tb','-o',str(report/'fat32_tb.vvp'),str(hdl/'fat32_bmp_read.v'),str(hdl/'bmp_scaled_read.v'),str(tb/'fat32_tb.v')]
p=subprocess.run(cmd,capture_output=True,text=True);(report/'fat32_compile.log').write_text(p.stdout+p.stderr);assert p.returncode==0,p.stderr
cases=[('fragmented_mbr',{}),('superfloppy_root',{'mbr':False,'folder':False}),('two_sector_cluster',{'spc':2}),('active_fat1',{'active':1}),('large_cluster',{'spc':128}),('four_of_five',{'extra_files':3}),('single_fat',{'nfats':1}),('mirrored_low_bits',{'fault':'mirror_low_bits'}),('two_node_cycle',{'fault':'two_node_cycle'})]
faults=['signature','bps','spc','fat16','version','fat_short','root_range','active_range','partition_size','no_partition','empty','free','bad','reserved','out_of_range','early_eoc','cycle','directory_cycle','directory_bound','directory_short_file','header_file_size','bmp_signature','short_sector','long_sector','read_timeout']
cases += [(f,{'fault':f}) for f in faults]
if len(sys.argv)>1:cases=[c for c in cases if c[0] in sys.argv[1:]]
results=[]
for name,options in cases:
 out,n,err,stage,variant=fixture(name,nearest=True,**options)
 files=min(4,2+options.get('extra_files',0))
 p=subprocess.run([str(tools/'bin/vvp.exe'),'-M','-',str(report/'fat32_tb.vvp'),'+DIR='+out.as_posix(),f'+COUNT={n}',f'+ERROR={err}',f'+FILES={files}',f'+VARIANT={variant}',f'+STAGE={stage}'],cwd=report,capture_output=True,text=True,timeout=600)
 (report/('fat32_'+name+'.log')).write_text(p.stdout+p.stderr)
 ok=p.returncode==0 and 'PASS FAT32' in p.stdout
 results.append({'case':name,'result':'PASS' if ok else 'FAIL','expected_error':err,'options':options})
 print(name,p.stdout.strip(),flush=True)
 if not ok:print(p.stderr,flush=True);break
if len(sys.argv)>1 and (report/'fat32_tests.json').exists():
 old=json.loads((report/'fat32_tests.json').read_text());names={x['case'] for x in results};results=[x for x in old if x['case'] not in names]+results
(report/'fat32_tests.json').write_text(json.dumps(results,indent=2))
assert all(x['result']=='PASS' for x in results)

if '--storage-only' not in sys.argv and '--recovery-only' not in sys.argv:
 (report/'project_fat32_tb_result.json').write_text(json.dumps([{'test':'fat32_tb','result':'PASS','cases':len(results),'scope':'real filesystem with legacy nearest scaler, sparse fragmented fixtures; default bilinear covered by quality matrix and real storage/recovery integration'}],indent=2))
if len(sys.argv)==1 or '--storage-only' in sys.argv or '--recovery-only' in sys.argv:
 out,n,_,_,_=fixture('storage')
 for suite in (['fat32_recovery_tb'] if '--recovery-only' in sys.argv else ['fat32_storage_tb','fat32_recovery_tb']):
  outv=report/(suite+'.vvp')
  sources=[hdl/'sd_card_bmp.v',hdl/'fat32_bmp_read.v',hdl/'bmp_scaled_read.v',hdl.parent/'control/error_recovery.v',hdl.parent/'control/storage_watchdog.v',tb/(suite+'.v')]
  p=subprocess.run([str(tools/'bin/iverilog.exe'),'-B',str(tools/'lib/ivl'),'-g2012','-Wall','-s',suite,'-o',str(outv),*[str(x) for x in sources]],capture_output=True,text=True)
  (report/(suite+'_compile.log')).write_text(p.stdout+p.stderr);assert p.returncode==0,p.stderr
  p=subprocess.run([str(tools/'bin/vvp.exe'),'-M','-',str(outv),'+DIR='+out.as_posix(),f'+COUNT={n}'],cwd=report,capture_output=True,text=True,timeout=600)
  (report/(suite+'.log')).write_text(p.stdout+p.stderr)
  ok=p.returncode==0 and 'PASS FAT32' in p.stdout
  (report/('project_'+suite+'_result.json')).write_text(json.dumps([{'test':suite,'result':'PASS' if ok else 'FAIL','scope':'actual FAT/scaler/storage/recovery; SD transport and DDR completion modeled'}],indent=2))
  print(p.stdout.strip(),flush=True);assert ok,p.stderr
