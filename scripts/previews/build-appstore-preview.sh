#!/bin/bash
# Turns an OpenScreen window take of the Device Hub simulator into an App Store
# app preview: crop to the phone screen, square off the rounded screen corners
# with the app's own background colour, scale to 886x1920, 30 fps, H.264, and add
# a silent AAC track (App Store Connect rejects previews without audio).
#
# Usage: build-appstore-preview.sh <take.mp4> <start-sec> <duration-sec> <out.mp4> \
#          [crop w:h:x:y] [mask-frame-sec]
# Defaults match the 1.1.0 take (1528x2160 window capture, screen at 846x1840+341+167).
set -euo pipefail
IN="$1"; SS="$2"; DUR="$3"; OUT="$4"
CROP="${5:-846:1840:341:167}"; MASK_AT="${6:-10}"
IFS=: read -r CW CH CX CY <<< "$CROP"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# 1. Corner mask: in each corner, everything outside the lit screen edge (plus 6 px).
ffmpeg -v error -y -ss "$MASK_AT" -i "$IN" -frames:v 1 -vf "crop=$CROP" -f rawvideo -pix_fmt gray "$T/f.gray"
python3 -I - "$T/f.gray" "$CW" "$CH" "$T/mask.pgm" <<'PY'
import sys
src,W,H,out=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),sys.argv[4]
d=open(src,'rb').read(); g=lambda x,y:d[y*W+x]
m=bytearray(W*H); B=170; D=6
for y in list(range(B))+list(range(H-B,H)):
    x=0
    while x<B and g(x,y)<215: x+=1
    if x>0:
        for xx in range(min(B,x+D)): m[y*W+xx]=255
    x=W-1
    while x>=W-B and g(x,y)<215: x-=1
    if x<W-1:
        for xx in range(max(W-B,x-D+1),W): m[y*W+xx]=255
m2=bytearray(m)
for y in range(H):
    for x in list(range(B))+list(range(W-B,W)):
        if m[y*W+x]:
            for dy in range(-D,D+1):
                if 0<=y+dy<H: m2[(y+dy)*W+x]=255
open(out,'wb').write(b'P5 %d %d 255\n'%(W,H)+bytes(m2))
PY
# 2. Fill: app background, #EEEFE5 on top, #E7E8DE at the bottom (tab bar area).
HALF=$((CH/2))
ffmpeg -v error -y -i "$T/mask.pgm" -vf boxblur=1 "$T/mask.png"
ffmpeg -v error -y -f lavfi -i "color=c=0xEEEFE5:s=${CW}x${HALF}" -f lavfi -i "color=c=0xE7E8DE:s=${CW}x$((CH-HALF))" \
  -i "$T/mask.png" -filter_complex "[0][1]vstack=2,format=rgb24[c];[2]format=gray[m];[c][m]alphamerge" -frames:v 1 "$T/fill.png"
# 3. Encode.
SH=$(( (886*CH/CW + 1) / 2 * 2 ))
ffmpeg -y -hide_banner -loglevel error -ss "$SS" -t "$DUR" -i "$IN" -i "$T/fill.png" \
  -f lavfi -t "$DUR" -i anullsrc=r=44100:cl=stereo \
  -filter_complex "[0:v]crop=$CROP,setsar=1[c];[c][1:v]overlay=0:0[o];[o]scale=886:$SH:flags=lanczos,crop=886:1920:0:$(( (SH-1920)/2 )),fps=30,format=yuv420p,setsar=1[v]" \
  -map "[v]" -map 2:a -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -r 30 \
  -b:v 8M -maxrate 10M -bufsize 16M -c:a aac -b:a 128k -t "$DUR" -movflags +faststart "$OUT"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate:format=duration,size -of compact "$OUT"
