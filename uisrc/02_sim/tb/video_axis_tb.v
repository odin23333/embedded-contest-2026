`timescale 1ns/1ps
module video_axis_tb;
reg clk=0,rst=1,vs=1,de=0;
reg [23:0] rgb=0;
wire user,valid,last; wire [23:0] data;
integer f,y,x,sof=0,eol=0,pixels=0;
always #20 clk=~clk;
video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,user,valid,last,data);
task sample;
input v,d;input [23:0] c;input u,l;
begin
 @(negedge clk);vs=v;de=d;rgb=c;
 @(posedge clk);#1;
 if(valid!==d || data!==c || user!==u || last!==l)
   $fatal(1,"AXIS mismatch frame=%0d y=%0d x=%0d valid=%b user=%b last=%b expected last=%b",f,y,x,valid,user,last,l);
 if(valid) pixels=pixels+1;
 if(user) sof=sof+1;
 if(last) eol=eol+1;
end endtask
initial begin
 repeat(4) @(negedge clk);rst=0;
 for(f=0;f<2;f=f+1) begin
  sample(0,0,0,0,0);sample(1,0,0,0,0);
  for(y=0;y<480;y=y+1) begin
   for(x=0;x<640;x=x+1) sample(1,1,(y*640+x),y==0&&x==0,x==639);
   repeat(160) sample(1,0,0,0,0);
  end
 end
 if(sof!=2 || eol!=960 || pixels!=614400) $fatal(1,"Counts incorrect");
 $display("PASS VIDEO_AXIS: two frames; 614400 pixels; 960 EOL; 2 SOF; exact RGB and one-cycle latency");$finish;
end
initial begin #40000000;$fatal(1,"Timeout");end
endmodule
