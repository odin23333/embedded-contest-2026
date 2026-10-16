`timescale 1ns/1ps
module error_recovery_tb;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,key=0,fault=0,ready=0;reg[7:0] cause=0;
wire image_rst_n,retrying;wire[7:0] code;
error_recovery #(.RESET_CYCLES(4)) dut(clk,rst_n,key,fault,cause,ready,image_rst_n,retrying,code);
reg vs=1,de=0,alarm=0;wire[23:0] rgb;
error_osd osd(clk,rst_n,code,retrying,alarm,vs,de,24'h123456,rgb);
task tick;begin @(posedge clk);#1;end endtask
task frame;begin vs=1;tick;vs=0;tick;end endtask
integer i,px,py,fd,colored;
task render;input[255:0] name;input expect_banner;begin
 frame;fd=$fopen(name,"w");$fwrite(fd,"P3\n640 80\n255\n");colored=0;
 for(py=0;py<80;py=py+1)begin
  for(px=0;px<640;px=px+1)begin
   @(negedge clk);de=1;#1;
   $fwrite(fd,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
   if(rgb!==24'h123456)colored=colored+1;
   if((py<28 || py>=70 || px<8 || px>=632) && rgb!==24'h123456)$fatal(1,"Banner altered outside rectangle");
  end
  @(negedge clk);de=0;repeat(2)tick;
 end
 $fclose(fd);
 if(expect_banner && colored==0)$fatal(1,"No banner pixels");
 if(!expect_banner && colored!=0)$fatal(1,"Emergency pixels obscured");
end endtask
initial begin
 tick;rst_n=1;tick;
 if(!image_rst_n || code || retrying)$fatal(1,"Boot reset state");
 cause=8'h17;fault=1;ready=1;tick;
 if(code!=8'h17)$fatal(1,"Capture first cause");
 cause=8'h00;tick;if(code!=8'h17)$fatal(1,"Cause not sticky");
 frame;if(!osd.show || osd.retry)$fatal(1,"No error banner");
 cause=8'h30;tick;if(osd.code!=8'h17)$fatal(1,"Banner changed midframe");
 key=1;tick;key=0;
 if(image_rst_n || !retrying)$fatal(1,"Retry did not reset images");
 for(i=0;i<3;i=i+1)begin tick;if(image_rst_n)$fatal(1,"Short reset pulse");end
 fault=0;ready=0;tick;if(!image_rst_n)$fatal(1,"Reset not released");
 frame;if(!osd.retry)$fatal(1,"No retry banner");
 ready=1;tick;if(code || retrying)$fatal(1,"Success did not clear error");
 frame;if(osd.show)$fatal(1,"Success banner persisted");
 // Clean-state explicit reload and a failed retry must both remain bounded.
 key=1;tick;key=0;ready=0;repeat(4)tick;
 fault=1;cause=8'h03;tick;if(retrying || code!=3)$fatal(1,"Retry failure cause");
 repeat(15)tick;if(!image_rst_n)$fatal(1,"Automatic reset loop");
 render("recovery_error_preview.ppm",1);
 alarm=1;frame;if(osd.show)$fatal(1,"Error banner obscured emergency");
 render("recovery_alarm_preview.ppm",0);
 alarm=0;frame;if(!osd.show)$fatal(1,"Error lost after emergency");
 key=1;tick;key=0;fault=0;ready=0;repeat(4)tick;render("recovery_retry_preview.ppm",1);
 rst_n=0;fault=0;tick;rst_n=1;tick;if(code || retrying)$fatal(1,"Full reset failed");
 $display("PASS ERROR_RECOVERY: sticky cause, bounded image reset, retry success/failure, frame latch and emergency priority");$finish;
end
endmodule
