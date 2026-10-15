param([string]$Port = 'COM4')
$ErrorActionPreference='Stop'
$clockPort = [System.IO.Ports.SerialPort]::new($Port,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$clockPort.Handshake=[System.IO.Ports.Handshake]::None
$clockPort.DtrEnable=$false
$clockPort.RtsEnable=$false
$clockPort.ReadTimeout=2500
$clockPort.WriteTimeout=2500
try {
    $clockPort.Open()
    $clockPort.DiscardInBuffer()
    $chinaTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow,'China Standard Time')
    $h=[byte](([int][math]::Floor($chinaTime.Hour/10)*16)+$chinaTime.Hour%10)
    $m=[byte](([int][math]::Floor($chinaTime.Minute/10)*16)+$chinaTime.Minute%10)
    $s=[byte](([int][math]::Floor($chinaTime.Second/10)*16)+$chinaTime.Second%10)
    [byte[]]$packet=@(0xA5,$h,$m,$s,(0xA5 -bxor $h -bxor $m -bxor $s))
    $clockPort.Write($packet,0,$packet.Length)
    $reply=$clockPort.ReadByte()
    $result=@{port=$Port;baud=115200;timezone='Asia/Shanghai';sent_time=$chinaTime.ToString('HH:mm:ss');rtc_write_ack=($reply -eq 0x4B);reply_hex=('{0:X2}' -f $reply);physical_screen_verified=$false}
    $report=Join-Path (Split-Path $PSScriptRoot -Parent) 'reports/clock_sync.json'
    $result | ConvertTo-Json | Set-Content -LiteralPath $report -Encoding UTF8
    $result | ConvertTo-Json
    if($reply -ne 0x4B){throw 'RTC calibration did not return success acknowledgement'}
} finally {
    if($clockPort.IsOpen){$clockPort.Close()}
    $clockPort.Dispose()
}
