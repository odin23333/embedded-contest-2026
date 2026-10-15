`timescale 1ns/1ps
// Coordinates describe the delayed input RGB/DE stream, not an earlier VTC.
// Both emergency content and the status bar change only at vertical blanking.
module video_compositor #(parameter BRIGHTNESS_ENABLED=0,parameter TIMESTAMP_ENABLED=0,parameter ALARM_FLASH_ENABLED=0)(input clk,rst_n,input [5:0] status,input [1:0] brightness,
 input hs,vs,de,input [23:0] rgb,output frame_start,
 output out_hs,out_vs,out_de,output [23:0] out_rgb,input [23:0] timestamp_bcd,input timestamp_valid,input alarm_flash);
reg frame_flash;reg vs_prev,de_prev,frame_alarm,frame_valid;reg [1:0] frame_brightness;reg [9:0] x,y;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin vs_prev<=0;de_prev<=0;x<=0;y<=0;frame_alarm<=0;frame_valid<=0;frame_brightness<=3;frame_flash<=0;end
 else begin
  vs_prev<=vs;de_prev<=de;
  if(frame_start)begin x<=0;y<=0;frame_alarm<=status[0];frame_valid<=status[4];frame_brightness<=brightness;frame_flash<=alarm_flash;end
  else if(de)x<=x+1'b1;
  else begin x<=0;if(de_prev)y<=y+1'b1;end
 end
end
assign frame_start=vs_prev && !vs;
wire [23:0] screen_rgb,normal_rgb;
generate if(BRIGHTNESS_ENABLED)begin:brightness_image
 brightness_rgb gain(rgb,frame_brightness,normal_rgb);
end else begin:original_image
 assign normal_rgb=rgb;
end endgenerate
alarm_screen #(.FLASH_ENABLED(ALARM_FLASH_ENABLED)) screen(x,y,frame_alarm,frame_valid?normal_rgb:24'd0,screen_rgb,frame_flash);
wire [23:0] timestamp_rgb;
generate if(TIMESTAMP_ENABLED)begin:clock_overlay
 timestamp_osd clock_panel(clk,rst_n,frame_start,frame_valid&&!frame_alarm,timestamp_valid,timestamp_bcd,x,y,de,screen_rgb,timestamp_rgb);
end else begin:no_clock
 assign timestamp_rgb=screen_rgb;
end endgenerate
status_osd bar(clk,rst_n,frame_start,status,x,y,hs,vs,de,timestamp_rgb,
 out_hs,out_vs,out_de,out_rgb);
endmodule
