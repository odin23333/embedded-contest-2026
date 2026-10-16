`timescale 1ns/1ps
// Read-only FAT32 front end. Directory entries select files, not raw BM signatures.
// Slot IDs replace physical start sectors at the existing scheduler interface.
// Each selected file chain is checked before any pixels are committed; the scaler
// sees an ordinary sequential, virtual file and cannot read outside DIR_FileSize.
module fat32_bmp_read #(
 parameter integer CLK_FREQ_HZ=100_000_000,
 parameter integer MAX_DIR_SECTORS=256,
 parameter integer MAX_CHAIN_CLUSTERS=65536
)(
 input clk,rst,output ready,output read_error,
 input scan_start,input[31:0] scan_start_sector,scan_max_sector,input[2:0] scan_target_count,
 output reg scan_done,scan_found_valid,output reg[31:0] scan_found_sector,output reg[2:0] scan_found_total,
 input load_start,input[31:0] load_sector,input sd_init_done,output[3:0] state_code,
 input[15:0] bmp_width,bmp_height,output write_req,input write_req_ack,
 output reg sd_sec_read,output reg[31:0] sd_sec_read_addr,input[7:0] sd_sec_read_data,
 input sd_sec_read_data_valid,sd_sec_read_end,output bmp_data_wr_en,output[23:0] bmp_data,
 input pixel_write_ready,output reg[7:0] fs_error_code
);
localparam IDLE=0,RX=1,BOOT_CHECK=2,MBR_PICK=3,BPB_CHECK=4,SHIFT=5,LAYOUT=6,
 DIR_REQ=7,DIR_NEXT=8,FAT_REQ=9,FAT_CHECK=10,SCAN_FINISH=11,PUBLISH=12,
 PRECHECK=13,PRE_NEXT=14,START_CORE=15,SERVE=16,MAP_NEXT=17,FILE_DONE=18,WAIT_DROP=19,FAILED=20;
localparam BOOT=0,DIRECTORY=1,FAT=2,FILE_DATA=3;
reg[4:0] state,after_read,fat_return;
reg[1:0] read_kind,partition_idx,slot,publish_idx;
reg fs_error,mounted,core_start,core_seen_busy;
reg[9:0] rx_count;
reg[31:0] stall_count;
reg[7:0] sig0,sig1,jump0,spc,nfats;
reg[15:0] bps,reserved,root_entries,total16,fat16,extflags,version;
reg[31:0] total32,fat_size,root_cluster,partition_base,partition_size;
reg[7:0] p_type[0:3];reg[31:0] p_start[0:3],p_size[0:3];
reg[3:0] cluster_shift;reg[7:0] shift_spc;
reg[31:0] fat_base,data_base,max_cluster,cluster_count;
reg[31:0] dir_cluster,folder_cluster;reg[7:0] dir_sector;
reg in_folder,dir_stop,folder_found;
reg[15:0] dir_sectors;
reg[87:0] entry_name;reg[7:0] entry_first,entry_attr;
reg[15:0] entry_hi,entry_lo;reg[31:0] entry_size;
reg[2:0] file_count,target_count;
reg[31:0] file_cluster[0:3],file_size[0:3];
reg[31:0] fat_cluster,fat_value;
reg[31:0] walk_cluster,walk_steps,walk_need,walk_anchor,walk_power,walk_lam;
reg[31:0] read_cluster,file_sector,file_sectors,header_file_size;
reg[7:0] in_cluster;
integer k;
wire[8:0] partition_pos=rx_count-10'd446;
wire[31:0] entry_cluster={entry_hi,entry_lo}&32'h0fffffff;
wire[31:0] entry_bytes={sd_sec_read_data,entry_size[23:0]};
wire spc_valid=spc!=0 && spc<=128 && (spc&(spc-1'b1))==0;
wire bpb_shape=(jump0==8'heb || jump0==8'he9) && bps==512 && spc_valid &&
 reserved!=0 && (nfats==1 || nfats==2) && root_entries==0 && total16==0 && fat16==0 &&
 total32!=0 && fat_size!=0 && version==0 && (!extflags[7] || extflags[3:0]<nfats);
wire[32:0] fat_area=(nfats==2)?({1'b0,fat_size}<<1):{1'b0,fat_size};
wire[32:0] first_data={17'd0,reserved}+fat_area;
wire[32:0] volume_end={1'b0,partition_base}+{1'b0,total32};
wire[31:0] data_sectors=total32-first_data[31:0];
wire[31:0] calc_clusters=data_sectors>>cluster_shift;
wire[40:0] fat_entries={9'd0,fat_size}<<7;
wire[31:0] next_cluster=fat_value&32'h0fffffff;
wire fat_eoc=next_cluster>=32'h0ffffff8;
wire fat_valid=next_cluster>=2 && next_cluster<=max_cluster && next_cluster<32'h0ffffff0;
wire selected_partition=(p_type[partition_idx]==8'h0b || p_type[partition_idx]==8'h0c) &&
 p_start[partition_idx]!=0 && p_size[partition_idx]!=0 &&
 ({1'b0,p_start[partition_idx]}+{1'b0,p_size[partition_idx]})<=33'h100000000;
wire core_ready,core_error,core_req,core_end;
wire[31:0] core_addr;wire[3:0] core_state;
assign ready=state==IDLE && core_ready;
assign read_error=fs_error|core_error;
assign state_code=(state==IDLE)?4'd1:((state==SERVE||state==RX&&read_kind==FILE_DATA)?core_state:4'd2);
assign core_end=state==RX && read_kind==FILE_DATA && sd_sec_read_end;
wire core_valid=state==RX && read_kind==FILE_DATA && sd_sec_read_data_valid;

bmp_scaled_read scaler(
 .clk(clk),.rst(rst|fs_error|!sd_init_done),.ready(core_ready),.read_error(core_error),
 .scan_start(1'b0),.scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd0),
 .scan_done(),.scan_found_valid(),.scan_found_sector(),.scan_found_total(),
 .load_start(core_start),.load_sector(32'd0),.sd_init_done(sd_init_done),.state_code(core_state),
 .bmp_width(bmp_width),.bmp_height(bmp_height),.write_req(write_req),.write_req_ack(write_req_ack),
 .sd_sec_read(core_req),.sd_sec_read_addr(core_addr),.sd_sec_read_data(sd_sec_read_data),
 .sd_sec_read_data_valid(core_valid),.sd_sec_read_end(core_end),
 .bmp_data_wr_en(bmp_data_wr_en),.bmp_data(bmp_data),.pixel_write_ready(pixel_write_ready));

function[7:0] upper;
 input[7:0] c;
 begin upper=(c>="a" && c<="z")?c-8'd32:c;end
endfunction
task fail;
 input[7:0] code;
 begin fs_error<=1;fs_error_code<=code;sd_sec_read<=0;core_start<=0;state<=FAILED;end
endtask
task request_sector;
 input[31:0] lba;input[1:0] kind;input[4:0] following;
 begin
  sd_sec_read_addr<=lba;sd_sec_read<=1;rx_count<=0;stall_count<=0;
  read_kind<=kind;after_read<=following;state<=RX;
 end
endtask
task reset_walk;
 input[31:0] first;
 begin walk_cluster<=first;walk_anchor<=first;walk_power<=1;walk_lam<=0;walk_steps<=1;end
endtask
// Brent cycle detection, plus explicit total-work bounds. No unbounded directory
// or cluster walk is possible, including corrupt FATs with no end marker.
task advance_walk;
 begin
  walk_cluster<=next_cluster;walk_steps<=walk_steps+1'b1;
  if(walk_lam+1'b1==walk_power)begin
   walk_anchor<=next_cluster;walk_power<=walk_power<<1;walk_lam<=0;
  end else walk_lam<=walk_lam+1'b1;
 end
endtask

always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=IDLE;after_read<=IDLE;fat_return<=IDLE;read_kind<=BOOT;partition_idx<=0;
  fs_error<=0;fs_error_code<=0;mounted<=0;core_start<=0;core_seen_busy<=0;
  sd_sec_read<=0;sd_sec_read_addr<=0;rx_count<=0;stall_count<=0;
  scan_done<=0;scan_found_valid<=0;scan_found_sector<=0;scan_found_total<=0;
  sig0<=0;sig1<=0;jump0<=0;spc<=0;nfats<=0;bps<=0;reserved<=0;root_entries<=0;
  total16<=0;fat16<=0;extflags<=0;version<=0;total32<=0;fat_size<=0;root_cluster<=0;
  partition_base<=0;partition_size<=0;cluster_shift<=0;shift_spc<=0;
  fat_base<=0;data_base<=0;max_cluster<=0;cluster_count<=0;
  dir_cluster<=0;folder_cluster<=0;dir_sector<=0;in_folder<=0;dir_stop<=0;folder_found<=0;dir_sectors<=0;
  entry_name<=0;entry_first<=0;entry_attr<=0;entry_hi<=0;entry_lo<=0;entry_size<=0;
  file_count<=0;target_count<=0;publish_idx<=0;slot<=0;
  fat_cluster<=0;fat_value<=0;walk_cluster<=0;walk_steps<=0;walk_need<=0;
  walk_anchor<=0;walk_power<=0;walk_lam<=0;read_cluster<=0;file_sector<=0;file_sectors<=0;header_file_size<=0;in_cluster<=0;
  for(k=0;k<4;k=k+1)begin p_type[k]<=0;p_start[k]<=0;p_size[k]<=0;file_cluster[k]<=0;file_size[k]<=0;end
 end else begin
  core_start<=0;scan_found_valid<=0;
  if(!sd_init_done)begin
   state<=IDLE;mounted<=0;scan_done<=0;scan_found_total<=0;file_count<=0;sd_sec_read<=0;
   // Read errors remain sticky until KEY16 reset, even across a card-ready loss.
  end else if(fs_error)state<=FAILED;
  else if(core_error)fail(8'h30);
  else begin
   if(state==RX && sd_sec_read_data_valid)begin
    rx_count<=rx_count+1'b1;stall_count<=0;
    if(read_kind==BOOT)begin
     case(rx_count)
      0:jump0<=sd_sec_read_data;
      11:bps[7:0]<=sd_sec_read_data;12:bps[15:8]<=sd_sec_read_data;
      13:spc<=sd_sec_read_data;14:reserved[7:0]<=sd_sec_read_data;15:reserved[15:8]<=sd_sec_read_data;
      16:nfats<=sd_sec_read_data;17:root_entries[7:0]<=sd_sec_read_data;18:root_entries[15:8]<=sd_sec_read_data;
      19:total16[7:0]<=sd_sec_read_data;20:total16[15:8]<=sd_sec_read_data;
      22:fat16[7:0]<=sd_sec_read_data;23:fat16[15:8]<=sd_sec_read_data;
      32:total32[7:0]<=sd_sec_read_data;33:total32[15:8]<=sd_sec_read_data;34:total32[23:16]<=sd_sec_read_data;35:total32[31:24]<=sd_sec_read_data;
      36:fat_size[7:0]<=sd_sec_read_data;37:fat_size[15:8]<=sd_sec_read_data;38:fat_size[23:16]<=sd_sec_read_data;39:fat_size[31:24]<=sd_sec_read_data;
      40:extflags[7:0]<=sd_sec_read_data;41:extflags[15:8]<=sd_sec_read_data;
      42:version[7:0]<=sd_sec_read_data;43:version[15:8]<=sd_sec_read_data;
      44:root_cluster[7:0]<=sd_sec_read_data;45:root_cluster[15:8]<=sd_sec_read_data;46:root_cluster[23:16]<=sd_sec_read_data;47:root_cluster[31:24]<=sd_sec_read_data;
      510:sig0<=sd_sec_read_data;511:sig1<=sd_sec_read_data;
     endcase
     if(rx_count>=446 && rx_count<510)case(partition_pos[3:0])
      4:p_type[partition_pos[5:4]]<=sd_sec_read_data;
      8:p_start[partition_pos[5:4]][7:0]<=sd_sec_read_data;
      9:p_start[partition_pos[5:4]][15:8]<=sd_sec_read_data;
      10:p_start[partition_pos[5:4]][23:16]<=sd_sec_read_data;
      11:p_start[partition_pos[5:4]][31:24]<=sd_sec_read_data;
      12:p_size[partition_pos[5:4]][7:0]<=sd_sec_read_data;
      13:p_size[partition_pos[5:4]][15:8]<=sd_sec_read_data;
      14:p_size[partition_pos[5:4]][23:16]<=sd_sec_read_data;
      15:p_size[partition_pos[5:4]][31:24]<=sd_sec_read_data;
     endcase
    end
    if(read_kind==FAT && rx_count[8:2]==fat_cluster[6:0])case(rx_count[1:0])
     0:fat_value[7:0]<=sd_sec_read_data;1:fat_value[15:8]<=sd_sec_read_data;
     2:fat_value[23:16]<=sd_sec_read_data;3:fat_value[31:24]<=sd_sec_read_data;
    endcase
    if(read_kind==FILE_DATA && file_sector==0)case(rx_count)
     2:header_file_size[7:0]<=sd_sec_read_data;3:header_file_size[15:8]<=sd_sec_read_data;
     4:header_file_size[23:16]<=sd_sec_read_data;5:header_file_size[31:24]<=sd_sec_read_data;
    endcase
    if(read_kind==DIRECTORY && !dir_stop)begin
     if(rx_count[4:0]<11)entry_name<={entry_name[79:0],upper(sd_sec_read_data)};
     case(rx_count[4:0])
      0:entry_first<=sd_sec_read_data;11:entry_attr<=sd_sec_read_data;
      20:entry_hi[7:0]<=sd_sec_read_data;21:entry_hi[15:8]<=sd_sec_read_data;
      26:entry_lo[7:0]<=sd_sec_read_data;27:entry_lo[15:8]<=sd_sec_read_data;
      28:entry_size[7:0]<=sd_sec_read_data;29:entry_size[15:8]<=sd_sec_read_data;30:entry_size[23:16]<=sd_sec_read_data;
      31:begin
       if(entry_first==0)dir_stop<=1;
       else if(entry_first!=8'he5 && (entry_attr&8'h3f)!=8'h0f && !entry_attr[3])begin
        if(!in_folder && entry_attr[4] && entry_name=="MLK_TEST   " && !folder_found)begin
         folder_found<=1;folder_cluster<=entry_cluster;
        end else if(!entry_attr[4] && !(|entry_attr[2:1]) && entry_name[23:0]=="BMP" && file_count<target_count)begin
         // Unsupported sizes/invalid first clusters are reported when selected.
         file_cluster[file_count[1:0]]<=entry_cluster;file_size[file_count[1:0]]<=entry_bytes;
         file_count<=file_count+1'b1;
        end
       end
      end
     endcase
    end
   end
   case(state)
    IDLE:begin
     sd_sec_read<=0;
     if(scan_start)begin
      mounted<=0;partition_base<=0;partition_size<=0;scan_done<=0;scan_found_total<=0;
      file_count<=0;folder_found<=0;in_folder<=0;target_count<=scan_target_count;
      if(scan_target_count==0 || scan_target_count>4)fail(8'h01);
      else request_sector(0,BOOT,BOOT_CHECK);
     end else if(load_start)begin
      if(!mounted || load_sector>=file_count)fail(8'h20);
      else begin slot<=load_sector[1:0];state<=PRECHECK;end
     end
    end
    RX:begin
     if(!sd_sec_read_data_valid)stall_count<=stall_count+1'b1;
     if(sd_sec_read_end)begin
      sd_sec_read<=0;
      if(rx_count!=512 && !(rx_count==511 && sd_sec_read_data_valid))fail(8'h02);
      else state<=after_read;
     end
     if(sd_sec_read_data_valid && rx_count>=512)fail(8'h02);
     else if(stall_count>=CLK_FREQ_HZ*2-1)fail(8'h03);
    end
    BOOT_CHECK:begin
     if(sig0!=8'h55 || sig1!=8'haa)fail(8'h10);
     else if(bpb_shape)state<=BPB_CHECK;
     else begin partition_idx<=0;state<=MBR_PICK;end
    end
    MBR_PICK:begin
     if(selected_partition)begin
      partition_base<=p_start[partition_idx];partition_size<=p_size[partition_idx];
      request_sector(p_start[partition_idx],BOOT,BPB_CHECK);
     end else if(partition_idx==3)fail(8'h11);
     else partition_idx<=partition_idx+1'b1;
    end
    BPB_CHECK:begin
     if(sig0!=8'h55 || sig1!=8'haa || !bpb_shape)fail(8'h12);
     else begin shift_spc<=spc;cluster_shift<=0;state<=SHIFT;end
    end
    SHIFT:if(shift_spc==1)state<=LAYOUT;
     else begin shift_spc<=shift_spc>>1;cluster_shift<=cluster_shift+1'b1;end
    LAYOUT:begin
     if(fat_size>total32 || fat_size>32'h7fffffff || first_data>={1'b0,total32} || volume_end>33'h100000000 ||
       (partition_size!=0 && total32>partition_size) || calc_clusters<65525 || calc_clusters>32'h0fffffee ||
       fat_entries<({9'd0,calc_clusters}+41'd2) || root_cluster<2 || root_cluster>calc_clusters+1)fail(8'h13);
     else begin
      fat_base<=partition_base+reserved+((extflags[7] && extflags[3:0]==1)?fat_size:32'd0);
      data_base<=partition_base+first_data[31:0];cluster_count<=calc_clusters;max_cluster<=calc_clusters+1;
      dir_cluster<=root_cluster;dir_sector<=0;dir_stop<=0;dir_sectors<=0;
      reset_walk(root_cluster);state<=DIR_REQ;
     end
    end
    DIR_REQ:begin
     if(dir_cluster<2 || dir_cluster>max_cluster || dir_sectors>=MAX_DIR_SECTORS)fail(8'h14);
     else begin
      dir_sectors<=dir_sectors+1'b1;
      request_sector(data_base+((dir_cluster-2)<<cluster_shift)+dir_sector,DIRECTORY,DIR_NEXT);
     end
    end
    DIR_NEXT:begin
     if(!in_folder && folder_found)begin
      in_folder<=1;dir_cluster<=folder_cluster;file_count<=0;dir_stop<=0;dir_sector<=0;dir_sectors<=0;
      reset_walk(folder_cluster);state<=DIR_REQ;
     end else if(dir_stop || (in_folder && file_count>=target_count))state<=SCAN_FINISH;
     else if(dir_sector+1<spc)begin dir_sector<=dir_sector+1'b1;state<=DIR_REQ;end
     else begin fat_cluster<=dir_cluster;fat_return<=DIR_NEXT;state<=FAT_REQ;end
    end
    FAT_REQ:begin
     if(fat_cluster<2 || fat_cluster>max_cluster || (fat_cluster>>7)>=fat_size)fail(8'h15);
     else request_sector(fat_base+(fat_cluster>>7),FAT,FAT_CHECK);
    end
    FAT_CHECK:begin
     if(fat_return==DIR_NEXT)begin
      if(fat_eoc)state<=SCAN_FINISH;
      else if(!fat_valid || next_cluster==walk_anchor || walk_steps>=cluster_count)fail(8'h16);
      else begin advance_walk;dir_cluster<=next_cluster;dir_sector<=0;state<=DIR_REQ;end
     end else if(fat_return==PRE_NEXT)begin
      if(fat_eoc)begin
       if(walk_steps<walk_need)fail(8'h22);else state<=START_CORE;
      end else if(!fat_valid || next_cluster==walk_anchor || walk_steps>=MAX_CHAIN_CLUSTERS || walk_steps>=cluster_count)fail(8'h23);
      else begin advance_walk;state<=PRE_NEXT;end
     end else begin
      if(!fat_valid)fail(8'h24);
      else begin read_cluster<=next_cluster;in_cluster<=0;state<=SERVE;end
     end
    end
    SCAN_FINISH:begin
     if(file_count==0)fail(8'h17);
     else begin publish_idx<=0;scan_found_total<=0;state<=PUBLISH;end
    end
    PUBLISH:begin
     scan_found_valid<=1;scan_found_sector<={30'd0,publish_idx};scan_found_total<={1'b0,publish_idx}+1'b1;
     if({1'b0,publish_idx}+1>=file_count)begin scan_done<=1;mounted<=1;state<=IDLE;end
     else publish_idx<=publish_idx+1'b1;
    end
    PRECHECK:begin
     if(file_cluster[slot]<2 || file_cluster[slot]>max_cluster || file_size[slot]<54 || file_size[slot]>32'd33554432)fail(8'h21);
     else begin
      reset_walk(file_cluster[slot]);
      file_sectors<=(file_size[slot]>>9)+(|file_size[slot][8:0]);
      walk_need<=(((file_size[slot]>>9)+(|file_size[slot][8:0]))+spc-1)>>cluster_shift;
      state<=PRE_NEXT;
     end
    end
    PRE_NEXT:begin fat_cluster<=walk_cluster;fat_return<=PRE_NEXT;state<=FAT_REQ;end
    START_CORE:begin
     read_cluster<=file_cluster[slot];in_cluster<=0;file_sector<=0;
     core_seen_busy<=0;core_start<=1;state<=SERVE;
    end
    SERVE:begin
     if(!core_ready)core_seen_busy<=1;
     if(core_req)begin
      if(core_addr!=file_sector || core_addr>=file_sectors)fail(8'h25);
      else if(in_cluster>=spc)begin fat_cluster<=read_cluster;fat_return<=MAP_NEXT;state<=FAT_REQ;end
      else request_sector(data_base+((read_cluster-2)<<cluster_shift)+in_cluster,FILE_DATA,FILE_DONE);
     end else if(core_seen_busy && core_ready)state<=IDLE;
    end
    FILE_DONE:begin
     if(file_sector==0 && header_file_size>file_size[slot])fail(8'h26);
     else begin file_sector<=file_sector+1'b1;in_cluster<=in_cluster+1'b1;state<=WAIT_DROP;end
    end
    WAIT_DROP:if(!core_req)state<=SERVE;
    FAILED:sd_sec_read<=0;
    default:fail(8'hff);
   endcase
  end
 end
end
endmodule
