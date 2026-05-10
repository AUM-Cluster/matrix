#!/bin/bash
# auto_debuild_river.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== river v0.3.5 debuild 자동화 시작 ===${NC}"

# [1단계] 빌드 도구 (Zig 0.13.0) 환경 구성 및 검증
echo -e "\n${YELLOW}[1단계] 빌드 도구 (Zig 0.13.0) 환경 구성${NC}"

# 기본 빌드 필수 패키지 설치
apt update && apt install -y xz-utils curl git devscripts debhelper build-essential pkg-config \
    libwlroots-0.18-dev wayland-protocols libwayland-dev libxkbcommon-dev \
    libpixman-1-dev libinput-dev libudev-dev libevdev-dev scdoc

# 기존에 Zig가 설치되어 있고 버전이 0.13.0인지 확인
ZIG_VER=$(zig version 2>/dev/null)

if [[ "$ZIG_VER" == "0.13.0"* ]]; then
    echo -e "${GREEN}>> 이미 Zig $ZIG_VER 버전이 설치되어 있습니다. 다운로드를 건너뜁니다.${NC}"
else
    echo -e "${YELLOW}>> Zig 0.13.0이 없거나 다른 버전입니다. 새로 설치를 진행합니다...${NC}"
    ZIG_URL="https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz"
    ZIG_DIR_NAME="zig-linux-x86_64-0.13.0"

    curl -L "$ZIG_URL" -o zig.tar.xz
    if [ -f "zig.tar.xz" ]; then
        echo -e "${GREEN}다운로드 성공: zig.tar.xz${NC}"
    else
        echo -e "${RED}[에러] Zig 다운로드 실패!${NC}"
        exit 1
    fi

    tar -xf zig.tar.xz
    ACTUAL_DIR=$(ls -d zig-*-0.13.0 2>/dev/null | head -n 1)
    if [ -z "$ACTUAL_DIR" ]; then 
        ACTUAL_DIR="$ZIG_DIR_NAME"
    fi

    rm -rf /usr/local/zig
    mv "$ACTUAL_DIR" /usr/local/zig

    ln -sf /usr/local/zig/zig /usr/bin/zig
    rm -f zig.tar.xz

    # 설치 최종 확인
    ZIG_VER_NEW=$(zig version 2>&1)
    if [[ "$ZIG_VER_NEW" == "0.13.0"* ]]; then
        echo -e "${GREEN}Zig $ZIG_VER_NEW 설치 및 연동 성공!${NC}"
    else
        echo -e "${RED}[에러] Zig 설치 확인 실패!${NC}"
        exit 1
    fi
fi

# [2단계] 소스 가져오기 및 폴더 진입
echo -e "\n${YELLOW}[2단계] 소스 코드 체크아웃${NC}"
rm -rf river
git clone --recursive --branch v0.3.5 https://github.com/riverwm/river.git

if [ ! -d "river" ]; then
    echo -e "${RED}[에러] river 소스 폴더가 없습니다.${NC}"
    exit 1
fi

cd river

# [3단계] 데비안 폴더 및 필수 파일 자동 생성
echo -e "\n${YELLOW}[3단계] 데비안 표준 파일 자동 생성 중...${NC}"
mkdir -p debian/source

# 3-1. debian/control 작성
cat << 'EOF' > debian/control
Source: river
Section: misc
Priority: optional
Maintainer: AUM-Cluster <your-email@example.com>
Build-Depends: debhelper-compat (= 13), git, build-essential, pkg-config, libwlroots-0.18-dev, wayland-protocols, libwayland-dev, libxkbcommon-dev, libpixman-1-dev, libinput-dev, libudev-dev, libevdev-dev, scdoc
Standards-Version: 4.7.4

Package: river
Architecture: amd64
Depends: ${shlibs:Depends}, ${misc:Depends}
Description: river Wayland compositor
 River is a dynamic tiling Wayland compositor.
EOF

# 3-2. debian/rules 작성 (Tab 공백 유지 및 내부 cat 중첩 적용)
cat << 'EOF' > debian/rules
#!/usr/bin/make -f
%:
	dh $@

override_dh_auto_build:
	zig build -Doptimize=ReleaseSafe -Dcpu=x86_64_v2

override_dh_auto_install:
	# 1. 실행 파일 복사 (river, riverctl, rivertile)
	mkdir -p debian/river/usr/bin
	cp zig-out/bin/river debian/river/usr/bin/
	cp zig-out/bin/riverctl debian/river/usr/bin/
	cp zig-out/bin/rivertile debian/river/usr/bin/

	# 2. river-session 래퍼 스크립트 생성
	printf "#!/bin/sh\n\
export XDG_SESSION_TYPE=wayland\n\
export XDG_CURRENT_DESKTOP=river\n\
export MOZ_ENABLE_WAYLAND=1\n\n\
[ -f \"\$\$$HOME/.config/river/env\" ] && . \"\$\$$HOME/.config/river/env\"\n\n\
dbus-update-activation-environment --systemd --all\n\n\
exec systemd-run --user --scope --unit=river-session dbus-run-session /usr/bin/river\n" > debian/river/usr/bin/river-session
	chmod +x debian/river/usr/bin/river-session

	# 3. Desktop Entry 생성 (로그인 화면 표시용)
	mkdir -p debian/river/usr/share/wayland-sessions
	printf "[Desktop Entry]\n\
Name=River\n\
Comment=Dynamic Tiling Wayland Compositor\n\
Exec=river-session\n\
Type=Application\n" > debian/river/usr/share/wayland-sessions/river.desktop
EOF

# rules 파일 실행 권한 부여
chmod +x debian/rules

# 3-3. debian/changelog 작성
cat << 'EOF' > debian/changelog
river (0.3.5-1) unstable; urgency=medium

  * Initial release of river v0.3.5 package via automation.

 -- AUM-Cluster <your-email@example.com>  Mon, 04 May 2026 17:15:00 +0900
EOF

# 3-4. debian/source/format 작성
echo "3.0 (native)" > debian/source/format

# [4단계] 정석 debuild 실행
echo -e "\n${YELLOW}[4단계] 정석 debuild 실행 중...${NC}"
debuild -us -uc -b

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}=== 모든 빌드 및 패키징이 성공했습니다! ===${NC}"
    echo -e "${GREEN}>> 상위 디렉토리에 .deb 파일이 생성되었습니다.${NC}"
else
    echo -e "\n${RED}[에러] debuild 과정에서 오류가 발생했습니다.${NC}"
    exit 1
fi
