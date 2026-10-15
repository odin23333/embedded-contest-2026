`timescale 1ns/1ps
module fade_tb;
reg clk=0,rst_n=0,tick=0,valid=1,cancel=0,ready=0;reg[1:0] idx=0;reg[23:0] rgb=24'hff8040;
wire permit;wire[23:0] out;wire[4:0] gain;integer i;
always #5 clk=~clk;
image_fade dut(clk,rst_n,tick,valid,cancel,ready,idx,rgb,permit,out,gain);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
task check;input integer level;integer r,g,b;begin
 #1;if(gain!==level)$fatal(1,"Gain expected%0d got%0d",level,gain);
 r=255*level/16;g=128*level/16;b=64*level/16;
 if(out!=={r[7:0],g[7:0],b[7:0]})$fatal(1,"RGB scaling incorrect");
end endtask
initial begin
 repeat(3)@(negedge clk);rst_n=1;
 for(i=0;i<180;i=i+1)begin frame;check(16);if(permit)$fatal(1,"Commit before replacement loaded");end
 ready=1;frame;check(16);
 for(i=15;i>=0;i=i-1)begin frame;check(i);if(i>0 && permit)$fatal(1,"Commit before black");end
 if(!permit)$fatal(1,"No black commit permit");
 // Old/new DDR buffers must change only while output is completely black.
 idx=1;ready=0;frame;check(1);
 for(i=2;i<=16;i=i+1)begin frame;check(i);if(permit)$fatal(1,"Commit permit remained during fade-in");end
 // Gain cannot change partway through a frame.
 ready=1;frame;frame;check(15);repeat(30)@(negedge clk);check(15);
 cancel=1;frame;check(16);cancel=0;ready=0;frame;check(16);
 // No-image startup and errors do not dim on-chip emergency/status content.
 valid=0;ready=1;frame;check(16);if(permit)$fatal(1,"Startup not bypassed");
 valid=1;ready=0;frame;ready=1;frame;frame;check(15);ready=0;frame;check(16);
 $display("PASS FADE: loaded-ready gating, 16-frame fade-out, black-only commit, 16-frame fade-in, frame-atomic gain, abort/emergency/startup recovery and RGB scaling");$finish;
end
initial begin #100000;$fatal(1,"Timeout");end
endmodule
