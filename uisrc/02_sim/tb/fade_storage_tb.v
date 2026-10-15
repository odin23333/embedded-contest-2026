`timescale 1ns/1ps
module fade_storage_tb;
reg clk=0,rst=1,next=0,finish=0;integer fc=0;wire tick=fc==19;
always #5 clk=~clk;
always @(posedge clk)if(rst)fc<=0;else if(fc==19)fc<=0;else fc<=fc+1;
wire valid,ready,permit;wire[1:0] disp,wr;wire[4:0] gain;wire[23:0] rgb;
sd_card_bmp #(.EXTERNAL_CONTROL(1),.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(100)) dut(
 .clk(clk),.rst(rst),.next_cmd(next),.block_cmd(1'b0),.frame_tick(tick&&(!valid||permit)),.storage_halt(1'b0),
 .key_next(1'b1),.key_auto(1'b1),.pending_ready(ready),.display_valid(valid),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_finish_toggle(finish),.write_buf_idx(wr),.disp_buf_idx(disp),.write_req_ack(1'b1),.SD_MISO(1'b1));
image_fade fade(clk,~rst,tick,valid,1'b0,ready,disp,24'hffffff,permit,rgb,gain);
reg prior_valid=0;reg[1:0] prior_disp=0;
always @(negedge clk)begin
 if(!rst && prior_valid && disp!=prior_disp && gain!=0)$fatal(1,"Buffer changed while visible");
 prior_valid=valid;prior_disp=disp;
end
initial begin
 repeat(5)@(negedge clk);rst=0;wait(dut.load_busy);wait(dut.source_done_seen);@(negedge clk);finish=~finish;
 wait(valid);if(disp!=0 || gain!=16)$fatal(1,"First image bypass failed");
 @(negedge clk);next=1;@(negedge clk);next=0;wait(dut.load_busy);
 repeat(100)@(negedge clk);if(gain!=16 || disp!=0)$fatal(1,"Dimmed while loading");
 wait(dut.source_done_seen);@(negedge clk);finish=~finish;wait(ready);wait(permit);
 if(disp!=0 || gain!=0)$fatal(1,"Fade not black before commit");
 wait(disp==1);wait(gain==16);if(!valid || dut.load_busy)$fatal(1,"Commit not finished");
 $display("PASS FADE_STORAGE: actual storage control plus fade, first-image bypass, old picture retained while loading, black-only frame commit, full new-image restore");$finish;
end
initial begin #100000;$fatal(1,"Timeout");end
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
