`timescale 1ns/1ps
// Actual FAT32 -> scaler -> scheduler integration. Only SD sector transport and
// DDR completion are modeled; every emitted pixel is checked independently.
module fat32_storage_tb;
reg clk=0,rst=1,next=0,block=0,finish=0,retired=0;
wire req,wen,valid,pending,busy,ready,active,progress,error,multiple;
wire[1:0] wr,disp;wire[31:0] data;
integer fc=0,frames=0,pixels=0,wait_done=0,old_req=0;
reg[23:0] expected0[0:307199],expected1[0:307199];string dir,filename;
always #5 clk=~clk;
always @(posedge clk)if(rst)fc<=0;else if(fc==19)fc<=0;else fc<=fc+1;
sd_card_bmp #(.EXTERNAL_CONTROL(1),.PREFETCH_ENABLED(1),.IMAGE_SCALING_ENABLED(1),.FAT32_ENABLED(1),.CLK_FREQ_HZ(1000)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.next_cmd(next),.block_cmd(block),.frame_tick(fc==19),.storage_halt(1'b0),
 .storage_active(active),.storage_progress(progress),.storage_error(error),.backend_busy(busy),.backend_ready(ready),.multiple(multiple),
 .pending_ready(pending),.bmp_width(16'd640),.bmp_height(16'd480),.display_valid(valid),.write_finish_toggle(finish),
 .write_buf_idx(wr),.disp_buf_idx(disp),.write_req(req),.write_req_ack(req),.write_en(wen),.write_data(data),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),.buffer_retired(retired),.pixel_write_ready(1'b1));
always @(negedge clk)begin
 if(!rst)begin
  if(req && !old_req)begin pixels=0;frames=frames+1;if(valid && wr==disp)$fatal(1,"FAT preload overwrites display");end
  if(wen)begin
   if(data[31:8]!==((frames%2==1)?expected0[pixels]:expected1[pixels]))$fatal(1,"Integrated pixel mismatch frame %0d pixel %0d",frames,pixels);
   pixels=pixels+1;
   if(pixels==307200)wait_done=5;
  end
  if(wait_done!=0)begin wait_done=wait_done-1;if(wait_done==0)finish=~finish;end
  if(error)$fatal(1,"Integrated FAT error %h",dut.fat32_files.bmp_read_m0.fs_error_code);
 end
 old_req=req;
end
task press;begin @(negedge clk);next=1;@(negedge clk);next=0;end endtask
initial begin
 if(!$value$plusargs("DIR=%s",dir))$fatal(1,"DIR required");
 filename=$sformatf("%0s/expected0.hex",dir);$readmemh(filename,expected0);
 filename=$sformatf("%0s/expected1.hex",dir);$readmemh(filename,expected1);
 repeat(5)@(negedge clk);rst=0;wait(valid);repeat(20)@(negedge clk);
 if(frames!=1 || disp!=0 || !multiple)$fatal(1,"First FAT image not committed correctly");
 repeat(50)@(negedge clk);if(frames!=1)$fatal(1,"Read buffer not retired before reuse");
 retired=1;wait(dut.transfer_complete);repeat(3000)@(negedge clk);
 if(frames!=2 || disp!=0 || pending || busy || active || !ready)$fatal(1,"FAT cache changes display or keeps watchdog active");
 block=1;press();repeat(40)@(negedge clk);if(disp!=0 || pending)$fatal(1,"Emergency accepts switch");
 block=0;press();wait(disp==1);retired=0;
 repeat(100)@(negedge clk);if(frames!=2)$fatal(1,"Former display reused without retirement");
 retired=1;wait(frames==3);wait(dut.transfer_complete);press();wait(disp==0);
 $display("PASS FAT32_STORAGE: real FAT/scaler pixels, first publish after source+DDR, hidden preload, retirement, emergency blocking, cached cycle");$finish;
end
initial begin #1000000000;$fatal(1,"Integrated FAT timeout frames=%0d pixels=%0d valid=%b",frames,pixels,valid);end
endmodule

module sd_card_top #(parameter SPI_LOW_SPEED_DIV=0)(input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
 output sd_init_done,input sd_sec_read,input[31:0] sd_sec_read_addr,output reg[7:0] sd_sec_read_data,
 output reg sd_sec_read_data_valid,sd_sec_read_end,input sd_sec_write,input[31:0] sd_sec_write_addr,
 input[7:0] sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end);
assign sd_init_done=!rst;assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
reg[7:0] bytes[0:131071];reg[31:0] lbas[0:255];string dir,filename;integer count,i,j,idx;
initial begin
 sd_sec_read_data=0;sd_sec_read_data_valid=0;sd_sec_read_end=0;
 i=$value$plusargs("DIR=%s",dir);i=$value$plusargs("COUNT=%d",count);
 filename=$sformatf("%0s/bytes.hex",dir);$readmemh(filename,bytes,0,count*512-1);
 filename=$sformatf("%0s/lbas.hex",dir);$readmemh(filename,lbas,0,count-1);
 forever begin
  @(negedge clk);
  if(sd_sec_read && !rst)begin
   idx=-1;for(i=0;i<count;i=i+1)if(lbas[i]==sd_sec_read_addr)idx=i;
   if(idx<0)$fatal(1,"Integrated read outside filesystem %0d",sd_sec_read_addr);
   for(j=0;j<512;j=j+1)begin
    sd_sec_read_data=bytes[idx*512+j];sd_sec_read_data_valid=1;@(negedge clk);sd_sec_read_data_valid=0;@(negedge clk);
   end
   sd_sec_read_end=1;@(negedge clk);sd_sec_read_end=0;repeat(4)@(negedge clk);
  end
 end
end
endmodule
