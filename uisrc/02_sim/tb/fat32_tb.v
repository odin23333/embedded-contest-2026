`timescale 1ns/1ps
module fat32_tb;
// Filesystem fault/partition/cluster matrix is independent of interpolation.
// Keep its established nearest pixel oracle; storage/recovery tests below use
// the production default bilinear path and the bilinear reference images.
defparam dut.scaler.QUALITY=0;
reg clk=0,rst=1,initialized=0,scan=0,load=0,ack=0,dv=0,ending=0,space=1;
reg[31:0] chosen=0;reg[7:0] din=0;
wire ready,error,done,found,req,rd,wen;wire[31:0] sector,addr;wire[2:0] total;wire[3:0] code;wire[7:0] fs_code;wire[23:0] pixel;
reg[7:0] bytes[0:131071];reg[31:0] lbas[0:255];reg[23:0] expected0[0:307199],expected1[0:307199];
string dir,filename;integer count,expected_error,files,variant,expected_stage;
integer i,j,idx,base,cycles=0,pixels=0,active_file=0,found_count=0,reads=0,write_requests=0;
always #5 clk=~clk;
always @(negedge clk)begin cycles=cycles+1;space=(cycles%11!=0 && cycles%11!=1);end
fat32_bmp_read #(.CLK_FREQ_HZ(1000),.MAX_DIR_SECTORS(8),.MAX_CHAIN_CLUSTERS(128)) dut(
 .clk(clk),.rst(rst),.ready(ready),.read_error(error),.scan_start(scan),.scan_start_sector(32'd0),.scan_max_sector(32'd131071),.scan_target_count(3'd4),
 .scan_done(done),.scan_found_valid(found),.scan_found_sector(sector),.scan_found_total(total),
 .load_start(load),.load_sector(chosen),.sd_init_done(initialized),.state_code(code),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req(req),.write_req_ack(ack),.sd_sec_read(rd),.sd_sec_read_addr(addr),.sd_sec_read_data(din),
 .sd_sec_read_data_valid(dv),.sd_sec_read_end(ending),.bmp_data_wr_en(wen),.bmp_data(pixel),.pixel_write_ready(space),.fs_error_code(fs_code));
initial begin
 if(!$value$plusargs("DIR=%s",dir))$fatal(1,"DIR required");
 i=$value$plusargs("COUNT=%d",count);i=$value$plusargs("ERROR=%d",expected_error);
 i=$value$plusargs("FILES=%d",files);i=$value$plusargs("VARIANT=%d",variant);i=$value$plusargs("STAGE=%d",expected_stage);
 filename=$sformatf("%0s/bytes.hex",dir);$readmemh(filename,bytes,0,count*512-1);
 filename=$sformatf("%0s/lbas.hex",dir);$readmemh(filename,lbas,0,count-1);
 filename=$sformatf("%0s/expected0.hex",dir);$readmemh(filename,expected0);
 filename=$sformatf("%0s/expected1.hex",dir);$readmemh(filename,expected1);
 forever begin
  @(negedge clk);
  if(rd && !rst)begin
   idx=-1;for(i=0;i<count;i=i+1)if(lbas[i]==addr)idx=i;
   if(idx<0)$fatal(1,"Unexpected physical LBA %0d",addr);
   base=idx*512;reads=reads+1;
   if(variant==3 && reads==1)begin wait(!rd);end
   else begin
    for(j=0;j<((variant==1&&reads==1)?511:((variant==2&&reads==1)?513:512));j=j+1)begin
     din=bytes[base+(j%512)];dv=1;@(negedge clk);dv=0;@(negedge clk);
     if(j%37==0)repeat(3)@(negedge clk);
    end
    ending=1;@(negedge clk);ending=0;repeat(4)@(negedge clk);
   end
  end
 end
end
always @(posedge clk)begin #1;
 if(found)begin
  if(sector!==found_count)$fatal(1,"Non-slot scheduler token %0d expected %0d",sector,found_count);
  found_count=found_count+1;
 end
 if(req && !ack)write_requests=write_requests+1;
 if(wen)begin
  if(pixels>=307200 || pixel!==(active_file==0?expected0[pixels]:expected1[pixels]))
   $fatal(1,"File %0d pixel %0d actual %h expected %h",active_file,pixels,pixel,active_file==0?expected0[pixels]:expected1[pixels]);
  pixels=pixels+1;
 end
end
task assert_error;
begin
 wait(error);repeat(10)@(negedge clk);
 if(fs_code!=expected_error)$fatal(1,"Error code %h expected %h",fs_code,expected_error);
 if(rd || req || wen)$fatal(1,"Activity continues after sticky error");
 if(expected_stage<2 && write_requests!=0)$fatal(1,"Bad metadata reached framebuffer write");
 $display("PASS FAT32: rejected fault code=%h, reads=%0d, no incomplete publication",fs_code,reads);$finish;
end endtask
initial begin
 wait(count>0);repeat(5)@(negedge clk);initialized=1;rst=0;scan=1;@(negedge clk);scan=0;
 if(expected_error!=0 && expected_stage==0)assert_error;
 wait(done || error);if(error)$fatal(1,"Unexpected scan failure %h",fs_code);
 repeat(3)@(negedge clk);if(total!=files || found_count!=files)$fatal(1,"Files %0d/%0d expected %0d",total,found_count,files);
 for(active_file=0;active_file<files;active_file=active_file+1)begin
  pixels=0;chosen=active_file;@(negedge clk);load=1;@(negedge clk);load=0;
  if(expected_error!=0)assert_error;
  wait(req || error);if(error)$fatal(1,"Unexpected load failure %h",fs_code);
  ack=1;repeat(2)@(negedge clk);ack=0;
  wait(ready || error);if(error || pixels!=307200)$fatal(1,"Load result error=%h pixels=%0d",fs_code,pixels);
  repeat(5)@(negedge clk);
 end
 $display("PASS FAT32: %0d fragmented BMP files, exact 307200 pixels/file, directory/cluster mapping/backpressure, reads=%0d",files,reads);$finish;
end
initial begin #1000000000;$fatal(1,"FAT32 timeout state=%0d code=%h addr=%0d",dut.state,fs_code,addr);end
endmodule
