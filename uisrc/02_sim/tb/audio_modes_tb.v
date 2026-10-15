`timescale 1ns/1ps
module audio_modes_tb;
integer loop,checked=0;reg warmed=0;
reg mclk=0,clk=0,rst=1;always #40.690104 mclk=~mclk;always #20 clk=~clk;
reg [1:0] status=0;wire tb,tl,td,ab,al,ad,serial,valid;wire [23:0] left,right;
hdmi_audio_tone_i2s_64fs normal(mclk,rst,tb,tl,td);
alert_i2s #(.HALF_BEEP_FRAMES(1000)) alarm(mclk,~rst,status[0],status[1],ab,al,ad,);
audio_mode_mux mux(mclk,~rst,status,td,ad,serial);
I2S_receiver receiver(clk,rst,ab,al,serial,valid,left,right);
always @(posedge valid)begin
 #2;if(warmed)begin
  if(left!==right)$fatal(1,"Transient stereo mismatch");
  if($signed(left)!=0 && $signed(left)!=2000000 && $signed(left)!=-2000000 && $signed(left)!=500000 && $signed(left)!=-500000)$fatal(1,"Illegal transient PCM amplitude");
  checked=checked+1;
 end
end
task samples;input integer n;input integer expected;integer i;begin
 for(i=0;i<n;i=i+1)begin @(posedge valid);#1;
  if(expected==0)begin if(left!==0 || right!==0)$fatal(1,"Mute failed");end
  else if(($signed(left)!=expected && $signed(left)!=-expected) || ($signed(right)!=expected && $signed(right)!=-expected))$fatal(1,"Invalid PCM left=%d right=%d",$signed(left),$signed(right));
 end
end endtask
task settle;begin repeat(5)@(posedge valid);end endtask
initial begin
 repeat(4)@(negedge mclk);rst=0;settle;warmed=1;samples(10,2000000);
 for(loop=0;loop<50;loop=loop+1)begin
 // Changes deliberately occur midway through an I2S slot.
 #1500;status=1;settle;samples(10,500000);
 #2300;status=3;settle;samples(10,0);
 #1800;status=0;settle;samples(10,2000000);
 end
 $display("PASS AUDIO_MODES: 50 repeated cycles including transition PCM checks; real I2S decoding of normal/alarm/mute/resume, stereo amplitude and slot-boundary switching");$finish;
end
initial begin #100000000;$fatal(1,"Timeout");end
endmodule
