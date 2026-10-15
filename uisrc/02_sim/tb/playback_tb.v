`timescale 1ns/1ps
// Control test using real sd_card_bmp + debounce; peripheral models below.
module playback_tb;
reg clk=0,rst=1,keynext=1,keyauto=1,finish=0;
wire valid;wire [1:0] wrbuf,dispbuf;
wire [3:0] statecode;wire wrreq,wen,ncs,dclk,mosi;wire [31:0] data;
integer starts=0;
always #5 clk=~clk;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(100)) dut(
 .clk(clk),.rst(rst),.storage_halt(1'b0),.key_next(keynext),.key_auto(keyauto),.state_code(statecode),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(valid),.write_finish_toggle(finish),
 .write_buf_idx(wrbuf),.disp_buf_idx(dispbuf),.write_req(wrreq),.write_req_ack(1'b1),
 .write_en(wen),.write_data(data),.SD_nCS(ncs),.SD_DCLK(dclk),.SD_MOSI(mosi),.SD_MISO(1'b1));
always @(posedge clk) if(!rst && dut.load_start_pulse)starts=starts+1;
task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
task press_next;begin keynext=0;ticks(30);keynext=1;ticks(30);end endtask
task press_auto;begin keyauto=0;ticks(30);keyauto=1;ticks(30);end endtask
task complete;
input [1:0] idx,bufidx;
begin
 wait(dut.load_busy);ticks(250);
 if(dut.load_idx!==idx || wrbuf!==bufidx)$fatal(1,"Wrong target idx=%0d buf=%0d",dut.load_idx,wrbuf);
 finish=~finish;ticks(5);
 if(!valid || dut.img_idx!==idx || dispbuf!==bufidx)$fatal(1,"Commit failure");
end endtask
initial begin
 ticks(5);rst=0;wait(dut.load_busy);ticks(250);
 if(valid)$fatal(1,"Display committed before memory finished");
 complete(0,0);
 keynext=0;ticks(3);keynext=1;ticks(30);
 if(starts!=1)$fatal(1,"Glitch accepted");
 press_next;wait(dut.load_busy);
 if(dispbuf!=0 || wrbuf!=1)$fatal(1,"Overwriting displayed buffer");
 // While busy, two presses are coalesced into one pending request.
 press_next;press_next;
 complete(1,1);complete(2,0);
 ticks(50);if(starts!=3)$fatal(1,"Busy requests did not coalesce: %0d",starts);
 keynext=0;ticks(80);complete(3,1);ticks(50);
 if(starts!=4)$fatal(1,"Held button repeated");keynext=1;ticks(30);
 press_next;complete(0,0);
 press_auto;wait(dut.load_busy);complete(1,1);
 press_auto;ticks(1300);
 if(starts!=6 || dut.auto_play_en)$fatal(1,"Auto stop failed");
 rst=1;ticks(3);
 if(valid || dut.auto_play_en)$fatal(1,"Reset failed");
 $display("PASS PLAYBACK: scan four, first-frame commit, manual wrap, debounce, hold, busy coalescing, buffer alternation, auto start/stop, reset");$finish;
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
