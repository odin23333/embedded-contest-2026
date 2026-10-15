`timescale 1ns/1ps
module brightness_compositor_tb;
reg clk=0,rst_n=0,hs=0,vs=0,de=0;reg [5:0] status=0;reg [1:0] brightness=3;reg [23:0] rgb=0;
wire f1,f0,h1,v1,d1,h0,v0,d0;wire [23:0] adjusted,original;
video_compositor #(.BRIGHTNESS_ENABLED(1)) enabled(clk,rst_n,status,brightness,hs,vs,de,rgb,f1,h1,v1,d1,adjusted,24'd0,1'b0,1'b1);
video_compositor #(.BRIGHTNESS_ENABLED(0)) disabled(clk,rst_n,status,brightness,hs,vs,de,rgb,f0,h0,v0,d0,original,24'd0,1'b0,1'b1);
integer frame,x,y,fd,i;reg [23:0] expected;
function [7:0] reference;input [7:0] c;input integer gain;integer value;begin
 case(gain)3:value=c;2:value=(c*3)/4;1:value=c/2;default:value=c/4;endcase
 reference=value;
end endfunction
always #20 clk=~clk;
initial begin
 repeat(4)@(negedge clk);rst_n=1;
 // Four gains, emergency at dimmest preference, then restored preference.
 for(frame=0;frame<6;frame=frame+1)begin
  brightness=frame<4?3-frame:0;status=frame==4?6'b010001:6'b010010;
  de=0;vs=1;@(negedge clk);vs=0;@(negedge clk);vs=1;
  fd=$fopen($sformatf("week6_brightness_%0d.ppm",frame),"w");$fwrite(fd,"P3\n640 480\n255\n");
  for(y=0;y<480;y=y+1)begin
   for(x=0;x<640;x=x+1)begin
    @(negedge clk);de=1;hs=1;rgb={x[7:0],y[7:0],8'hff};
    if(x==300 && y==240)brightness=3; // Must not change this frame.
    @(posedge clk);#1;
    if({h1,v1,d1}!={h0,v0,d0} || f1!==f0)$fatal(1,"Brightness changed stream latency/sync");
    if(frame==4 || y<24)begin if(adjusted!==original)$fatal(1,"Emergency/status was dimmed");end
    else begin
     i=frame<4?3-frame:0;expected={reference(rgb[23:16],i),reference(rgb[15:8],i),reference(rgb[7:0],i)};
     if(adjusted!==expected || original!==rgb)$fatal(1,"Frame latch/scaling/bypass failure f%0d x%0d y%0d",frame,x,y);
    end
    $fwrite(fd,"%0d %0d %0d\n",adjusted[23:16],adjusted[15:8],adjusted[7:0]);
   end
   @(negedge clk);de=0;hs=0;@(posedge clk);#1;if(d1||h1)$fatal(1,"Blanking mismatch");
  end
  $fclose(fd);@(negedge clk);de=0;
 end
 $display("PASS BRIGHTNESS_COMPOSITOR: 6 full frames/1843200 pixels; four gains, frame-atomic update, original bypass, full-strength alarm/status and preference restore");$finish;
end
initial begin #100000000;$fatal(1,"Timeout");end
endmodule
