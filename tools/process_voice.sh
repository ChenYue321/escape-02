#!/usr/bin/env bash
# 旁白/人声统一处理：把一句干声做成"录音机里的旁白"。
#
# 用法:
#   tools/process_voice.sh <输入音频> <输出.mp3>
# 例:
#   tools/process_voice.sh ~/Downloads/Falling_voice_1.m4a audio/voice/fall_01.mp3
#
# 处理链（顺序有意义）:
#   1. 降调 1.5 个半音（asetrate + atempo，速度不变）——让声音不那么"像自己"
#   2. 120 Hz 高通 + 6.5 kHz 低通——收窄频带，像磁带/录音机
#   3. 轻压缩 + tanh 软削波——一点点磁带饱和，不是失真
#   4. 0.4 Hz / 0.5% 的 wow——磁带转速轻微不稳
#   5. 很轻的 pink noise 底噪——磁带嘶声
#   6. 单条 38 ms、9% 的短反射——空间感比原来的 60/95 ms 双回声轻很多
#   7. loudnorm 到 -25 LUFS / 峰值 -3 dB——统一旁白电平
#   8. 128 kbps 单声道 48 kHz MP3 输出（Godot 不认 m4a）
#
# 想改：PITCH 是降调的频率比（0.917 = -1.5 半音，0.955 = -0.8 半音），
#       TARGET_LUFS 控制整体音量；空间感主要看 ECHO_MS / ECHO_DECAY。
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "用法: $0 <输入音频> <输出.mp3>" >&2
	exit 1
fi

IN="$1"
OUT="$2"
PITCH=0.917
TARGET_LUFS=-25
HIGHPASS=120
LOWPASS=6500
WOW_HZ=0.4
WOW_DEPTH=0.005
ECHO_MS=38
ECHO_DECAY=0.09
HISS_AMP=0.0006
BITRATE=128k

SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$IN")
RATE=$(awk "BEGIN{printf \"%.0f\", $SR * $PITCH}")
TEMPO=$(awk "BEGIN{printf \"%.6f\", 1 / $PITCH}")

mkdir -p "$(dirname "$OUT")"

ffmpeg -hide_banner -loglevel error -y -i "$IN" \
	-f lavfi -i "anoisesrc=color=pink:amplitude=${HISS_AMP}:sample_rate=48000" \
	-filter_complex "\
[0:a]asetrate=${RATE},aresample=48000,atempo=${TEMPO},\
highpass=f=${HIGHPASS},lowpass=f=${LOWPASS},\
acompressor=threshold=0.1:ratio=2.5:attack=10:release=180:makeup=1.2,\
volume=4dB,asoftclip=type=tanh:threshold=0.55:output=0.9,volume=-4dB,\
vibrato=f=${WOW_HZ}:d=${WOW_DEPTH},\
highshelf=f=3500:g=-2,\
aecho=0.7:0.5:${ECHO_MS}:${ECHO_DECAY}[voice];\
[1:a]highpass=f=500,lowpass=f=5000[noise];\
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
