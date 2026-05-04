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

echo -e "${YELLOW}=== Zig 0.13.0 안정판 설치 프로세스 시작 ===${NC}"

step_confirm() {
    echo -e "\n${YELLOW}>> $1 단계 완료.${NC}"
    read -p "다음으로 진행하시겠습니까? (y/n): " resp
    if [ "$resp" != "y" ]; then 
        echo -e "${RED}중단되었습니다.${NC}"
        exit 1
    fi
}

# 1단계: 다운로드
echo -e "\n[1단계] Zig 0.13.0 바이너리 다운로드 중..."
sudo apt update && sudo apt install -y xz-utils curl
curl -L "$ZIG_URL" -o zig.tar.xz

if [ -f "zig.tar.xz" ]; then
    echo -e "${GREEN}다운로드 성공: zig.tar.xz${NC}"
else
    echo -e "${RED}다운로드 실패!${NC}"
    exit 1
fi
step_confirm "다운로드"

# 2단계: 압축 해제 및 위치 이동
echo -e "\n[2단계] 압축 해제 및 /usr/local/zig 배치"
tar -xf zig.tar.xz

# 만약 폴더 이름이 예상과 다를 경우를 대비해 자동 감지 로직 추가
ACTUAL_DIR=$(ls -d zig-*-0.13.0 2>/dev/null | head -n 1)
if [ -z "$ACTUAL_DIR" ]; then ACTUAL_DIR="$ZIG_DIR_NAME"; fi

sudo rm -rf /usr/local/zig
sudo mv "$ACTUAL_DIR" /usr/local/zig

if [ -d "/usr/local/zig" ]; then
    echo -e "${GREEN}이동 완료: /usr/local/zig${NC}"
else
    echo -e "${RED}이동 실패! 폴더명을 확인하세요: $ACTUAL_DIR${NC}"
    exit 1
fi
step_confirm "파일 배치"

# 3단계: 심볼릭 링크 및 실행 확인
echo -e "\n[3단계] 전역 명령어 등록 및 최종 확인"
sudo ln -sf /usr/local/zig/zig /usr/bin/zig

ZIG_VER=$(zig version)
if [[ "$ZIG_VER" == "0.13.0"* ]]; then
    echo -e "${GREEN}성공: Zig $ZIG_VER 설치가 완료되었습니다.${NC}"
else
    echo -e "${RED}설치 확인 실패! 현재 버전: $ZIG_VER${NC}"
    exit 1
fi

# 임시 파일 정리
rm zig.tar.xz
