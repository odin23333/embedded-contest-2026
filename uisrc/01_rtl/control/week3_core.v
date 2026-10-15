`timescale 1ns/1ps
// Module integration harness, not an HX4S20 board top (no pin assignments/PLL).
module week3_core #(
 parameter integer DEBOUNCE_CYCLES=500000,LONG_CYCLES=25000000,
 parameter integer AUTO_CYCLES=125000000,HALF_BEEP_FRAMES=12000
)(
 input wire ctrl_clk,pixel_clk,audio_mclk,arst_n,
 input wire key_next_n,key_auto_n,
 input wire display_valid,has_multiple,load_busy,load_ready,
 output wire next_valid,pending_request,emergency,muted,auto_enabled,
 input wire frame_start,input wire [9:0] x,y,
 input wire hs,vs,de,input wire [23:0] rgb,
 output wire out_hs,out_vs,out_de,output wire [23:0] out_rgb,
 output wire audio_bclk,audio_lrck,audio_dout
);
wire ctrl_rst_n,pixel_rst_n,audio_rst_n;
reset_sync rc(ctrl_clk,arst_n,ctrl_rst_n);
reset_sync rv(pixel_clk,arst_n,pixel_rst_n);
reset_sync ra(audio_mclk,arst_n,audio_rst_n);
wire next_short,next_long,auto_short,auto_long,next_event;
key_gesture #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.LONG_CYCLES(LONG_CYCLES))
 kn(ctrl_clk,ctrl_rst_n,key_next_n,next_short,next_long),
 ka(ctrl_clk,ctrl_rst_n,key_auto_n,auto_short,auto_long);
mode_control modes(ctrl_clk,ctrl_rst_n,next_short,auto_short,next_long,auto_long,
                   emergency,muted,auto_enabled,next_event);
playback_scheduler #(.AUTO_CYCLES(AUTO_CYCLES))
 player(ctrl_clk,ctrl_rst_n,emergency|next_long,auto_enabled,next_event,
        display_valid,has_multiple,load_busy,load_ready,next_valid,pending_request);
wire [4:0] video_status;
wire [1:0] audio_status;
level_sync #(.WIDTH(5)) sv(pixel_clk,pixel_rst_n,{display_valid,load_busy,muted,auto_enabled,emergency},video_status);
level_sync #(.WIDTH(2)) sa(audio_mclk,audio_rst_n,{muted,emergency},audio_status);
status_osd osd(pixel_clk,pixel_rst_n,frame_start,video_status,x,y,hs,vs,de,rgb,
               out_hs,out_vs,out_de,out_rgb);
alert_i2s #(.HALF_BEEP_FRAMES(HALF_BEEP_FRAMES))
 tone(audio_mclk,audio_rst_n,audio_status[0],audio_status[1],audio_bclk,audio_lrck,audio_dout);
endmodule
