name: sevcator.t.me / sevcator.github.io
run-name: XD

on:
  workflow_dispatch:

jobs:
  build-windows:
    name: Windows x86_64
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          repository: bol-van/zapret
          path: zapret

      - name: Set up MinGW
        uses: msys2/setup-msys2@v2
        with:
          msystem: MINGW64
          install: mingw-w64-x86_64-toolchain

      - name: Build ip2net, mdig
        shell: msys2 {0}
        run: |
          export CFLAGS="-DZAPRET_GH_VER=${{ github.ref_name }} -DZAPRET_GH_HASH=${{ github.sha }}"
          mkdir -p output
          cd zapret
          mingw32-make -C ip2net win
          mingw32-make -C mdig win
          cp -a {ip2net/ip2net,mdig/mdig}.exe ../output

      - name: Restore psmisc from cache
        id: cache-restore-psmisc
        uses: actions/cache/restore@v4
        with:
          path: ${{ github.workspace }}/psmisc
          key: psmisc-x86_64

      - name: Set up Cygwin
        env:
          PACKAGES: ${{ steps.cache-restore-psmisc.outputs.cache-hit != 'true' && 'cygport gettext-devel libiconv-devel libncurses-devel' || null }}
        uses: cygwin/cygwin-install-action@v4
        with:
          platform: x86_64
          site: http://ctm.crouchingtigerhiddenfruitbat.org/pub/cygwin/circa/64bit/2024/01/30/231215
          check-sig: false
          packages: >-
            gcc-core
            make
            zlib-devel
            zip
            unzip
            wget
            ${{ env.PACKAGES }}

      - name: Build psmisc
        if: steps.cache-restore-psmisc.outputs.cache-hit != 'true'
        env:
          URL: https://mirrors.kernel.org/sourceware/cygwin/x86_64/release/psmisc
        shell: C:\cygwin\bin\bash.exe -eo pipefail '{0}'
        run: >-
          export MAKEFLAGS=-j$(nproc) &&
          mkdir -p psmisc && cd psmisc &&
          wget -qO- ${URL} | grep -Po 'href=\"\Kpsmisc-(\d+\.)+\d+.+src\.tar\.xz(?=\")' | xargs -I{} wget -O- ${URL}/{} | tar -xJ &&
          cd psmisc-*.src &&
          echo CYGCONF_ARGS+=\" --disable-dependency-tracking --disable-nls\" >> psmisc.cygport &&
          cygport psmisc.cygport prep compile install

      - name: Save psmisc to cache
        if: steps.cache-restore-psmisc.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: ${{ github.workspace }}/psmisc
          key: psmisc-x86_64

      - name: Build winws
        shell: C:\cygwin\bin\bash.exe -eo pipefail '{0}'
        run: >-
          export MAKEFLAGS=-j$(nproc) &&
          export CFLAGS="-DZAPRET_GH_VER=${{ github.ref_name }} -DZAPRET_GH_HASH=${{ github.sha }}" &&
          cd zapret &&
          make -C nfq cygwin &&
          cp -a nfq/winws.exe ../output

      - name: Create zip
        shell: C:\cygwin\bin\bash.exe -e '{0}'
        run: >-
          cp -a -t output psmisc/psmisc-*.src/psmisc-*/inst/usr/bin/killall.exe /usr/bin/cygwin1.dll &&
          wget -O WinDivert.zip https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip &&
          unzip -j WinDivert.zip "*/x64/WinDivert.dll" "*/x64/WinDivert64.sys" -d output &&
          zip zapret-win-x86_64.zip -j output/*

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: zapret-win-x86_64
          path: zapret-*.zip
          if-no-files-found: error
