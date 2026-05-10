#!/bin/bash

# 색상 및 함수 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== river v0.3.5 완성형 패키징 프로세스 (Session 스크립트 포함) ===${NC}"

# === 기존 step_confirm 함수 수정 ===
step_confirm() {
    echo -e "${YELLOW}>> $1 단계 완료.${NC}"
    
    # ──> 아래와 같이 수정하여 사용자 질문(read)을 완전히 건너뜁니다.
    echo "[CI/CD 자동 승인] 다음 단계로 진행합니다."
    return 0
}

# 1단계: 필수 라이브러리 및 도구 설치
echo -e "\n[1단계] 빌드 환경 구성 (Debian 13)"
apt update && apt install -y git curl build-essential pkg-config ruby ruby-dev \
    libwlroots-0.18-dev wayland-protocols libwayland-dev libxkbcommon-dev \
    libpixman-1-dev libinput-dev libudev-dev libevdev-dev scdoc

# fpm 설치 시 sudo 제거 (GitHub Actions 컨테이너 환경 대응)
if ! command -v fpm &> /dev/null; then
    gem install --no-document fpm
    ln -sf /usr/local/bin/fpm /usr/bin/fpm || true
fi

fpm --version && echo -e "${GREEN}빌드 환경 준비 완료${NC}"
step_confirm "의존성 설치"

# 2단계: 소스 가져오기 (v0.3.5)
echo -e "\n[2단계] 소스 체크아웃 (v0.3.5)"
[ -d "river" ] && rm -rf river
git clone --recursive --branch v0.3.5 https://github.com/riverwm/river.git
cd river
VERSION="0.3.5"
step_confirm "소스 동기화"

# 3단계: Zig 빌드
echo -e "\n[3단계] Zig 빌드 실행"

# 기존 캐시 삭제 (필수)
rm -rf .zig-cache zig-out

# target 옵션 제거
zig build -Doptimize=ReleaseSafe
if [ ! -d "zig-out/bin" ]; then echo -e "${RED}빌드 실패${NC}"; exit 1; fi
step_confirm "컴파일 완료"

# 4단계: 패키지 레이아웃 및 세션 스크립트 통합
echo -e "\n[4단계] 시스템 통합 레이아웃 구성"
BUILD_ROOT="build_out"
rm -rf $BUILD_ROOT
mkdir -p $BUILD_ROOT/usr/bin
mkdir -p $BUILD_ROOT/usr/share/wayland-sessions
mkdir -p $BUILD_ROOT/usr/share/doc/river

# 바이너리 복사
cp zig-out/bin/* $BUILD_ROOT/usr/bin/

# [표준화] river-session 래퍼 스크립트 생성
cat <<EOF > $BUILD_ROOT/usr/bin/river-session
#!/bin/sh
# Wayland 및 세션 환경 변수 강제 적용
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=river
export MOZ_ENABLE_WAYLAND=1

# 사용자 개별 환경 설정이 있다면 로드 (유연성 확보)
[ -f "\$HOME/.config/river/env" ] && . "\$HOME/.config/river/env"

# DBUS 업데이트
dbus-update-activation-environment --systemd --all

# 실행 (패키지로 설치된 /usr/bin/river 사용)
# systemd-run을 추가하여 세션 관리를 강화합니다.
exec systemd-run --user --scope --unit=river-session dbus-run-session /usr/bin/river
EOF
chmod +x $BUILD_ROOT/usr/bin/river-session

# [표준화] Desktop Entry 수정 (river-session 호출)
cat <<EOF > $BUILD_ROOT/usr/share/wayland-sessions/river.desktop
[Desktop Entry]
Name=River (Standard Session)
Comment=Dynamic Tiling Wayland Compositor With Systemd Integration
Exec=river-session
Type=Application
EOF

step_confirm "세션 스크립트 및 레이아웃 통합"

# 5단계: 의존성 자동 분석 및 최종 패키징
echo -e "\n[5단계] 의존성 정밀 분석 및 .deb 생성"
DEPENDS_LIST=$(ldd zig-out/bin/river | grep "=> /" | awk '{print $3}' | xargs realpath | xargs dpkg -S | cut -d: -f1 | sort -u | tr '\n' ',' | sed 's/,$//')

# 만약 ldd가 wlroots를 놓칠 경우를 대비한 보정
[[ ! $DEPENDS_LIST == *"libwlroots"* ]] && DEPENDS_LIST="$DEPENDS_LIST,libwlroots18"

fpm -s dir -t deb \
-n river \
-v "$VERSION" \
-C $BUILD_ROOT \
-p ../river_${VERSION}_final_amd64.deb \
--description "River: Wayland compositor with integrated session script" \
--maintainer "ascension" \
$(echo $DEPENDS_LIST | sed 's/,/ --depends /g' | sed 's/^/--depends /') \
.

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}최종 완성: river_${VERSION}_final_amd64.deb 생성됨${NC}"
else
    echo -e "${RED}패키징 실패${NC}"
fi
