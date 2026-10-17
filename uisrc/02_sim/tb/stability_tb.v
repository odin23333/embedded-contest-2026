`timescale 1ns/1ps
// Accelerated event stress, not an elapsed one-hour board test.
module stability_tb;
reg clk=0,rst=1;always #5 clk=~clk;
reg [15:0] physical=0;wire [3:0] rows;reg [3:0] cols;
wire [15:0] down,pressed;integer r,c,i,starts=0,manuals=0,emergencies=0,resets=0;
always @* begin cols=15;for(r=0;r<4;r=r+1)for(c=0;c<4;c=c+1)if(rows[r]===1'b0 && physical[r*4+c])cols[c]=0;end
matrix_keys #(.SLOT(5),.STABLE(2)) keyboard(clk,~rst,cols,rows,down,pressed);
wire emergency,muted,auto_enabled,next_event,next_valid,pending,valid,busy,ready,multiple;
reg finish=0,tick=0,halt=0;wire active,progress,error;
wire [1:0] wrbuf,dispbuf;wire [3:0] code;wire wrreq,wen,ncs,dclk,mosi;wire [31:0] data;
mode_control modes(clk,~rst,pressed[0],pressed[1],pressed[2],pressed[3],emergency,muted,auto_enabled,next_event);
playback_scheduler #(.AUTO_CYCLES(5000)) scheduler(clk,~rst,emergency|pressed[2]|halt,auto_enabled,next_event,valid,multiple,busy,ready,next_valid,pending,);
sd_card_bmp #(.EXTERNAL_CONTROL(1),.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(100)) backend(
 .clk(clk),.rst(rst),.storage_halt(halt),.storage_active(active),.storage_progress(progress),.storage_error(error),
 .key_next(1'b1),.key_auto(1'b1),.next_cmd(next_valid&&ready),.block_cmd(emergency|pressed[2]),.frame_tick(tick),
 .backend_busy(busy),.backend_ready(ready),.multiple(multiple),.state_code(code),.bmp_width(16'd640),.bmp_height(16'd480),
 .display_valid(valid),.write_finish_toggle(finish),.write_buf_idx(wrbuf),.disp_buf_idx(dispbuf),
 .write_req(wrreq),.write_req_ack(1'b1),.write_en(wen),.write_data(data),.SD_nCS(ncs),.SD_DCLK(dclk),.SD_MOSI(mosi),.SD_MISO(1'b1));
always @(posedge clk)if(!rst && backend.load_start_pulse)starts<=starts+1;
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
task key;input integer index;begin physical=16'b1<<index;cycles(100);physical=0;cycles(100);end endtask
task complete;input [1:0] idx,bufidx;begin
 wait(busy);cycles(250);if(backend.load_idx!==idx || wrbuf!==bufidx)$fatal(1,"Wrong image/buffer");
 finish=~finish;cycles(10);if(!busy)$fatal(1,"Early commit");
 tick=1;cycles(1);tick=0;cycles(6);if(busy || !valid || dispbuf!==bufidx)$fatal(1,"Commit failure");
end endtask
integer mark;reg [1:0] saved_buf;
initial begin
 cycles(5);rst=0;complete(0,0);
 for(i=1;i<=100;i=i+1)begin key(0);complete(i%4,i%2);manuals=manuals+1;end
 if(starts!=101)$fatal(1,"Repeated/held key duplicated a request");
 for(i=0;i<50;i=i+1)begin
  mark=starts;key(2);if(!emergency)$fatal(1,"Alarm enter");
  key(0);key(1);if(starts!=mark || auto_enabled)$fatal(1,"Playback advanced during alarm");
  key(3);if(!muted)$fatal(1,"Mute enter");key(3);if(muted)$fatal(1,"Mute exit");
  key(2);if(emergency || starts!=mark)$fatal(1,"Alarm restore");emergencies=emergencies+1;
 end
 // Storage halt must preserve the good display, block commands and keep emergency usable.
 saved_buf=dispbuf;halt=1;cycles(20);key(0);key(1);key(2);
 if(!valid || dispbuf!==saved_buf || ready || !emergency)$fatal(1,"Fault did not preserve display/emergency");
 for(i=0;i<10;i=i+1)begin
  physical=0;rst=1;cycles(5);halt=0;rst=0;complete(0,0);
  if(emergency || muted || auto_enabled || pending)$fatal(1,"Reset state leaked");resets=resets+1;
 end
 key(1);wait(busy);complete(1,1);key(1);if(auto_enabled)$fatal(1,"Auto stop");
 $display("PASS STABILITY: %0d manual changes, %0d emergency/mute/restore cycles, %0d reset/restarts, storage-halt image retention, auto start/stop; accelerated model",manuals,emergencies,resets);$finish;
end
initial begin #5000000;$fatal(1,"Stress timeout");end
endmodule
// Abstract BMP source. The real BMP module is checked separately with 307200 pixels.
module bmp_read(input clk,rst,output ready,output read_error,input scan_start,input [31:0] scan_start_sector,scan_max_sector,
 input [2:0] scan_target_count,output reg scan_done,scan_found_valid,output reg [31:0] scan_found_sector,
 output reg [2:0] scan_found_total,input load_start,input [31:0] load_sector,input sd_init_done,
 output [3:0] state_code,input [15:0] bmp_width,bmp_height,output write_req,input write_req_ack,
 output sd_sec_read,output [31:0] sd_sec_read_addr,input [7:0] sd_sec_read_data,input sd_sec_read_data_valid,sd_sec_read_end,
 output bmp_data_wr_en,output [23:0] bmp_data);
integer busy=0,scanleft=0;
assign read_error=0;assign ready=busy==0&&scanleft==0;
assign state_code=0;assign write_req=0;assign sd_sec_read=0;assign sd_sec_read_addr=0;
assign bmp_data_wr_en=0;assign bmp_data=0;
always @(posedge clk) begin
 if(rst)begin busy<=0;scanleft<=0;scan_done<=0;scan_found_valid<=0;scan_found_total<=0;scan_found_sector<=0;end
 else begin
  scan_found_valid<=0;
  if(scan_start)begin scanleft<=4;scan_done<=0;scan_found_total<=0;end
  else if(scanleft>0)begin
   scan_found_valid<=1;scan_found_sector<=(5-scanleft)*10;scan_found_total<=scan_found_total+1;scanleft<=scanleft-1;
   if(scanleft==1)scan_done<=1;
  end
  if(load_start)begin
   if(load_sector!=10&&load_sector!=20&&load_sector!=30&&load_sector!=40)$fatal(1,"Sector lookup");
   busy<=180;
  end else if(busy>0)busy<=busy-1;
 end
end
endmodule
module sd_card_top #(parameter SPI_LOW_SPEED_DIV=60)(input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
 output sd_init_done,input sd_sec_read,input [31:0] sd_sec_read_addr,
 output [7:0] sd_sec_read_data,output sd_sec_read_data_valid,sd_sec_read_end,
 input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end);
assign sd_init_done=!rst;assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;
assign sd_sec_read_data=0;assign sd_sec_read_data_valid=0;assign sd_sec_read_end=0;
assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
endmodule
