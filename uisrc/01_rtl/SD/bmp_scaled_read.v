`timescale 1ns/1ps
// 24-bit bottom-up BI_RGB BMP, 1..2048 pixels per source axis.
// A sector buffer decouples SPI from the scaler; one source-line RAM suffices.
// Emit a fixed-size bottom-up frame, aspect-fit, black bars, center nearest sampling.
module bmp_scaled_read(
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
 NEXT_ROW=15,PIX_RX=16,TOP=17,BLACK_SEND=18;
reg[4:0] state,black_return;reg[9:0] rx_count,byte_index;
reg[7:0] magic0,magic1;reg[31:0] file_len,offset,width,height,dib,compression;
reg[15:0] planes,bits;
reg[31:0] scan_sector,base_sector,file_pos;reg[7:0] byte_q;
reg[7:0] sector_buf[0:511];reg[23:0] line_buf[0:2047];reg[23:0] line_q;
reg[15:0] fit_w,fit_h,left_bar,bottom_bar,black_rows,out_x,content_rows;
reg[15:0] source_y,needed_y,source_x,row_byte;reg[11:0] line_x;reg[1:0] component;reg[7:0] blue,green;
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
 if(state==PARSE && file_pos>=offset && row_byte<width[11:0]*3 && component==2)
  line_buf[line_x[10:0]]<={byte_q,green,blue};
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
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
     else if(source_y>needed_y)begin out_x<=0;source_x<=0;x_acc<=width;state<=X_STEP;end
     else state<=GET_BYTE;
    end
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
     if(content_rows<fit_h && source_y==needed_y+1'b1)begin out_x<=0;source_x<=0;x_acc<=width;state<=X_STEP;end
     else if(source_y>=height)begin black_rows<=480-bottom_bar-fit_h;state<=TOP;end
     else state<=GET_BYTE;
    end
    X_STEP:begin
     if(x_acc>=({16'd0,fit_w}<<1))begin x_acc<=x_acc-({16'd0,fit_w}<<1);source_x<=source_x+1'b1;end
     else state<=PIX_READ;
    end
    PIX_READ:state<=PIX_SEND;
    PIX_SEND:if(pixel_write_ready)begin
     bmp_data<=content_pixel?line_q:24'd0;bmp_data_wr_en<=1;
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
