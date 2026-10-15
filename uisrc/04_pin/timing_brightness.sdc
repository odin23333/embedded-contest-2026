create_clock -name sys_clk -period 40.000 [get_ports {clk}]
derive_clocks
# Related pixel/serializer and DDR phases remain fully timed.
# Only actual first capture stages of independent CDC signals are exempt.
set_false_path -from [get_ports {key_col[*]}]
set_false_path -to [get_regs {player/status_sync/meta*}]
set_false_path -to [get_regs {player/audio_status_sync/meta*}]
set_false_path -to [get_regs {player/sync_write_ack/meta*}]
set_false_path -to [get_regs {player/sync_read_ack/meta*}]
set_false_path -to [get_regs {player/u_I2S_receiver/S_i2s_bclk_1d}]
set_false_path -to [get_regs {player/u_I2S_receiver/S_i2s_lrck_1d}]
set_false_path -to [get_regs {player/u_I2S_receiver/S_i2s_dout_1d}]
set_false_path -to [get_regs {player/frame_sync[0]}]
set_false_path -to [get_regs {player/sd_card_bmp_m0/wrfin_tgl_sync[0]}]
set async_clear_pins [get_pins -nowarn {*.ar}]
if {[llength $async_clear_pins] > 0} { set_false_path -from [get_regs {player/por_count[17]}] -to $async_clear_pins }
set_false_path -from [get_regs {player/por_count[17]}] -to [get_pins {*.sr}]
set async_clear_pins [get_pins -nowarn {*.ar}]
if {[llength $async_clear_pins] > 0} { set_false_path -from [get_regs {player/keys_down[15]}] -to $async_clear_pins }
set_false_path -from [get_regs {player/keys_down[15]}] -to [get_pins {*.sr}]
set_false_path -to [get_regs {player/stream_fault_sync/meta*}]
set_false_path -to [get_regs {player/memory_ready_sync/meta*}]
set brightness_meta [get_regs -nowarn {player/brightness_sync/meta*}]
if {[llength $brightness_meta] > 0} { set_false_path -to $brightness_meta }

set_false_path -from [get_ports {UART_RX RTC_SDA}]
set_false_path -to [get_regs {player/clock_sync[0]}]
set_false_path -to [get_regs {player/pixel_time* player/pixel_time_valid}]

set_false_path -to [get_regs {player/alarm_flash_sync/meta*}]

set_false_path -to [get_regs {player/reader_retirement/sync/meta*}]
