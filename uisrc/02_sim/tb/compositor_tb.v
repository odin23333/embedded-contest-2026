`timescale 1ns/1ps
module compositor_tb;
reg clk=0,rst_n=0,hs=0,vs=0,de=0;reg [23:0] rgb=0;reg [5:0] status=0;
wire fs,oh,ov,od;wire [23:0] pixel;
video_compositor dut(clk,rst_n,status,2'd3,hs,vs,de,rgb,fs,oh,ov,od,pixel,24'd0,1'b0,1'b1);
integer f,xx,yy,fd,pixels=0,title_white=0,body_white=0,key_white=0;
reg [23:0] first_line_bg;
always #20 clk=~clk;
initial begin
 repeat(4)@(negedge clk);rst_n=1;
 for(f=0;f<4;f=f+1)begin
  status=f==3?6'b110010:(f==1?6'b010001:6'b010010);de=0;vs=1;
  @(negedge clk);vs=0;@(negedge clk);vs=1;
  if(f==0)fd=$fopen("week4_normal.ppm","w");else if(f==1)fd=$fopen("week4_alarm.ppm","w");else if(f==2)fd=$fopen("week4_resume.ppm","w");else fd=$fopen("week4_fault.ppm","w");
  $fwrite(fd,"P3\n640 480\n255\n");
  for(yy=0;yy<480;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+1)begin
    @(negedge clk);hs=1;de=1;rgb={xx[7:0],yy[7:0],8'h60};
    if(xx==300 && yy==0)status=~status;
    @(posedge clk);#1;
    if(!od || !oh || !ov)$fatal(1,"Compositor sync misaligned");
    if(f!=1 && yy>=24 && pixel!==rgb)$fatal(1,"Normal/resume image corrupted");
    if(f==1 && yy==200 && xx==0 && pixel!==24'hfbbf24)$fatal(1,"Emergency border missing");
    if(f==3 && yy==0 && xx==550 && pixel!==24'hb91c1c)$fatal(1,"FAULT panel missing or tore");
    if(yy==0 && xx==100)first_line_bg=pixel;
    if(f==1 && pixel==24'hffffff)begin
     if(yy>=80&&yy<144)title_white=title_white+1;
     if(yy>=190&&yy<292)body_white=body_white+1;
     if(yy>=365&&yy<381)key_white=key_white+1;
    end
    $fwrite(fd,"%0d %0d %0d\n",pixel[23:16],pixel[15:8],pixel[7:0]);pixels=pixels+1;
   end
   @(negedge clk);de=0;hs=0;@(posedge clk);#1;
   if(od || oh)$fatal(1,"Blanking sync corrupted");
  end
  if(first_line_bg!==(f==1?24'hb91c1c:24'h166534))$fatal(1,"Status changed within frame");
  $fclose(fd);@(negedge clk);de=0;
 end
 if(pixels!=1228800 || title_white<1000 || body_white<400 || key_white<100)$fatal(1,"Emergency text missing");
 $display("PASS COMPOSITOR: 4 full 640x480 frames, normal/alarm/resume/fault, mid-frame status isolation, Chinese text and aligned RGB/sync");$finish;
end
initial begin #80000000;$fatal(1,"Timeout");end
endmodule
