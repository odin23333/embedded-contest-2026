`timescale 1ns/1ps
module prefetch_tb;
reg clk=0,rst=1,manual=0,auto_en=0,pause=0,finish=0,retired=0,halt=0;
integer fc=0,loads=0,done_wait=0,commits=0;
wire tick=fc==19;always #5 clk=~clk;
always @(posedge clk)if(rst)fc<=0;else if(fc==19)fc<=0;else fc<=fc+1;
wire valid,ready,permit,busy,accept,multiple,active,request,pending;
wire[1:0] disp,wr;wire[4:0] gain;wire[23:0] rgb;
sd_card_bmp #(.EXTERNAL_CONTROL(1),.PREFETCH_ENABLED(1),.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(100)) dut(
 .clk(clk),.rst(rst),.next_cmd(request&&accept),.block_cmd(pause),.frame_tick(tick&&(!valid||pause||permit)),.storage_halt(halt),
 .key_next(1'b1),.key_auto(1'b1),.pending_ready(ready),.backend_busy(busy),.backend_ready(accept),.multiple(multiple),.storage_active(active),
 .buffer_retired(retired),.display_valid(valid),.bmp_width(16'd640),.bmp_height(16'd480),.write_finish_toggle(finish),.write_buf_idx(wr),.disp_buf_idx(disp),.write_req_ack(1'b1),.SD_MISO(1'b1));
playback_scheduler #(.AUTO_CYCLES(600)) schedule(clk,~rst,pause,auto_en,manual,valid,multiple,busy,accept,request,pending);
image_fade fade(clk,~rst,tick,valid,pause,ready,disp,24'hffffff,permit,rgb,gain);
reg old_valid=0;reg[1:0] old_disp=0;
always @(negedge clk)begin
 if(!rst)begin
  if(dut.load_start_pulse)begin
   loads=loads+1;
   if(valid && (!retired || wr==disp))$fatal(1,"Preload writes an unretired/displayed buffer");
  end
  if(dut.load_busy && dut.source_done_seen && !dut.write_done_seen)begin
   done_wait=done_wait+1;
   if(done_wait==8)finish=~finish;
  end else done_wait=0;
  if(old_valid && disp!=old_disp)begin
   commits=commits+1;retired=0;
   if(gain!=0 && !pause)$fatal(1,"Buffer changes before black");
  end
 end
 old_valid=valid;old_disp=disp;
end
task press;begin @(negedge clk);manual=1;@(negedge clk);manual=0;end endtask
integer initial_loads,initial_commits,latency;
initial begin
 repeat(5)@(negedge clk);rst=0;wait(valid);
 initial_loads=loads;repeat(100)@(negedge clk);
 if(loads!=initial_loads)$fatal(1,"Did not wait for reader retirement");
 retired=1;wait(dut.transfer_complete);repeat(100)@(negedge clk);
 if(disp!=0 || gain!=16 || ready || busy || active)$fatal(1,"Background preload switched/dimmed/stalled scheduler/watchdog");
 initial_loads=loads;press();latency=0;
 while(gain==16 && latency<45)begin @(negedge clk);latency=latency+1;end
 if(gain==16 || loads!=initial_loads)$fatal(1,"Cached next still waits for SD reload");
 wait(disp==1);wait(gain==16);repeat(100)@(negedge clk);
 if(loads!=initial_loads)$fatal(1,"Reuses former display before reader retires");
 // An early press is held until the one look-ahead load completes.
 press();repeat(60)@(negedge clk);if(disp!=1 || gain!=16)$fatal(1,"Early press corrupts old image");
 retired=1;wait(dut.load_start_pulse);press();press(); // coalesced burst presses
 wait(dut.transfer_complete);wait(disp==0);wait(gain==16);
 repeat(100)@(negedge clk);if(commits!=2)$fatal(1,"Burst presses cause multi-page skips");
 retired=1;wait(dut.transfer_complete);press();wait(gain<16);pause=1;
 repeat(60)@(negedge clk);
 if(disp!=0 || gain!=16 || ready)$fatal(1,"Emergency does not cancel switch and restore old image");
 pause=0;repeat(100)@(negedge clk);if(commits!=2)$fatal(1,"Canceled request reappears after emergency");
 auto_en=1;wait(disp==1);wait(gain==16);retired=1;
 wait(dut.transfer_complete);if(pending)$fatal(1,"Auto timer already queued unexpectedly");
 wait(disp==0);wait(gain==16);auto_en=0;retired=1;wait(dut.transfer_complete);
 initial_commits=commits;repeat(1500)@(negedge clk);
 if(commits!=initial_commits)$fatal(1,"Auto stop still advances");
 // Completion cached at a fault must never be published.
 halt=1;press();repeat(100)@(negedge clk);if(commits!=initial_commits || ready)$fatal(1,"Fault publishes cache");
 rst=1;repeat(6)@(negedge clk);if(valid || ready)$fatal(1,"Reset retains stale cache");
 $display("PASS PREFETCH: retire-before-reuse, hidden background load, no unsolicited fade, instant cached request, early/coalesced keys, emergency cancellation, auto and fault/reset");$finish;
end
initial begin #300000;$fatal(1,"Timeout");end
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
