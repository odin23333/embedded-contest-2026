`timescale 1ns/1ps
module recovery_top_tb;
reg clk=0;always #20 clk=~clk;
wire[3:0] rows;wire[7:0] led;
top dut(.clk(clk),.key_col(4'hf),.key_row(rows),.led(led),.sd_miso(1'b1),.UART_RX(1'b1));
defparam dut.storage_guard.TIMEOUT_CYCLES=1000000;
task tick;begin @(posedge clk);#1;end endtask
reg[15:0] injected;
task press;input[15:0] k;begin injected=k;force dut.keys_pressed=injected;tick;release dut.keys_pressed;tick;end endtask
reg[23:0] saved_time;
initial begin
 wait(dut.rst_n);repeat(20)tick;
 force dut.sd_card_bmp_m0.display_valid=1'b1;
 force dut.sd_card_bmp_m0.card_initialized=1'b1;
 force dut.sd_card_bmp_m0.storage_progress=1'b1;
 press(16'h0004);if(!dut.emergency)$fatal(1,"Alarm not armed");
 press(16'h0008);if(!dut.muted)$fatal(1,"Mute not armed");
 force dut.sd_card_bmp_m0.storage_error_code=8'h17;
 force dut.sd_card_bmp_m0.storage_error=1'b1;
 repeat(5)tick;if(dut.error_code!=8'h17 || !dut.storage_fault)$fatal(1,"Fault code wiring");
 press(16'h0020);if(dut.image_rst_n)$fatal(1,"KEY6 image reset not asserted");
 if(!dut.rst_n || !dut.video_rst_n || !dut.audio_rst_n)$fatal(1,"Retry reset unrelated subsystem");
 if(!dut.emergency || !dut.muted)$fatal(1,"Retry lost emergency/mute");
 force dut.sd_card_bmp_m0.display_valid=1'b0;
 force dut.sd_card_bmp_m0.storage_error=1'b0;
 force dut.sd_card_bmp_m0.storage_error_code=8'd0;
 repeat(1035)tick;
 if(!dut.image_rst_n || dut.storage_fault || dut.memory_lost)$fatal(1,"Image reset did not recover DDR watchdog");
 if(!dut.emergency || !dut.muted || !dut.retrying)$fatal(1,"Retry state/control lost");
 force dut.sd_card_bmp_m0.display_valid=1'b1;repeat(5)tick;
 if(dut.retrying || dut.error_code)$fatal(1,"Ready did not complete retry");
 press(16'h0004);if(dut.emergency)$fatal(1,"Alarm exit after retry");
 $display("PASS RECOVERY_TOP: KEY6 wiring, image/DDR reset, fault clear and preserved alarm/mute/HDMI domains");$finish;
end
initial begin #15000000;$fatal(1,"Recovery integration timeout");end
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
    parameter integer EXTERNAL_CONTROL = 0,parameter integer PREFETCH_ENABLED=0,parameter integer FAT32_ENABLED=0,parameter integer IMAGE_SCALING_ENABLED=0,
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
    output storage_active,storage_progress,storage_error,output card_initialized,output [7:0] storage_error_code,output [9:0] playback_info,
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
assign playback_info=0;assign card_initialized=0;assign storage_error_code=0;
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
