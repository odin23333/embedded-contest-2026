`timescale 1ns/1ps
module timestamp_tb;
reg clk=0,rst_n=0,fs=0,visible=1,tvalid=1,de=1;reg[23:0] t=24'h125959,rgb=24'habcdef;reg[9:0]x=500,y=450;
wire[23:0] pixel;integer xx,yy,white=0;
always #5 clk=~clk;
timestamp_osd dut(clk,rst_n,fs,visible,tvalid,t,x,y,de,rgb,pixel);
task frame;begin @(negedge clk);fs=1;@(negedge clk);fs=0;end endtask
initial begin
 repeat(4)@(negedge clk);rst_n=1;frame;
 #1;if(pixel!=rgb)$fatal(1,"Outside panel changed");
 x=516;#1;if(pixel!=24'h38bdf8)$fatal(1,"Panel border missing");
 x=518;#1;if(pixel!=24'h0f172a)$fatal(1,"Panel background missing");
 for(yy=447;yy<461;yy=yy+1)for(xx=524;xx<620;xx=xx+1)begin x=xx;y=yy;#1;if(pixel==24'hffffff)white=white+1;end
 if(white<100)$fatal(1,"Time digits not drawn");
 t=24'h130000;#1;if(dut.frame_time!=24'h125959)$fatal(1,"Timestamp changed within frame");frame;if(dut.frame_time!=24'h130000)$fatal(1,"Timestamp not latched");
 visible=0;frame;x=518;y=450;#1;if(pixel!=rgb)$fatal(1,"Emergency overlay not hidden");
 visible=1;tvalid=0;frame;#1;if(dut.text!=="--:--:--")$fatal(1,"Invalid time must be placeholder");
 de=0;#1;if(pixel!=rgb)$fatal(1,"Blanking modified");
 $display("PASS TIMESTAMP: bottom-right bounds, glyphs, frame-atomic rollover, invalid placeholder, emergency hide and RGB passthrough");$finish;
end
endmodule
