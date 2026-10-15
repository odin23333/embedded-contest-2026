`timescale 1ns/1ps
module brightness_tb;
reg clk=0,rst_n=0,press=0,pause=0;wire [1:0] level;
reg [23:0] rgb=0;reg [1:0] gain=0;wire [23:0] scaled;integer i,j,n;reg [7:0] inverse;
brightness_control control(clk,rst_n,press,pause,level);
brightness_rgb pixels(rgb,gain,scaled);
always #20 clk=~clk;
task cycles;input integer count;begin repeat(count)@(negedge clk);end endtask
task click;begin press=1;cycles(1);press=0;cycles(1);end endtask
initial begin
 cycles(3);rst_n=1;cycles(1);if(level!=3)$fatal(1,"Default gain is not full");
 for(i=0;i<100;i=i+1)begin click;if(level!==((2-i)&3))$fatal(1,"Cycle/wrap failure");end
 pause=1;repeat(10)click;if(level!=3)$fatal(1,"Emergency/fault pause did not preserve preference");
 pause=0;click;if(level!=2)$fatal(1,"Resume failed");rst_n=0;cycles(2);if(level!=3)$fatal(1,"Reset failed");
 // Exhaustive 256 byte values x four gains, independently calculated arithmetic.
 for(j=0;j<4;j=j+1)for(i=0;i<256;i=i+1)begin
  gain=j;inverse=255-i;rgb={i[7:0],inverse,i[7:0]};#1;
  n=j==3?i:(j==2?(i*3)/4:(j==1?i/2:i/4));
  if(scaled[23:16]!==n || scaled[7:0]!==n)$fatal(1,"Scaling overflow/rounding failure %0d gain %0d",i,j);
  n=j==3?255-i:(j==2?((255-i)*3)/4:(j==1?(255-i)/2:(255-i)/4));
  if(scaled[15:8]!==n)$fatal(1,"Channel independence failure");
 end
 $display("PASS BRIGHTNESS: 100 key cycles, pause/resume/reset, 1024 exhaustive RGB byte/gain combinations, integer floor and no overflow");$finish;
end
endmodule
