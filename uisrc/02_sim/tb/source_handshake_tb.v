`timescale 1ns/1ps
module source_handshake_tb;
reg clk=0,rst=1,next=0,finish=0,tick=1;always #5 clk=~clk;
wire valid,busy,ready,multiple,error,active,progress;wire [1:0] wrbuf,dispbuf;
wire [3:0] code;wire req,wen,ncs,dclk,mosi;wire [31:0] data;
sd_card_bmp #(.EXTERNAL_CONTROL(1),.CLK_FREQ_HZ(1000),.SCAN_MAX_SECTOR(100)) backend(
 .clk(clk),.rst(rst),.storage_halt(1'b0),.storage_active(active),.storage_progress(progress),.storage_error(error),
 .key_next(1'b1),.key_auto(1'b1),.next_cmd(next),.block_cmd(1'b0),.frame_tick(tick),
 .backend_busy(busy),.backend_ready(ready),.multiple(multiple),.state_code(code),.bmp_width(16'd640),.bmp_height(16'd480),
 .display_valid(valid),.write_finish_toggle(finish),.write_buf_idx(wrbuf),.disp_buf_idx(dispbuf),
 .write_req(req),.write_req_ack(1'b1),.write_en(wen),.write_data(data),.SD_nCS(ncs),.SD_DCLK(dclk),.SD_MOSI(mosi),.SD_MISO(1'b1));
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
initial begin
 cycles(5);rst=0;wait(busy);cycles(2);finish=~finish;
 cycles(8);if(valid || !busy || backend.source_done_seen)$fatal(1,"Idle before source start misclassified as completion");
 wait(!backend.bmp_ready);cycles(10);if(valid)$fatal(1,"Published active source");
 wait(backend.bmp_ready);cycles(5);if(!valid || busy || dispbuf!=0)$fatal(1,"Real source completion lost");
 next=1;cycles(1);next=0;wait(busy);cycles(2);finish=~finish;
 wait(!backend.bmp_ready);backend.fixed_bmp.bmp_read_m0.inject_error=1;
 cycles(220);if(!valid || dispbuf!=0 || ready)$fatal(1,"Errored target image replaced good display");
 rst=1;cycles(3);if(valid || busy || error)$fatal(1,"Reset failed");
 $display("PASS SOURCE_HANDSHAKE: delayed source start + early memory finish never commits idle; actual ready return commits; parser error preserves old buffer; reset");$finish;
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
integer busy=0,scanleft=0,start_delay=0;reg inject_error=0;
assign read_error=inject_error;assign ready=busy==0&&scanleft==0;
assign state_code=0;assign write_req=0;assign sd_sec_read=0;assign sd_sec_read_addr=0;
assign bmp_data_wr_en=0;assign bmp_data=0;
always @(posedge clk) begin
 if(rst)begin start_delay<=0;inject_error<=0;busy<=0;scanleft<=0;scan_done<=0;scan_found_valid<=0;scan_found_total<=0;scan_found_sector<=0;end
 else begin
  scan_found_valid<=0;
  if(scan_start)begin scanleft<=4;scan_done<=0;scan_found_total<=0;end
  else if(scanleft>0)begin
   scan_found_valid<=1;scan_found_sector<=(5-scanleft)*10;scan_found_total<=scan_found_total+1;scanleft<=scanleft-1;
   if(scanleft==1)scan_done<=1;
  end
  if(load_start)begin
   if(load_sector!=10&&load_sector!=20&&load_sector!=30&&load_sector!=40)$fatal(1,"Sector lookup");
   start_delay<=20;
  end else if(start_delay>0)begin start_delay<=start_delay-1;if(start_delay==1)busy<=180;end
  else if(busy>0)busy<=busy-1;
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
