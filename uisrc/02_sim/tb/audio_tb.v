`timescale 1ns/1ps
module audio_tb;
reg mclk=0,clk=0,rst=1;
always #40.690104 mclk=~mclk;
always #20 clk=~clk;
wire bclk,lrck,dout,valid,acrvalid;
wire [23:0] left,right;wire [19:0] cts,n;
integer count=0,acrs=0,fd,positive=0,negative=0;
real previous=0,delta;
reg prevvalid=0;
hdmi_audio_tone_i2s_64fs tone(mclk,rst,bclk,lrck,dout);
I2S_receiver rx(clk,rst,bclk,lrck,dout,valid,left,right);
audio_arc_calculate acr(clk,rst,valid,acrvalid,cts,n);
always @(posedge clk) begin
 #1;
 if(!rst && valid) begin
  count=count+1;
  if(prevvalid) $fatal(1,"audio_valid wider than one cycle");
  if(count>4) begin
   delta=$realtime-previous;
   if(delta<20800 || delta>20880) $fatal(1,"Sample interval %f",delta);
   if(left!==right) $fatal(1,"Stereo mismatch %h %h",left,right);
   if($signed(left)!=2000000 && $signed(left)!=-2000000) $fatal(1,"Sample amplitude %h",left);
   if($signed(left)>0)positive=positive+1;else negative=negative+1;
   $fdisplay(fd,"%0d",$signed(left));
  end
  previous=$realtime;
  if(count==2404) begin
   if(acrs<49 || positive<100 || negative<100) $fatal(1,"Missing audio or ACR");
   $fclose(fd);
   $display("PASS AUDIO: 2400 stereo samples, nominal 48kHz, +/-2000000, ACR N=6144 and CTS near 25000");$finish;
  end
 end
 if(!rst && acrvalid) begin
  acrs=acrs+1;
  if(acrs>1 && (n!=6144 || cts<24998 || cts>25002)) $fatal(1,"ACR cts=%0d n=%0d",cts,n);
 end
 prevvalid=valid;
end
initial begin fd=$fopen("audio_samples.txt","w");#400;rst=0;end
initial begin #60000000;$fatal(1,"Timeout");end
endmodule
