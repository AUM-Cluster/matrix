#!/bin/bash

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Zig 0.13.0 공식 안정판 링크 및 디렉토리명 설정
ZIG_URL="https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz"
# 압축 해제 시 생성되는 실제 폴더 이름입니다.
ZIG_DIR_NAME="zig-linux-x86_64-0.13.0"

# 1단계: 다운로드
echo -e "\n[1단계] Zig 0.13.0 바이너리 다운로드 중..."
apt update && apt install -y xz-utils curl
curl -L "$ZIG_URL" -o zig.tar.xz

# 2단계: 압축 해제 및 위치 이동
echo -e "\n[2단계] 압축 해제 및 /usr/local/zig 배치"
tar -xf zig.tar.xz

# 만약 폴더 이름이 예상과 다를 경우를 대비해 자동 감지 로직 추가
ACTUAL_DIR=$(ls -d zig-*-0.13.0 2>/dev/null | head -n 1)
if [ -z "$ACTUAL_DIR" ]; then ACTUAL_DIR="$ZIG_DIR_NAME"; fi

rm -rf /usr/local/zig
mv "$ACTUAL_DIR" /usr/local/zig

# 3단계: 심볼릭 링크 및 실행 확인
echo -e "\n[3단계] 전역 명령어 등록 및 최종 확인"
ln -sf /usr/local/zig/zig /usr/bin/zig

ZIG_VER=$(zig version)
# 임시 파일 정리
rm zig.tar.xz
