`timescale 1ns/1ps
module alarm_sync_tb;
reg clk=0;always #20 clk=~clk;
reg rst=0,emergency=0,muted=0;
wire b,l,d,flash;
alert_i2s #(.HALF_BEEP_FRAMES(2)) tone(clk,rst,emergency,muted,b,l,d,flash);
wire pixel_flash;
level_sync #(.WIDTH(1)) cdc(clk,rst,flash,pixel_flash);
reg hs=0,vs=0,de=0;reg[5:0] status=0;
wire fs,oh,ov,od;wire[23:0] rgb;
video_compositor #(.ALARM_FLASH_ENABLED(1)) comp(clk,rst,status,2'd3,hs,vs,de,24'h123456,fs,oh,ov,od,rgb,24'd0,1'b0,pixel_flash);
reg[9:0] tx=208,ty=80;wire[23:0] text_rgb;
alarm_screen #(.FLASH_ENABLED(1)) text_screen(tx,ty,1'b1,24'd0,text_rgb,flash);
integer samples=0,bright=0,dark=0;reg check_audio=0;
always @(negedge clk)begin
 if(check_audio && tone.bit_count==0 && tone.lrck==0 && tone.bclk==0)begin
  samples=samples+1;
  if(flash)bright=bright+1;else dark=dark+1;
  if((tone.sample!=0)!==(flash && !muted))$fatal(1,"Audio PCM and visual envelope disagree");
  if(text_rgb!==24'hffffff)$fatal(1,"Emergency Chinese glyph disappeared in dark half");
 end
end
task new_frame;begin
 @(negedge clk);vs=1;repeat(3)@(negedge clk);vs=0;repeat(3)@(negedge clk);
end endtask
reg[23:0] saved_rgb;
initial begin
 repeat(4)@(negedge clk);rst=1;emergency=1;status=1;
 repeat(600)@(negedge clk);check_audio=1;
 repeat(8)begin
  wait(pixel_flash==1);new_frame();if(rgb!==24'hfbbf24)$fatal(1,"Bright border missing");
  saved_rgb=rgb;wait(pixel_flash==0);repeat(4)@(negedge clk);
  if(rgb!==saved_rgb)$fatal(1,"Visual changed mid-frame");
  new_frame();if(rgb!==24'h78350f)$fatal(1,"Dark border missing");
 end
 check_audio=0;muted=1;repeat(600)@(negedge clk);check_audio=1;
 repeat(2000)@(negedge clk);check_audio=0;
 if(samples<10 || bright<4 || dark<4)$fatal(1,"Missing repeated flash or mute coverage");
 muted=0;repeat(600)@(negedge clk);check_audio=1;repeat(2000)@(negedge clk);check_audio=0;
 emergency=0;status=6'b010000;repeat(600)@(negedge clk);new_frame();
 if(flash!==0 || rgb!==24'h123456)$fatal(1,"Emergency exit did not restore image");
 rst=0;repeat(4)@(negedge clk);if(flash!==0)$fatal(1,"Reset leaves flash active");
 $display("PASS ALARM_SYNC: PCM/shared envelope alignment, repeated bright/dark, clear Chinese text, frame-atomic CDC, mute/resume/exit/reset");$finish;
end
initial begin #10000000;$fatal(1,"Timeout");end
endmodule

