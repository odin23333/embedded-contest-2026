`timescale 1ns/1ps
module time_uart #(parameter DIV=217)(input clk,rst_n,rx,input reply,reply_ok,output reg tx,
 output reg set_pulse,output reg [23:0] set_time);
reg [1:0] sync;reg [2:0] rs;reg [15:0] count;reg [2:0] bitno;reg [7:0] data;reg byte_valid;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin sync<=3;rs<=0;count<=0;bitno<=0;data<=0;byte_valid<=0;end
 else begin sync<={sync[0],rx};byte_valid<=0;
 case(rs)
 0:if(!sync[1])begin rs<=1;count<=DIV/2-1;end
 1:if(count!=0)count<=count-1'b1;else if(!sync[1])begin rs<=2;count<=DIV-1;bitno<=0;end else rs<=0;
 2:if(count!=0)count<=count-1'b1;else begin data[bitno]<=sync[1];count<=DIV-1;if(bitno==7)rs<=3;else bitno<=bitno+1'b1;end
 3:if(count!=0)count<=count-1'b1;else begin byte_valid<=sync[1];rs<=0;end
 default:rs<=0;
 endcase end
end
function valid_bcd;input[7:0] a;input[7:0] maxval;begin valid_bcd=a[3:0]<=9 && a[7:4]<=9 && a<=maxval;end endfunction
reg[2:0] packet;reg[7:0] hh,mm,ss,checksum;reg[23:0] timeout;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin packet<=0;set_pulse<=0;set_time<=0;hh<=0;mm<=0;ss<=0;checksum<=0;timeout<=0;end
 else begin set_pulse<=0;
 if(packet!=0)begin if(timeout==2500000)begin packet<=0;timeout<=0;end else timeout<=timeout+1'b1;end
 if(byte_valid)begin timeout<=0;
 case(packet)
 0:if(data==8'ha5)begin packet<=1;checksum<=8'ha5;end
 1:begin hh<=data;checksum<=checksum^data;packet<=2;end
 2:begin mm<=data;checksum<=checksum^data;packet<=3;end
 3:begin ss<=data;checksum<=checksum^data;packet<=4;end
 4:begin packet<=0;if(data==checksum && valid_bcd(hh,8'h23) && valid_bcd(mm,8'h59) && valid_bcd(ss,8'h59))begin set_time<={hh,mm,ss};set_pulse<=1;end end
 default:packet<=0;
 endcase end end
end
reg[9:0] txshift;reg[15:0] txcount;reg[3:0] txbits;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin tx<=1;txshift<=10'h3ff;txcount<=0;txbits<=0;end
 else if(txbits==0)begin tx<=1;if(reply)begin txshift<={1'b1,(reply_ok?8'h4b:8'h45),1'b0};tx<=0;txcount<=DIV-1;txbits<=10;end end
 else if(txcount!=0)txcount<=txcount-1'b1;
 else begin txshift<={1'b1,txshift[9:1]};tx<=txshift[1];txbits<=txbits-1'b1;txcount<=DIV-1;end
end
endmodule
