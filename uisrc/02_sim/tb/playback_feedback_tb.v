`timescale 1ns/1ps
module playback_feedback_tb;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,pause=0,auto_en=1,next=0,valid=1,multiple=1,busy=0,ready=1;
wire request,pending;wire[2:0] remaining;
playback_scheduler #(.AUTO_CYCLES(50)) schedule(clk,rst_n,pause,auto_en,next,valid,multiple,busy,ready,request,pending,remaining);
reg[9:0] meta=0;reg[2:0] seconds=5;reg mode=0,queued=0,image_valid=1,alarm=0,fault=0,retry=0;
reg[4:0] gain=16;reg hs=0,vs=1,de=0;reg[23:0] rgb=24'h37566d;
wire oh,ov,od;wire[23:0] out;
playback_osd osd(clk,rst_n,meta,seconds,mode,queued,image_valid,alarm,fault,retry,gain,hs,vs,de,rgb,oh,ov,od,out);
task tick;begin @(posedge clk);#1;end endtask
task frame;begin @(negedge clk);vs=1;tick;@(negedge clk);vs=0;tick;end endtask
integer i,xx,yy,fd,changed;reg[23:0] expect_rgb;
reg[319:0] expected_top,expected_bottom;
task render;input[255:0] filename;input want_panel;begin
 frame;fd=$fopen(filename,"w");$fwrite(fd,"P3\n640 480\n255\n");changed=0;
 for(yy=0;yy<480;yy=yy+1)begin
  for(xx=0;xx<640;xx=xx+1)begin
   @(negedge clk);de=1;#1;expect_rgb=osd.color;
   if(want_panel && xx==16 && yy==398 && osd.text!==expected_top)$fatal(1,"Wrong picture/cache label: %s",osd.text);
   if(want_panel && xx==16 && yy==418 && osd.text!==expected_bottom)$fatal(1,"Wrong playback label: %s",osd.text);
   tick;
   if(out!==expect_rgb || od!==de || oh!==hs || ov!==vs)$fatal(1,"RGB/sync register alignment");
   if(out!==rgb)changed=changed+1;
   if((xx<8 || xx>=632 || yy<394 || yy>=436) && out!==rgb)$fatal(1,"Panel altered image/timestamp outside bounds");
   $fwrite(fd,"%0d %0d %0d\n",out[23:16],out[15:8],out[7:0]);
  end
  @(negedge clk);de=0;repeat(2)tick;
 end
 $fclose(fd);
 if(want_panel && changed==0)$fatal(1,"No panel pixels");
 if(!want_panel && changed!=0)$fatal(1,"Panel hides emergency/fault");
end endtask
initial begin
 tick;rst_n=1;#1;
 if(remaining!=5)$fatal(1,"Timer startup");
 for(i=1;i<50;i=i+1)begin
  tick;if(remaining!==(5-i/10))$fatal(1,"Countdown not derived from scheduler at %0d: %d",i,remaining);
 end
 tick;if(!pending || remaining!=0 || !request)$fatal(1,"Timer deadline/queued request");
 tick;if(pending || remaining!=5)$fatal(1,"Accepted request not reset");
 busy=1;tick;if(remaining!=0)$fatal(1,"Countdown during loading");
 busy=0;pause=1;tick;if(remaining!=0)$fatal(1,"Countdown during pause");
 pause=0;auto_en=0;tick;if(remaining!=0)$fatal(1,"Manual countdown");
 auto_en=1;multiple=0;tick;if(remaining!=0)$fatal(1,"Single image countdown");
 multiple=1;valid=0;tick;if(remaining!=0)$fatal(1,"Invalid image countdown");
 valid=1;next=1;tick;if(remaining!=0)$fatal(1,"Manual request countdown");
 next=0;tick;auto_en=0;
 meta={1'b0,1'b1,1'b1,3'd4,2'd1,2'd0};
 expected_top="PIC 1/4  NEXT 2/4  CACHE READY          ";
 expected_bottom="MANUAL    KEY1 NEXT  KEY2 AUTO          ";
 render("feedback_manual.ppm",1);
 // Frame snapshot must retain the old tuple until the next vertical boundary.
 meta={1'b0,1'b1,1'b0,3'd4,2'd3,2'd2};mode=1;seconds=3;
 if(osd.info[1:0]!=0 || osd.frame_auto)$fatal(1,"Mid-frame metadata update");
 expected_top="PIC 3/4  NEXT 4/4  CACHE LOAD           ";
 expected_bottom="AUTO 03S  KEY1 NEXT  KEY2 STOP          ";
 render("feedback_auto.ppm",1);
 queued=1;expected_bottom="WAIT NEXT IMAGE - REQUEST QUEUED        ";render("feedback_wait.ppm",1);
 gain=8;expected_bottom="SWITCHING IMAGE - PLEASE WAIT           ";render("feedback_switch.ppm",1);
 gain=16;queued=0;alarm=1;render("feedback_alarm.ppm",0);
 alarm=0;fault=1;render("feedback_fault.ppm",0);
 fault=0;retry=1;render("feedback_retry.ppm",0);
 retry=0;image_valid=0;render("feedback_invalid.ppm",0);
 image_valid=1;mode=0;meta={1'b0,1'b0,1'b0,3'd1,2'd0,2'd0};
 expected_top="PIC 1/1  NEXT -/-  CACHE N/A            ";
 expected_bottom="MANUAL    KEY1 NEXT  KEY2 AUTO          ";
 render("feedback_single.ppm",1);
 $display("PASS PLAYBACK_FEEDBACK: actual scheduler 5..1/deadline/gating, frame tuple, exact labels, cache/wait/fade/auto, RGB/sync/bounds and priority");$finish;
end
endmodule
