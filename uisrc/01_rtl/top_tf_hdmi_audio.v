
module top #(parameter ENABLE_BRIGHTNESS=0, parameter ENABLE_TRANSITION=1, parameter ENABLE_PREFETCH=1, parameter ENABLE_IMAGE_SCALING=1)(input clk,input [3:0] key_col,output [3:0] key_row,output [7:0] led,
    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    output                      HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input UART_RX,output UART_TX,output RTC_SCL,inout RTC_SDA,
    input                       sd_miso
);

parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_PIXELS  = 24'd307200;   // 640*480
parameter BUF0_ADDR     = 24'd0;
parameter BUF1_ADDR     = FRAME_PIXELS;

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk=clk;
wire sys_clk100_unused;
wire rst_n,video_rst_n,mem_rst_n,audio_rst_n,serial_rst_n;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire ext_mem_clk90,sys_lock,video_lock;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
wire        display_valid;
wire image_pending_ready,fade_permit_pixel,fade_permit_ctrl;

wire [3:0]  state_code;
wire [6:0]  seg_data_0;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
wire sd_write_ack,video_read_ack;
level_sync #(.WIDTH(1)) sync_write_ack(sd_card_clk,rst_n,sd_card_write_req_ack,sd_write_ack);
level_sync #(.WIDTH(1)) sync_read_ack(video_clk,video_rst_n,video_read_req_ack,video_read_ack);
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;

// HDMI 1.4b 音频发射相关
wire        audio_pll_lock;
wire        audio_mclk;
wire        audio_i2s_bclk;
wire        audio_i2s_lrck;
wire        audio_i2s_dout;
wire        audio_valid;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;

wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;
wire hdmi_axis_user,hdmi_axis_valid,hdmi_axis_last;wire [23:0] hdmi_axis_data;
wire stream_overflow;wire [5:0] stream_count;wire stream_fault_ctrl;
level_sync #(.WIDTH(1)) stream_fault_sync(clk,rst_n,stream_overflow,stream_fault_ctrl);
axis_stream_buffer #(.DEPTH(32)) stream_queue(video_clk,video_rst_n,
 axis_s_valid,axis_s_user,axis_s_last,axis_s_data,axis_s_ready,
 hdmi_axis_valid,hdmi_axis_user,hdmi_axis_last,hdmi_axis_data,stream_overflow,stream_count);

wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// 统一复位：TF 图像链路 + HDMI 音频链路
wire rst_all;
reg [17:0] por_count=0;
always @(posedge clk)if(!por_count[17])por_count<=por_count+1'b1;
wire base_reset=~por_count[17] | ~audio_pll_lock | ~sys_lock | ~video_lock;
wire [15:0] keys_down,keys_pressed;
wire keyboard_rst_n;
reset_sync reset_keyboard(sd_card_clk,~base_reset,keyboard_rst_n);
matrix_keys #(.SLOT(6250)) keyboard(sd_card_clk,keyboard_rst_n,key_col,key_row,keys_down,keys_pressed);
wire raw_rst_n=~base_reset & ~keys_down[15];
reset_sync reset_ctrl(sd_card_clk,raw_rst_n,rst_n);
reset_sync reset_video(video_clk,raw_rst_n,video_rst_n);
reset_sync reset_memory(ext_mem_clk,raw_rst_n,mem_rst_n);
reset_sync reset_audio(audio_mclk,raw_rst_n,audio_rst_n);
reset_sync reset_serial(hdmi_5x_clk,raw_rst_n,serial_rst_n);
wire video_rst=~video_rst_n,mem_rst=~mem_rst_n,audio_rst=~audio_rst_n;
assign rst_all=~rst_n;
wire emergency,muted,auto_enabled,next_event,next_valid,pending_request;
wire backend_busy,backend_ready,has_multiple;
wire buffer_retired,pixel_write_ready;
buffer_retirement #(.ADDR_BITS(ADDR_BITS),.PAGE1_BASE(BUF1_ADDR)) reader_retirement(
 .mem_clk(ext_mem_clk),.mem_rst(mem_rst),.read_ack(video_read_req_ack),.read_addr(App_rd_addr),
 .ctrl_clk(sd_card_clk),.ctrl_rst_n(rst_n),.displayed_page(disp_buf_idx),.retired(buffer_retired));
wire storage_active,storage_progress,storage_error,storage_fault,ddr_ready_ctrl,memory_trusted,memory_lost;
level_sync #(.WIDTH(1)) memory_ready_sync(clk,rst_n,Sdr_init_done,ddr_ready_ctrl);
memory_health memory_health_check(clk,rst_n,ddr_ready_ctrl,memory_trusted,memory_lost);
storage_watchdog #(.TIMEOUT_CYCLES(125000000)) storage_guard(clk,rst_n,storage_active,storage_progress,ddr_ready_ctrl,storage_error|memory_lost,storage_fault);
mode_control modes(sd_card_clk,rst_n,keys_pressed[0],keys_pressed[1],keys_pressed[2],keys_pressed[3],emergency,muted,auto_enabled,next_event);
playback_scheduler #(.AUTO_CYCLES(125000000)) scheduler(sd_card_clk,rst_n,emergency|keys_pressed[2]|storage_fault,auto_enabled,next_event,
 display_valid,has_multiple,backend_busy,backend_ready,next_valid,pending_request);
wire [1:0] brightness_level,brightness_pixel;
generate if(ENABLE_BRIGHTNESS)begin:brightness_feature
 brightness_control brightness_keys(clk,rst_n,keys_pressed[4],emergency|keys_pressed[2]|storage_fault,brightness_level);
end else begin:brightness_disabled
 assign brightness_level=2'd3;
end endgenerate
level_sync #(.WIDTH(2)) brightness_sync(video_clk,video_rst_n,brightness_level,brightness_pixel);
reg [24:0] heartbeat;
always @(posedge clk)if(base_reset)heartbeat<=0;else if(heartbeat==24999999)heartbeat<=0;else heartbeat<=heartbeat+1'b1;
assign led=~{(pending_request|stream_fault_ctrl|storage_fault),base_reset,Sdr_init_done,display_valid,muted,emergency,auto_enabled,(heartbeat<12500000)};
wire alarm_flash_audio,alarm_flash_pixel;
level_sync #(.WIDTH(1)) alarm_flash_sync(video_clk,video_rst_n,alarm_flash_audio,alarm_flash_pixel);
wire [5:0] vid_status;
level_sync #(.WIDTH(6)) status_sync(video_clk,video_rst_n,{storage_fault,(display_valid&memory_trusted),backend_busy,muted,auto_enabled,emergency},vid_status);
wire frame_start;
wire time_set,time_reply,time_reply_ok,rtc_valid,rtc_toggle;
wire [23:0] host_time,rtc_bcd;
reg [23:0] pixel_time;reg pixel_time_valid;reg [2:0] clock_sync;
time_uart serial_time(clk,rst_n,UART_RX,time_reply,time_reply_ok,UART_TX,time_set,host_time);
rtc_time wall_clock(clk,rst_n,time_set,host_time,RTC_SCL,RTC_SDA,rtc_bcd,rtc_valid,rtc_toggle,time_reply,time_reply_ok);
always @(posedge video_clk or negedge video_rst_n)begin
 if(!video_rst_n)begin clock_sync<=0;pixel_time<=0;pixel_time_valid<=0;end
 else begin
  clock_sync<={clock_sync[1:0],rtc_toggle};
  if(clock_sync[2]!=clock_sync[1])begin pixel_time<=rtc_bcd;pixel_time_valid<=rtc_valid;end
 end
end
wire osd_hs,osd_vs,osd_de;wire [23:0] osd_rgb;
video_compositor #(.BRIGHTNESS_ENABLED(ENABLE_BRIGHTNESS),.TIMESTAMP_ENABLED(1),.ALARM_FLASH_ENABLED(1)) screen(video_clk,video_rst_n,vid_status,brightness_pixel,hs,vs,de,vout_data,
 frame_start,osd_hs,osd_vs,osd_de,osd_rgb,pixel_time,pixel_time_valid,alarm_flash_pixel);
reg frame_toggle;
always @(posedge video_clk or posedge video_rst)if(video_rst)frame_toggle<=0;else if(frame_start)frame_toggle<=~frame_toggle;
reg [2:0] frame_sync;
always @(posedge sd_card_clk or posedge rst_all)if(rst_all)frame_sync<=0;else frame_sync<={frame_sync[1:0],frame_toggle};
wire frame_tick=frame_sync[2]^frame_sync[1];
// MLK-S200: 25 MHz board/control, 100 MHz DDR, 25/125 MHz video.
sys_pll sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (sys_clk100_unused),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .clk90_out(ext_mem_clk90),.extlock(sys_lock),
    .reset      (~por_count[17])
);

video_pll video_pll_m0(
    .refclk     (clk),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),.extlock(video_lock),
    .reset      (~por_count[17])
);

// Audio PLL MCLK is approximately 12.295082 MHz (not exact 12.288 MHz).
PLL_HDMI_AUDIO u_audio_pll(
    .refclk     (clk),
    .reset      (~por_count[17]),
    .extlock    (audio_pll_lock),
    .clk0_out   (),
    .clk1_out   (),
    .clk2_out   (audio_mclk)
);

// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge mem_rst) begin
    if (mem_rst)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .EXTERNAL_CONTROL(1),.PREFETCH_ENABLED(ENABLE_PREFETCH),.IMAGE_SCALING_ENABLED(ENABLE_IMAGE_SCALING),
    .CLK_FREQ_HZ       (25_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_all),
    .storage_halt(storage_fault),.storage_active(storage_active),.storage_progress(storage_progress),.storage_error(storage_error),
    .key_next(1'b1),.next_cmd(next_valid && backend_ready),.block_cmd(emergency|keys_pressed[2]),.frame_tick(frame_tick && (!ENABLE_TRANSITION || !display_valid || emergency || storage_fault || fade_permit_ctrl)),
    .buffer_retired(buffer_retired),.pixel_write_ready(pixel_write_ready),.pending_ready(image_pending_ready),.backend_busy(backend_busy),.backend_ready(backend_ready),.multiple(has_multiple),
    .key_auto(1'b1),
    .state_code        (state_code),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),

    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_write_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (video_rst),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (video_rst),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
wire [2:0] fade_source;
wire [23:0] transition_rgb;
level_sync #(.WIDTH(3)) fade_source_sync(video_clk,video_rst_n,{image_pending_ready,disp_buf_idx},fade_source);
level_sync #(.WIDTH(1)) fade_permit_sync(sd_card_clk,rst_n,fade_permit_pixel,fade_permit_ctrl);
image_fade transition(.clk(video_clk),.rst_n(video_rst_n),.frame_tick(frame_start),
 .valid(vid_status[4]),.cancel(vid_status[0]|vid_status[5]),.pending_ready(fade_source[2]),
 .buffer_index(fade_source[1:0]),.rgb(vout_data_raw),.commit_permit(fade_permit_pixel),.faded_rgb(transition_rgb),.gain());
assign vout_data = ENABLE_TRANSITION ? transition_rgb : vout_data_raw;

frame_read_write #(
    .BURST_SIZE(128),.BURST_BITS(10),
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (640),
    .FRAME_HEIGHT     (480)
) frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .rst               (mem_rst),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),

    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),

    .read_clk          (video_clk),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (24'd0),
    .read_addr_3       (24'd0),
    .read_addr_index   (disp_buf_idx),
    .read_len          (FRAME_PIXELS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),

    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),

    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_ready(pixel_write_ready),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (24'd0),
    .write_addr_3      (24'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (FRAME_PIXELS),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),.Clk90(ext_mem_clk90),
    .Rst               (mem_rst),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

wire tone_bclk,tone_lrck,tone_dout,alarm_bclk,alarm_lrck,alarm_dout;
wire [1:0] aud_status;
level_sync #(.WIDTH(2)) audio_status_sync(audio_mclk,audio_rst_n,{muted,emergency},aud_status);
alert_i2s tone_alarm(audio_mclk,audio_rst_n,aud_status[0],aud_status[1],alarm_bclk,alarm_lrck,alarm_dout,alarm_flash_audio);
// Same MCLK/reset and 64 clocks/channel for both sources; clocks remain continuous.
assign audio_i2s_bclk=alarm_bclk;assign audio_i2s_lrck=alarm_lrck;
audio_mode_mux select_audio(audio_mclk,audio_rst_n,aud_status,tone_dout,alarm_dout,audio_i2s_dout);
// ===================== 音频：内部 I2S 测试音 =====================
hdmi_audio_tone_i2s_64fs #(
    .PHASE_INC (32'd39370534),
    .AMP       (24'sd2000000)
) u_hdmi_audio_tone_i2s_64fs (
    .I_mclk      (audio_mclk),
    .I_rst       (audio_rst),
    .O_i2s_BCLK  (tone_bclk),
    .O_i2s_LRCK  (tone_lrck),
    .O_i2s_DOUT  (tone_dout)
);

I2S_receiver u_I2S_receiver(
    .I_clk              (video_clk),
    .I_rst              (video_rst),
    .I_i2s_BCLK         (audio_i2s_bclk),
    .I_i2s_LRCK         (audio_i2s_lrck),
    .I_i2s_DOUT         (audio_i2s_dout),
    .O_audio_valid      (audio_valid),
    .O_audio_left_data  (audio_left_data),
    .O_audio_right_data (audio_right_data)
);

audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (video_rst),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);

// ===================== RGB/DE 转 AXIS 视频 =====================
video_rgb_to_axis_640x480 u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (video_rst),
    .I_vs          (osd_vs),
    .I_de          (osd_de),
    .I_rgb         (osd_rgb),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);

// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (video_rst),
    .O_pulse (edid_trig)
);

// ===================== 带音频的 HDMI 1.4b 发射 =====================
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 800        ),
    .HSA                    ( 96         ),
    .HFP                    ( 16         ),
    .HBP                    ( 48         ),
    .HACTIVE                ( 640        ),
    .VTOTAL                 ( 525        ),
    .VSA                    ( 2          ),
    .VFP                    ( 10         ),
    .VBP                    ( 33         ),
    .VACTIVE                ( 480        ),
    .VIDEO_VIC              ( 1          ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 250        )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (video_rst),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),

    .I_axis_s_user      (hdmi_axis_user),
    .I_axis_s_valid     (hdmi_axis_valid),
    .I_axis_s_last      (hdmi_axis_last),
    .I_axis_s_data      (hdmi_axis_data),
    .O_axis_s_ready     (axis_s_ready),

    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),

    .O_video_locked     (),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),

    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (~serial_rst_n),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    // Full-rate TMDS clock word: verified on MLK-S200 with this serializer.
    .I_tmds_channel_clk (10'b0000011111),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule
