create_clock -name sys_clk -period 40.000 [get_ports {clk}]
derive_clocks
# Related pixel/serializer and DDR phases remain fully timed.
# Only actual first capture stages of independent CDC signals are exempt.
set_false_path -from [get_ports {key_col[*]}]
set_false_path -to [get_regs {status_sync/meta*}]
set_false_path -to [get_regs {audio_status_sync/meta*}]
set_false_path -to [get_regs {sync_write_ack/meta*}]
set_false_path -to [get_regs {sync_read_ack/meta*}]
set_false_path -to [get_regs {u_I2S_receiver/S_i2s_bclk_1d}]
set_false_path -to [get_regs {u_I2S_receiver/S_i2s_lrck_1d}]
set_false_path -to [get_regs {u_I2S_receiver/S_i2s_dout_1d}]
set_false_path -to [get_regs {frame_sync[0]}]
set_false_path -to [get_regs {sd_card_bmp_m0/wrfin_tgl_sync[0]}]
set async_clear_pins [get_pins -nowarn {*.ar}]
if {[llength $async_clear_pins] > 0} { set_false_path -from [get_regs {por_count[17]}] -to $async_clear_pins }
set_false_path -from [get_regs {por_count[17]}] -to [get_pins {*.sr}]
set async_clear_pins [get_pins -nowarn {*.ar}]
if {[llength $async_clear_pins] > 0} { set_false_path -from [get_regs {keys_down[15]}] -to $async_clear_pins }
set_false_path -from [get_regs {keys_down[15]}] -to [get_pins {*.sr}]
set_false_path -to [get_regs {stream_fault_sync/meta*}]
set_false_path -to [get_regs {memory_ready_sync/meta*}]
set brightness_meta [get_regs -nowarn {brightness_sync/meta*}]
if {[llength $brightness_meta] > 0} { set_false_path -to $brightness_meta }

set_false_path -from [get_ports {UART_RX RTC_SDA}]
set_false_path -to [get_regs {clock_sync[0]}]
set_false_path -to [get_regs {pixel_time* pixel_time_valid}]

set_false_path -to [get_regs {alarm_flash_sync/meta*}]

set_false_path -to [get_regs {reader_retirement/sync/meta*}]

# Error banner CDC: constrain the stable second stage, exempt only first capture.
set_false_path -to [get_regs {diagnostic_sync/meta*}]
