FROM mcr.microsoft.com/devcontainers/base:debian AS base

# By default /workspaces is owned by `root`.
# When the Dev Container extension mounts the source directory, it changes the mounted file owner to `vscode`.
# A directory is created under /workspaces which is owned by `vscode` and acts as a scratch pad to store
# miscellaneous ephemeral files.
RUN <<EOF
mkdir -p /workspaces/dev /workspaces/build
chown vscode:vscode /workspaces/dev /workspaces/build
EOF

# python3 for general scripting; curl + ca-certificates for HTTPS downloads;
# unzip + X11/Wayland/GL/audio/font libs for the Godot .NET Linux editor
# (headless tests and WSLg GUI).
RUN <<EOF
apt-get update
apt-get upgrade -y
apt-get install -y --no-install-recommends \
    python3 \
    curl \
    ca-certificates \
    unzip \
    dbus \
    libx11-6 \
    libxcursor1 \
    libxi6 \
    libxinerama1 \
    libxrandr2 \
    libxext6 \
    libxfixes3 \
    libxrender1 \
    libxkbcommon0 \
    libdbus-1-3 \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    libpulse0 \
    libasound2t64 \
    libgl1 \
    libgl1-mesa-dri \
    libfontconfig1 \
    libvulkan1 \
    mesa-vulkan-drivers
if ! test -s /etc/machine-id; then
    dbus-uuidgen --ensure=/etc/machine-id 2>/dev/null || \
        tr -d '-' </proc/sys/kernel/random/uuid >/etc/machine-id
fi
rm -rf /var/lib/apt/lists/*
EOF

# Mesa Dozen (dzn): Vulkan-on-D3D12 for WSLg. Debian's mesa-vulkan-drivers does
# not ship dzn; install the ICD + libdisplay-info.so.1 from Kisak/Ubuntu into
# /opt/mesa-dzn and select it via VK_DRIVER_FILES (see devcontainer.json).
ARG KISAK_MESA_VULKAN_DEB=mesa-vulkan-drivers_26.1.5~kisak1~n_amd64.deb
ARG LIBDISPLAY_INFO1_DEB=libdisplay-info1_0.1.1-2build1_amd64.deb
RUN <<EOF
set -euo pipefail
tmpdir="$(mktemp -d)"
curl -fsSL -o "${tmpdir}/mesa-vk.deb" \
  "https://ppa.launchpadcontent.net/kisak/kisak-mesa/ubuntu/pool/main/m/mesa/${KISAK_MESA_VULKAN_DEB}"
curl -fsSL -o "${tmpdir}/libdi.deb" \
  "http://mirrors.kernel.org/ubuntu/pool/universe/libd/libdisplay-info/${LIBDISPLAY_INFO1_DEB}"
dpkg-deb -x "${tmpdir}/mesa-vk.deb" "${tmpdir}/mesa"
dpkg-deb -x "${tmpdir}/libdi.deb" "${tmpdir}/di"
mkdir -p /opt/mesa-dzn/lib /opt/mesa-dzn/share/vulkan/icd.d
cp "${tmpdir}/mesa/usr/lib/x86_64-linux-gnu/libvulkan_dzn.so" /opt/mesa-dzn/lib/
cp "${tmpdir}/di/usr/lib/x86_64-linux-gnu/libdisplay-info.so.1" /opt/mesa-dzn/lib/
cp "${tmpdir}/di/usr/lib/x86_64-linux-gnu/libdisplay-info.so.0.1.1" /opt/mesa-dzn/lib/ 2>/dev/null || true
cat > /opt/mesa-dzn/share/vulkan/icd.d/dzn_icd.json <<'JSON'
{
    "ICD": {
        "api_version": "1.1.354",
        "library_path": "/opt/mesa-dzn/lib/libvulkan_dzn.so"
    },
    "file_format_version": "1.0.1"
}
JSON
rm -rf "${tmpdir}"
EOF

# Godot 4.6 .NET (mono) Linux x86_64 — binary + GodotSharp/ data directory.
ARG GODOT_VERSION=4.6-stable
ARG GODOT_ZIP=Godot_v4.6-stable_mono_linux_x86_64.zip
RUN <<EOF
set -euo pipefail
tmpdir="$(mktemp -d)"
curl -fsSL -o "${tmpdir}/godot.zip" \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
unzip -q "${tmpdir}/godot.zip" -d "${tmpdir}"
mkdir -p /opt/godot
mv "${tmpdir}/Godot_v4.6-stable_mono_linux_x86_64"/* /opt/godot/
chmod +x /opt/godot/Godot_v4.6-stable_mono_linux.x86_64
rm -rf "${tmpdir}"
EOF
