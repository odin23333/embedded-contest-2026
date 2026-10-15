`timescale 1ns/1ps
// Actual board top and production control/video/audio RTL. Only vendor/external
// peripherals (PLL, memory, card and encrypted HDMI core/PHY) are modeled.
module system_response_tb;
reg clk=0;always #20 clk=~clk;
reg [15:0] physical=0;reg [3:0] cols;wire [3:0] rows;wire [7:0] led;
wire hc,h0,h1,h2,scl,sda,ncs,sck,mosi;integer r,c,fd;
real start_time,video_ms,audio_ms;reg video_seen=0,audio_seen=0;
top dut(.clk(clk),.key_col(cols),.key_row(rows),.led(led),.HDMI_CLK_P(hc),.HDMI_D2_P(h2),.HDMI_D1_P(h1),.HDMI_D0_P(h0),.HDMI_DDC_SCL(scl),.HDMI_DDC_SDA(sda),.sd_ncs(ncs),.sd_dclk(sck),.sd_mosi(mosi),.sd_miso(1'b1),.UART_RX(1'b1));
always @* begin
 cols=15;
 for(r=0;r<4;r=r+1)for(c=0;c<4;c=c+1)
  if(rows[r]===1'b0 && physical[r*4+c])cols[c]=0;
end
always @(posedge dut.video_clk)if(dut.osd_de && dut.screen.frame_alarm && !video_seen)begin
 video_ms=($realtime-start_time)/1000000.0;video_seen=1;
end
always @(posedge dut.audio_valid)begin
 #1;
 if(($signed(dut.audio_left_data)==500000 || $signed(dut.audio_left_data)==-500000) && !audio_seen)begin
  if(dut.audio_left_data!==dut.audio_right_data)$fatal(1,"Emergency stereo mismatch");
  audio_ms=($realtime-start_time)/1000000.0;audio_seen=1;
 end
end
initial begin
 $dumpfile("week4_response.vcd");
 $dumpvars(0,physical,cols,rows,dut.emergency,dut.muted,dut.screen.frame_alarm,dut.audio_valid,dut.audio_left_data,dut.stream_overflow);
 wait(dut.rst_n);wait(dut.frame_start);#1234567;
 start_time=$realtime;physical=16'h0004;
 wait(video_seen && audio_seen);
 if(video_ms>200 || audio_ms>200 || video_ms<20 || audio_ms<20)$fatal(1,"Default-parameter response out of bounds");
 if(dut.display_valid)$fatal(1,"This test must exercise emergency before card image is ready");
 if(dut.stream_overflow)$fatal(1,"Short receiver stalls overflowed video queue");
 physical=0;#23000000;
 physical=16'h0008;wait(dut.muted);repeat(5)@(posedge dut.audio_valid);#1;
 if(dut.audio_left_data!==0 || dut.audio_right_data!==0)$fatal(1,"Integrated mute failed");
 physical=0;#23000000;
 physical=16'h0004;wait(!dut.emergency);wait(!dut.screen.frame_alarm);
 if(dut.stream_overflow)$fatal(1,"Video fault during restore");
 fd=$fopen("week4_response.json","w");
 $fwrite(fd,"{\"clock_hz\":25000000,\"default_debounce\":true,\"image_unavailable\":true,\"video_ms\":%0.6f,\"pcm_ms\":%0.6f,\"limit_ms\":200,\"physical_test\":false}\n",video_ms,audio_ms);$fclose(fd);
 $display("PASS SYSTEM_RESPONSE: actual board top, default matrix debounce, no-card emergency; RGB=%0.3f ms, decoded PCM=%0.3f ms; mute/restore and short HDMI stalls",video_ms,audio_ms);$finish;
end
initial begin #200000000;$fatal(1,"System response timeout");end
endmodule

module sys_pll(input refclk,reset,output clk0_out,clk1_out,clk2_out,clk90_out,extlock);
 reg fast=0,phase90=0;always #5 fast=~fast;initial begin #2.5;forever #5 phase90=~phase90;end
 assign clk0_out=fast;assign clk1_out=fast;assign clk2_out=!fast;assign clk90_out=phase90;assign extlock=!reset;
endmodule
module video_pll(input refclk,reset,output clk0_out,clk1_out,extlock);
 reg serial=0;initial begin #2;forever #4 serial=~serial;end
 assign clk0_out=refclk;assign clk1_out=serial;assign extlock=!reset;
endmodule
module PLL_HDMI_AUDIO(input refclk,reset,output clk0_out,clk1_out,clk2_out,extlock);
 reg audio=0;always #40.666667 audio=~audio;
 assign clk0_out=refclk;assign clk1_out=refclk;assign clk2_out=audio;assign extlock=!reset;
endmodule

module sd_card_bmp #(
    parameter integer EXTERNAL_CONTROL = 0,parameter integer PREFETCH_ENABLED=0,parameter integer IMAGE_SCALING_ENABLED=0,
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    input next_cmd,block_cmd,frame_tick,storage_halt,buffer_retired,pixel_write_ready,
    output storage_active,storage_progress,storage_error,
    output backend_busy,backend_ready,multiple,output pending_ready,
    output [3:0]                state_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,

    input                       write_finish_toggle,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO
);
// Card intentionally unavailable: emergency must not wait for image loading.
assign storage_active=1;assign storage_progress=0;assign storage_error=0;
assign pending_ready=0;assign backend_busy=0;assign backend_ready=0;assign multiple=0;assign state_code=0;
assign write_req=0;assign write_en=0;assign write_data=0;
assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;
always @(posedge clk)begin display_valid<=0;write_buf_idx<=0;disp_buf_idx<=0;end
endmodule

module frame_read_write
#
(
	parameter MEM_DATA_BITS          = 32,
	parameter READ_DATA_BITS         = 32,
	parameter WRITE_DATA_BITS        = 32,
	parameter ADDR_BITS              = 21,
	parameter BURST_BITS             = 9,//
	parameter BURST_SIZE             = 256,
	parameter WRITE_V_FLIP           = 1,      // 1: vertical flip when writing TF/BMP frame into SDRAM
	parameter FRAME_WIDTH            = 640,
	parameter FRAME_HEIGHT           = 480
) 
(
	input                            rst,                  
	input                            mem_clk,                    // external memory controller user interface clock
	input							 Sdr_init_done,
	input							 Sdr_init_ref_vld,
    input							 Sdr_busy,
	
    /*
    output                           rd_burst_req,               // to external memory controller,send out a burst read request
	output[BURST_BITS - 1:0]         rd_burst_len,               // to external memory controller,data length of the burst read request, not bytes
	output[ADDR_BITS - 1:0]          rd_burst_addr,              // to external memory controller,base address of the burst read request 
	input                            rd_burst_data_valid,        // from external memory controller,read data valid 
	input[MEM_DATA_BITS - 1:0]       rd_burst_data,              // from external memory controller,read request data
	input                            rd_burst_finish,            // from external memory controller,burst read finish
	*/
	output							 App_rd_en,
	output[ADDR_BITS - 1:0]			 App_rd_addr,
	input							 Sdr_rd_en,					 //read_data_valid
	input[MEM_DATA_BITS - 1:0]		 Sdr_rd_dout,
	
	input                            read_clk,                   // data read module clock
	input                            read_req,                   // data read module read request,keep '1' until read_req_ack = '1'
	output                           read_req_ack,               // data read module read request response
	output                           read_finish,                // data read module read request finish
	input[ADDR_BITS - 1:0]           read_addr_0,                // data read module read request base address 0, used when read_addr_index = 0
	input[ADDR_BITS - 1:0]           read_addr_1,                // data read module read request base address 1, used when read_addr_index = 1
	input[ADDR_BITS - 1:0]           read_addr_2,                // data read module read request base address 1, used when read_addr_index = 2
	input[ADDR_BITS - 1:0]           read_addr_3,                // data read module read request base address 1, used when read_addr_index = 3
	input[1:0]                       read_addr_index,            // select valid base address from read_addr_0 read_addr_1 read_addr_2 read_addr_3
	input[ADDR_BITS - 1:0]           read_len,                   // data read module read request data length
	input                            read_en,                    // data read module read request for one data, read_data valid next clock
	output[READ_DATA_BITS  - 1:0]    read_data,                  // read data
	/*
	output                           wr_burst_req,               // to external memory controller,send out a burst write request
	output[BURST_BITS - 1:0]         wr_burst_len,               // to external memory controller,data length of the burst write request, not bytes
	output[ADDR_BITS - 1:0]          wr_burst_addr,              // to external memory controller,base address of the burst write request 
	input                            wr_burst_data_req,          // from external memory controller,write data request ,before data 1 clock
	output[MEM_DATA_BITS - 1:0]      wr_burst_data,              // to external memory controller,write data
	input                            wr_burst_finish,            // from external memory controller,burst write finish
	*/
	output							 App_wr_en,
	output[ADDR_BITS - 1:0]			 App_wr_addr,
	output[MEM_DATA_BITS - 1:0]	 App_wr_din,
	output[3:0]						 App_wr_dm,
	
	//
	input                            write_clk,                  // data write module clock
	input                            write_req,                  // data write module write request,keep '1' until read_req_ack = '1'
	output                           write_req_ack,              // data write module write request response
	output                           write_finish,               // data write module write request finish
	input[ADDR_BITS - 1:0]           write_addr_0,               // data write module write request base address 0, used when write_addr_index = 0
	input[ADDR_BITS - 1:0]           write_addr_1,               // data write module write request base address 1, used when write_addr_index = 1
	input[ADDR_BITS - 1:0]           write_addr_2,               // data write module write request base address 1, used when write_addr_index = 2
	input[ADDR_BITS - 1:0]           write_addr_3,               // data write module write request base address 1, used when write_addr_index = 3
	input[1:0]                       write_addr_index,           // select valid base address from write_addr_0 write_addr_1 write_addr_2 write_addr_3
	input[ADDR_BITS - 1:0]           write_len,                  // data write module write request data length
	input                            write_en,                   // data write module write request for one data
	input[WRITE_DATA_BITS - 1:0]     write_data,                // write data
    output write_ready

);
assign write_ready=1;
assign App_rd_en=0;assign App_rd_addr=0;assign App_wr_en=0;assign App_wr_addr=0;assign App_wr_din=0;assign App_wr_dm=0;
assign read_req_ack=read_req;assign write_req_ack=write_req;assign read_finish=0;assign write_finish=0;
assign read_data=32'h23456700;
endmodule

module sdram(input Clk,Clk_sft,Clk90,Rst,output Sdr_init_done,Sdr_init_ref_vld,Sdr_busy,
 input App_wr_en,input [20:0] App_wr_addr,input [3:0] App_wr_dm,input [31:0] App_wr_din,
 input App_rd_en,input [20:0] App_rd_addr,output Sdr_rd_en,output [31:0] Sdr_rd_dout);
assign Sdr_init_done=!Rst;assign Sdr_init_ref_vld=0;assign Sdr_busy=0;assign Sdr_rd_en=0;assign Sdr_rd_dout=0;
endmodule

module hdmi_1_4b_transmitter_core_wrapper#(
    parameter DEVICE            = "EG", //"EF2","EF3","EF4","SF1","SF2","EG","PH1A","PH1P","DR1","PH2A"

    parameter HTOTAL            = 2200,
    parameter HSA               = 44,
    parameter HFP               = 88,
    parameter HBP               = 148,
    parameter HACTIVE           = 1920,
    parameter VTOTAL            = 1125,
    parameter VSA               = 5,
    parameter VFP               = 4,
    parameter VBP               = 36,
    parameter VACTIVE           = 1080,

    parameter VIDEO_TPG         = "Enable",
    parameter VIDEO_FORMAT      = "RGB",
    parameter VIDEO_VIC         = 16,

    parameter AUDIO_SAMPLE_RATE = "48K",

    parameter IIC_SCL_DIV       = 125
)(
    input wire       I_pixel_clk,
    input wire       I_rst,

    /*
        edid read interface 
    */
    input wire       I_edid_read_trig,
    output wire      O_edid_read_valid,
    output wire[7:0] O_edid_read_data,

    /*
        video interface 
    */
    input wire       I_axis_s_user,
    input wire       I_axis_s_valid,
    input wire       I_axis_s_last,
    input wire[23:0] I_axis_s_data,
    output wire      O_axis_s_ready,

    /*
        audio interface 
    */
    input wire       I_audio_valid,     
    input wire[23:0] I_audio_left_data, 
    input wire[23:0] I_audio_right_data,

    /*
        audio regenaration interface
    */
    input wire       I_acr_valid,
    input wire[19:0] I_acr_cts,
    input wire[19:0] I_acr_n,

    /*
        status signal
    */
    output wire      O_video_locked,

    /*
        DDC channel interface
    */
    output wire      O_ddc_scl,
    inout wire       IO_ddc_sda,

    /*
        tmds data interface 
    */
    output wire[9:0] O_ch0_tmds_data,
    output wire[9:0] O_ch1_tmds_data,
    output wire[9:0] O_ch2_tmds_data,
    output wire[9:0] O_clk_tmds_data
);
reg [9:0] cycles;
always @(posedge I_pixel_clk)if(I_rst)cycles<=0;else cycles<=cycles+1'b1;
assign O_axis_s_ready=(cycles>=4);
assign O_edid_read_valid=0;assign O_edid_read_data=0;assign O_video_locked=!I_rst;
assign O_ddc_scl=1;assign IO_ddc_sda=1'bz;
assign O_ch0_tmds_data=0;assign O_ch1_tmds_data=0;assign O_ch2_tmds_data=0;assign O_clk_tmds_data=0;
endmodule

module hdmi_phy_wrapper#(
    parameter DEVICE = "EG"
    )(
    input wire      I_pixel_clk,
    input wire      I_serial_clk,
    input wire      I_rst,

    input wire[9:0] I_tmds_channel_0,
    input wire[9:0] I_tmds_channel_1,
    input wire[9:0] I_tmds_channel_2,
    input wire[9:0] I_tmds_channel_clk,
    
    output wire     O_tmds_ch0_p,
    output wire     O_tmds_ch1_p,
    output wire     O_tmds_ch2_p,
    output wire     O_tmds_clk_p
);
assign O_tmds_ch0_p=0;assign O_tmds_ch1_p=0;assign O_tmds_ch2_p=0;assign O_tmds_clk_p=I_pixel_clk;
endmodule
