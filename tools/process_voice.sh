#!/usr/bin/env bash
# 旁白/人声统一处理：把一句干声做成"老式座机听筒里的旁白"。
#
# 用法:
#   tools/process_voice.sh <输入音频> <输出.mp3>
# 例:
#   tools/process_voice.sh ~/Downloads/Falling_voice_1.m4a audio/voice/fall_01.mp3
#
# 处理链（顺序有意义）:
#   1. 降调 1.5 个半音（asetrate + atempo，速度不变）——让声音不那么"像自己"
#   2. 340 Hz 高通 + 3.2 kHz 低通——老式电话的窄频带，去掉低频和齿音
#   3. 1.6 kHz +6 dB、2.5 kHz +3 dB——电话听筒的中频鼻音/箱声
#   4. 4:1 压缩 + tanh 软削波——像电话听筒被推得很响、轻微失真
#   5. 再收一次 330 Hz–3.1 kHz——削波产生的带外高频不要
#   6. 单条 12 ms、5% 的极短反射——一点点听筒腔体感，不是房间混响
#   7. 很轻的 pink noise 线路底噪
#   8. loudnorm 到 -25 LUFS / 峰值 -3 dB
#   9. 112 kbps 单声道 48 kHz MP3 输出（Godot 不认 m4a）
#
# 想改：PITCH 是降调的频率比（0.917 = -1.5 半音，0.955 = -0.8 半音），
#       TARGET_LUFS 控制整体音量；电话感主要看 HIGHPASS / LOWPASS / EQ 和削波前音量。
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "用法: $0 <输入音频> <输出.mp3>" >&2
	exit 1
fi

IN="$1"
OUT="$2"
PITCH=0.917
TARGET_LUFS=-25
HIGHPASS=340
LOWPASS=3200
PHONE_PEAK=1600
PHONE_PEAK_GAIN=6
PHONE_PRESENCE=2500
PHONE_PRESENCE_GAIN=3
ECHO_MS=12
ECHO_DECAY=0.05
HISS_AMP=0.0012
BITRATE=112k

SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$IN")
RATE=$(awk "BEGIN{printf \"%.0f\", $SR * $PITCH}")
TEMPO=$(awk "BEGIN{printf \"%.6f\", 1 / $PITCH}")

mkdir -p "$(dirname "$OUT")"

ffmpeg -hide_banner -loglevel error -y -i "$IN" \
	-f lavfi -i "anoisesrc=color=pink:amplitude=${HISS_AMP}:sample_rate=48000" \
	-filter_complex "\
[0:a]asetrate=${RATE},aresample=48000,atempo=${TEMPO},\
highpass=f=${HIGHPASS},lowpass=f=${LOWPASS},\
equalizer=f=${PHONE_PEAK}:t=q:w=1.0:g=${PHONE_PEAK_GAIN},\
equalizer=f=${PHONE_PRESENCE}:t=q:w=1.2:g=${PHONE_PRESENCE_GAIN},\
acompressor=threshold=0.045:ratio=4:attack=4:release=120:makeup=1.8,\
volume=8dB,asoftclip=type=tanh:threshold=0.4:output=0.8,volume=-6dB,\
highpass=f=330,lowpass=f=3100,\
aecho=0.6:0.4:${ECHO_MS}:${ECHO_DECAY}[voice];\
[1:a]highpass=f=${HIGHPASS},lowpass=f=3100[noise];\
[voice][noise]amix=inputs=2:duration=first:dropout_transition=0:normalize=0,\
loudnorm=I=${TARGET_LUFS}:TP=-3:LRA=9,aresample=48000[out]" \
	-map "[out]" -shortest -c:a libmp3lame -b:a "${BITRATE}" -ar 48000 -ac 1 "$OUT"

echo "输出: $OUT"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | awk '{printf "时长: %.2fs\n", $1}'
ffmpeg -hide_banner -i "$OUT" -af loudnorm=print_format=json -f null - 2>&1 | grep -E 'input_i|input_tp' | tr -d '\t'

# 处理链会让时长有千分之几的伸缩；按【原始录音】量的字幕时间需要乘这个比例
SRC_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
OUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
awk -v a="$SRC_DUR" -v b="$OUT_DUR" \
	'BEGIN{printf "时长比(处理后/原文件): %.5f —— 按原文件量的字幕时间要乘这个数\n", b/a}'
