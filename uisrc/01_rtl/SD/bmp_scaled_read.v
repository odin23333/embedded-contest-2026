`timescale 1ns/1ps
// 24-bit bottom-up BI_RGB BMP, 1..2048 pixels per source axis.
// Two alternating source-line RAMs support center-aligned bilinear sampling.
// Q0.8 weights, rounded separable RGB interpolation; exact 1:1, clamped edges.
// The legacy nearest mode is retained for regression and resource comparison.
module bmp_scaled_read #(parameter integer QUALITY=1)(
 input clk,rst,output ready,output reg read_error,
 input scan_start,input[31:0] scan_start_sector,scan_max_sector,input[2:0] scan_target_count,
 output reg scan_done,scan_found_valid,output reg[31:0] scan_found_sector,output reg[2:0] scan_found_total,
 input load_start,input[31:0] load_sector,input sd_init_done,output[3:0] state_code,
 input[15:0] bmp_width,bmp_height,output reg write_req,input write_req_ack,
 output reg sd_sec_read,output reg[31:0] sd_sec_read_addr,input[7:0] sd_sec_read_data,
 input sd_sec_read_data_valid,sd_sec_read_end,output reg bmp_data_wr_en,output reg[23:0] bmp_data,
 input pixel_write_ready);
localparam IDLE=0,SCAN_RX=1,SCAN_CHECK=2,HDR_RX=3,HDR_CHECK=4,GEOM=5,WR_ACK=6,
 BOTTOM=7,GET_BYTE=8,BYTE_WAIT=9,PARSE=10,X_STEP=11,PIX_READ=12,PIX_SEND=13,Y_STEP=14,
 NEXT_ROW=15,PIX_RX=16,TOP=17,BLACK_SEND=18,Y_FRAC=19,Y_READY=20,X_FRAC=21,
 QWAIT0=22,QA=23,QWAIT1=24,QB=25,SET_H0=26,MIX_H0=27,SET_H1=28,MIX_H1=29,SET_V=30,MIX_V=31;
reg[4:0] state,black_return;reg[9:0] rx_count,byte_index;
reg[7:0] magic0,magic1;reg[31:0] file_len,offset,width,height,dib,compression;
reg[15:0] planes,bits;
reg[31:0] scan_sector,base_sector,file_pos;reg[7:0] byte_q;
reg[7:0] sector_buf[0:511];reg[23:0] line_buf[0:2047];reg[23:0] line_q;
reg[15:0] fit_w,fit_h,left_bar,bottom_bar,black_rows,out_x,content_rows;
reg[15:0] source_y,needed_y,source_x,row_byte;reg[11:0] line_x;reg[1:0] component;reg[7:0] blue,green;
reg[23:0] line_buf1[0:2047];reg[23:0] q0,q1,p00,p01,p10,p11,quality_rgb;
reg[10:0] read_x,x1,y0,y1;reg[7:0] fx,fy,frac_work;
reg[11:0] frac_rem,frac_den;reg[3:0] frac_bits;
reg[1:0] channel;reg[7:0] mix_a,mix_b,mix_fraction,h0,h1;
wire signed[8:0] mix_delta=$signed({1'b0,mix_b})-$signed({1'b0,mix_a});
wire signed[17:0] mix_product=mix_delta*$signed({1'b0,mix_fraction});
wire signed[18:0] mix_sum=$signed({3'b000,mix_a,8'd0})+{mix_product[17],mix_product}+19'sd128;
wire[7:0] mix_value=mix_sum[15:8];
reg wide_fit;reg[31:0] geom_rem,x_acc,y_acc;
wire[12:0] stride=({1'b0,width[11:0]}*13'd3+13'd3)&13'h1ffc;
wire[24:0] payload=stride*height[11:0];
wire[32:0] pixel_end={1'b0,offset}+{8'd0,payload};
wire[31:0] sectors=(file_len>>9)+(|file_len[8:0]);
wire[32:0] next_scan={1'b0,scan_sector}+{1'b0,sectors};
wire good_header=magic0=="B" && magic1=="M" && width>=1 && width<=2048 && height>=1 && height<=2048 &&
 bits==24 && compression==0 && planes==1 && dib>=40 && offset>=54 &&
 {1'b0,offset}>={1'b0,dib}+33'd14 && !pixel_end[32] && file_len>=pixel_end && bmp_width==640 && bmp_height==480;
wire receive=state==SCAN_RX || state==HDR_RX || state==PIX_RX;
wire complete_sector=rx_count==512 || (rx_count==511 && sd_sec_read_data_valid);
wire content_pixel=out_x>=left_bar && out_x<left_bar+fit_w;
assign ready=state==IDLE;assign state_code=(state==IDLE)?1:((state==SCAN_RX||state==HDR_RX)?2:4);
// Synchronous read ports ensure block-RAM implementation.
always @(posedge clk)begin
 if(receive && sd_sec_read_data_valid)sector_buf[rx_count[8:0]]<=sd_sec_read_data;
 byte_q<=sector_buf[byte_index[8:0]];
 line_q<=line_buf[source_x[10:0]];
 q0<=line_buf[read_x];q1<=line_buf1[read_x];
 if(state==PARSE && file_pos>=offset && row_byte<width[11:0]*3 && component==2)begin
  if(QUALITY && source_y[0])line_buf1[line_x[10:0]]<={byte_q,green,blue};
  else line_buf[line_x[10:0]]<={byte_q,green,blue};
 end
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  read_x<=0;x1<=0;y0<=0;y1<=0;fx<=0;fy<=0;frac_work<=0;frac_rem<=0;frac_den<=1;frac_bits<=0;
  p00<=0;p01<=0;p10<=0;p11<=0;quality_rgb<=0;channel<=0;mix_a<=0;mix_b<=0;mix_fraction<=0;h0<=0;h1<=0;
  state<=IDLE;read_error<=0;write_req<=0;sd_sec_read<=0;sd_sec_read_addr<=0;
  scan_done<=0;scan_found_valid<=0;scan_found_sector<=0;scan_found_total<=0;
  rx_count<=0;byte_index<=0;file_pos<=0;scan_sector<=0;base_sector<=0;
  magic0<=0;magic1<=0;file_len<=0;offset<=0;width<=0;height<=0;dib<=0;compression<=0;planes<=0;bits<=0;
  fit_w<=0;fit_h<=0;left_bar<=0;bottom_bar<=0;black_rows<=0;out_x<=0;content_rows<=0;
  source_y<=0;needed_y<=0;source_x<=0;row_byte<=0;line_x<=0;component<=0;blue<=0;green<=0;
  wide_fit<=0;geom_rem<=0;x_acc<=0;y_acc<=0;black_return<=IDLE;bmp_data_wr_en<=0;bmp_data<=0;
 end else begin
  bmp_data_wr_en<=0;scan_found_valid<=0;
  if(!sd_init_done)begin state<=IDLE;sd_sec_read<=0;write_req<=0;scan_done<=0;scan_found_total<=0;end
  else begin
   if(receive && sd_sec_read_data_valid)begin
    rx_count<=rx_count+1'b1;
    if(state!=PIX_RX)case(rx_count)
     0:magic0<=sd_sec_read_data;1:magic1<=sd_sec_read_data;
     2:file_len[7:0]<=sd_sec_read_data;3:file_len[15:8]<=sd_sec_read_data;4:file_len[23:16]<=sd_sec_read_data;5:file_len[31:24]<=sd_sec_read_data;
     10:offset[7:0]<=sd_sec_read_data;11:offset[15:8]<=sd_sec_read_data;12:offset[23:16]<=sd_sec_read_data;13:offset[31:24]<=sd_sec_read_data;
     14:dib[7:0]<=sd_sec_read_data;15:dib[15:8]<=sd_sec_read_data;16:dib[23:16]<=sd_sec_read_data;17:dib[31:24]<=sd_sec_read_data;
     18:width[7:0]<=sd_sec_read_data;19:width[15:8]<=sd_sec_read_data;20:width[23:16]<=sd_sec_read_data;21:width[31:24]<=sd_sec_read_data;
     22:height[7:0]<=sd_sec_read_data;23:height[15:8]<=sd_sec_read_data;24:height[23:16]<=sd_sec_read_data;25:height[31:24]<=sd_sec_read_data;
     26:planes[7:0]<=sd_sec_read_data;27:planes[15:8]<=sd_sec_read_data;28:bits[7:0]<=sd_sec_read_data;29:bits[15:8]<=sd_sec_read_data;
     30:compression[7:0]<=sd_sec_read_data;31:compression[15:8]<=sd_sec_read_data;32:compression[23:16]<=sd_sec_read_data;33:compression[31:24]<=sd_sec_read_data;
    endcase
   end
   case(state)
    IDLE:begin
     write_req<=0;sd_sec_read<=0;
     if(scan_start)begin scan_done<=0;scan_found_total<=0;scan_sector<=scan_start_sector;sd_sec_read_addr<=scan_start_sector;rx_count<=0;sd_sec_read<=1;state<=SCAN_RX;end
     else if(load_start)begin base_sector<=load_sector;sd_sec_read_addr<=load_sector;rx_count<=0;sd_sec_read<=1;state<=HDR_RX;end
    end
    SCAN_RX,HDR_RX,PIX_RX:if(sd_sec_read_end)begin
     sd_sec_read<=0;
     if(!complete_sector)begin read_error<=1;state<=IDLE;end
     else if(state==SCAN_RX)state<=SCAN_CHECK;
     else if(state==HDR_RX)state<=HDR_CHECK;
     else begin byte_index<=0;state<=GET_BYTE;end
    end
    SCAN_CHECK:begin
     if(good_header)begin
      scan_found_valid<=1;scan_found_sector<=scan_sector;scan_found_total<=scan_found_total+1'b1;
      if(scan_found_total+1>=scan_target_count || next_scan>scan_max_sector || next_scan<=scan_sector)begin scan_done<=1;state<=IDLE;end
      else begin scan_sector<=next_scan[31:0];sd_sec_read_addr<=next_scan[31:0];rx_count<=0;sd_sec_read<=1;state<=SCAN_RX;end
     end else if(scan_sector>=scan_max_sector)begin scan_done<=1;state<=IDLE;end
     else begin scan_sector<=scan_sector+1'b1;sd_sec_read_addr<=scan_sector+1'b1;rx_count<=0;sd_sec_read<=1;state<=SCAN_RX;end
    end
    HDR_CHECK:begin
     if(!good_header)begin read_error<=1;state<=IDLE;end
     else begin
      wide_fit<=width*32'd480>=height*32'd640;
      if(width*32'd480>=height*32'd640)begin fit_w<=640;fit_h<=0;geom_rem<=height*32'd640;end
      else begin fit_h<=480;fit_w<=0;geom_rem<=width*32'd480;end
      state<=GEOM;
     end
    end
    GEOM:begin
     if(geom_rem>=(wide_fit?width:height))begin
      geom_rem<=geom_rem-(wide_fit?width:height);
      if(wide_fit)fit_h<=fit_h+1'b1;else fit_w<=fit_w+1'b1;
     end else begin
      if(fit_h==0)fit_h<=1;if(fit_w==0)fit_w<=1;
      state<=WR_ACK;write_req<=1;
     end
    end
    WR_ACK:if(write_req_ack)begin
     write_req<=0;left_bar<=(640-fit_w)>>1;bottom_bar<=(480-fit_h)>>1;black_rows<=(480-fit_h)>>1;
     out_x<=0;file_pos<=0;byte_index<=0;source_y<=0;row_byte<=0;line_x<=0;component<=0;
     needed_y<=0;y_acc<=height;content_rows<=0;state<=BOTTOM;
    end
    BOTTOM:if(black_rows==0)state<=Y_STEP;else begin black_return<=BOTTOM;state<=BLACK_SEND;end
    BLACK_SEND:if(pixel_write_ready)begin
     bmp_data<=0;bmp_data_wr_en<=1;
     if(out_x==639)begin out_x<=0;black_rows<=black_rows-1'b1;state<=black_return;end
     else out_x<=out_x+1'b1;
    end
    Y_STEP:begin
     if(content_rows>=fit_h)begin
      if(source_y>=height)begin black_rows<=480-bottom_bar-fit_h;state<=TOP;end
      else state<=GET_BYTE;
     end else if(y_acc>=({16'd0,fit_h}<<1))begin y_acc<=y_acc-({16'd0,fit_h}<<1);needed_y<=needed_y+1'b1;end
     else if(QUALITY)begin
      frac_bits<=0;frac_work<=0;frac_den<=fit_h<<1;
      if(needed_y==0 && y_acc<fit_h)begin y0<=0;y1<=0;fy<=0;state<=Y_READY;end
      else if((y_acc>=fit_h?needed_y:needed_y-1)>=height-1)begin y0<=height-1;y1<=height-1;fy<=0;state<=Y_READY;end
      else begin
       y0<=y_acc>=fit_h?needed_y:needed_y-1;y1<=y_acc>=fit_h?needed_y+1:needed_y;
       frac_rem<=y_acc>=fit_h?y_acc-fit_h:y_acc+fit_h;state<=Y_FRAC;
      end
     end
     else if(source_y>needed_y)begin out_x<=0;source_x<=0;x_acc<=width;state<=X_STEP;end
     else state<=GET_BYTE;
    end
    Y_FRAC:begin
     if({frac_rem,1'b0}>=frac_den)begin frac_rem<=({frac_rem,1'b0}-frac_den);frac_work<={frac_work[6:0],1'b1};end
     else begin frac_rem<=frac_rem<<1;frac_work<={frac_work[6:0],1'b0};end
     frac_bits<=frac_bits+1'b1;
     if(frac_bits==7)begin fy<=({frac_rem,1'b0}>=frac_den)?{frac_work[6:0],1'b1}:{frac_work[6:0],1'b0};state<=Y_READY;end
    end
    Y_READY:if(source_y>{5'd0,y1})begin out_x<=0;source_x<=0;x_acc<=width;state<=X_STEP;end else state<=GET_BYTE;
    GET_BYTE:begin
     if(byte_index==512)begin rx_count<=0;sd_sec_read_addr<=sd_sec_read_addr+1'b1;sd_sec_read<=1;state<=PIX_RX;end
     else state<=BYTE_WAIT;
    end
    BYTE_WAIT:state<=PARSE;
    PARSE:begin
     byte_index<=byte_index+1'b1;file_pos<=file_pos+1'b1;
     if(file_pos>=offset)begin
      if(row_byte<width[11:0]*3)begin
       case(component)0:blue<=byte_q;1:green<=byte_q;2:;endcase
       component<=(component==2)?0:component+1'b1;
       if(component==2)line_x<=line_x+1'b1;
      end
      if(row_byte==stride-1)begin row_byte<=0;line_x<=0;component<=0;source_y<=source_y+1'b1;state<=NEXT_ROW;end
      else begin row_byte<=row_byte+1'b1;state<=GET_BYTE;end
     end else state<=GET_BYTE;
    end
    NEXT_ROW:begin
     if(QUALITY && content_rows<fit_h)state<=Y_READY;
     else if(content_rows<fit_h && source_y==needed_y+1'b1)begin out_x<=0;source_x<=0;x_acc<=width;state<=X_STEP;end
     else if(source_y>=height)begin black_rows<=480-bottom_bar-fit_h;state<=TOP;end
     else state<=GET_BYTE;
    end
    X_STEP:begin
     if(QUALITY && !content_pixel)begin quality_rgb<=0;state<=PIX_SEND;end
     else if(x_acc>=({16'd0,fit_w}<<1))begin x_acc<=x_acc-({16'd0,fit_w}<<1);source_x<=source_x+1'b1;end
     else if(QUALITY)begin
      frac_bits<=0;frac_work<=0;frac_den<=fit_w<<1;
      if(source_x==0 && x_acc<fit_w)begin read_x<=0;x1<=0;fx<=0;state<=QWAIT0;end
      else if((x_acc>=fit_w?source_x:source_x-1)>=width-1)begin read_x<=width-1;x1<=width-1;fx<=0;state<=QWAIT0;end
      else begin
       read_x<=x_acc>=fit_w?source_x:source_x-1;x1<=x_acc>=fit_w?source_x+1:source_x;
       frac_rem<=x_acc>=fit_w?x_acc-fit_w:x_acc+fit_w;state<=X_FRAC;
      end
     end else state<=PIX_READ;
    end
    X_FRAC:begin
     if({frac_rem,1'b0}>=frac_den)begin frac_rem<=({frac_rem,1'b0}-frac_den);frac_work<={frac_work[6:0],1'b1};end
     else begin frac_rem<=frac_rem<<1;frac_work<={frac_work[6:0],1'b0};end
     frac_bits<=frac_bits+1'b1;
     if(frac_bits==7)begin fx<=({frac_rem,1'b0}>=frac_den)?{frac_work[6:0],1'b1}:{frac_work[6:0],1'b0};state<=QWAIT0;end
    end
    QWAIT0:state<=QA;
    QA:begin p00<=y0[0]?q1:q0;p10<=y1[0]?q1:q0;read_x<=x1;state<=QWAIT1;end
    QWAIT1:state<=QB;
    QB:begin p01<=y0[0]?q1:q0;p11<=y1[0]?q1:q0;channel<=0;state<=SET_H0;end
    SET_H0:begin mix_a<=p00[channel*8+:8];mix_b<=p01[channel*8+:8];mix_fraction<=fx;state<=MIX_H0;end
    MIX_H0:begin h0<=mix_value;state<=SET_H1;end
    SET_H1:begin mix_a<=p10[channel*8+:8];mix_b<=p11[channel*8+:8];mix_fraction<=fx;state<=MIX_H1;end
    MIX_H1:begin h1<=mix_value;state<=SET_V;end
    SET_V:begin mix_a<=h0;mix_b<=h1;mix_fraction<=fy;state<=MIX_V;end
    MIX_V:begin
     quality_rgb[channel*8+:8]<=mix_value;
     if(channel==2)state<=PIX_SEND;else begin channel<=channel+1'b1;state<=SET_H0;end
    end
    PIX_READ:state<=PIX_SEND;
    PIX_SEND:if(pixel_write_ready)begin
     bmp_data<=content_pixel?(QUALITY?quality_rgb:line_q):24'd0;bmp_data_wr_en<=1;
     if(out_x==639)begin out_x<=0;content_rows<=content_rows+1'b1;y_acc<=y_acc+(height<<1);state<=Y_STEP;end
     else begin out_x<=out_x+1'b1;if(content_pixel)x_acc<=x_acc+(width<<1);state<=X_STEP;end
    end
    TOP:if(black_rows==0)begin state<=IDLE;end else begin black_return<=TOP;state<=BLACK_SEND;end
    default:state<=IDLE;
   endcase
  end
 end
end
endmodule
