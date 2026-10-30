#!/usr/bin/env bash
# 旁白/人声统一处理：把一句干声变成"游戏里的旁白"。
#
# 用法:
#   tools/process_voice.sh <输入音频> <输出.mp3>
# 例:
#   tools/process_voice.sh ~/Downloads/Falling_voice_1.m4a audio/voice/fall_01.mp3
#
# 处理链（顺序有意义）:
#   1. 降调 1.5 个半音（asetrate + atempo，速度不变）——让声音不那么"像自己"
#   2. 80 Hz 高通——去掉手持/房间低频轰鸣
#   3. 4 kHz 以上 -3 dB——压齿音和手机麦克风的尖锐感
#   4. 60 / 95 ms 两道短回声——一点房间感，不再是"贴耳录音"
#   5. loudnorm 到 -25 LUFS / 峰值 -3 dB——统一电平，且比音效低几 dB，
#      落在"旁白"而不是"对着你说话"的位置
#   6. 160 kbps 单声道 48 kHz 输出（Godot 不认 m4a）
#
# 想改：PITCH 是降调的频率比（0.917 = -1.5 半音，0.955 = -0.8 半音），
#       TARGET_LUFS 控制整体音量。
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "用法: $0 <输入音频> <输出.mp3>" >&2
	exit 1
fi

IN="$1"
OUT="$2"
PITCH=0.917
TARGET_LUFS=-25

SR=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$IN")
RATE=$(awk "BEGIN{printf \"%.0f\", $SR * $PITCH}")
TEMPO=$(awk "BEGIN{printf \"%.6f\", 1 / $PITCH}")

mkdir -p "$(dirname "$OUT")"

ffmpeg -hide_banner -loglevel error -y -i "$IN" \
	-af "asetrate=${RATE},aresample=48000,atempo=${TEMPO},highpass=f=80,highshelf=f=4000:g=-3,aecho=0.8:0.7:60|95:0.28|0.18,loudnorm=I=${TARGET_LUFS}:TP=-3:LRA=9" \
	-c:a libmp3lame -b:a 160k -ar 48000 -ac 1 "$OUT"

echo "输出: $OUT"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | awk '{printf "时长: %.2fs\n", $1}'
ffmpeg -hide_banner -i "$OUT" -af loudnorm=print_format=json -f null - 2>&1 | grep -E 'input_i|input_tp' | tr -d '\t'

# 处理链会让时长有千分之几的伸缩；按【原始录音】量的字幕时间需要乘这个比例
SRC_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
OUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
awk -v a="$SRC_DUR" -v b="$OUT_DUR" \
	'BEGIN{printf "时长比(处理后/原文件): %.5f —— 按原文件量的字幕时间要乘这个数\n", b/a}'
