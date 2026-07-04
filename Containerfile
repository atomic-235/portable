FROM docker.io/ubuntu:24.04

# Avoid tzdata interactive prompt
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV HOME=/root
ENV LANG=C.UTF-8

# Install nix (single-user)
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl xz-utils ca-certificates git sudo && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -m 0755 /nix && chown root /nix && \
    groupadd nixbld && \
    for i in $(seq 1 10); do useradd -r -g nixbld -G nixbld -d /var/empty -s /usr/sbin/nologin nixbld$i; done && \
    curl -L https://nixos.org/nix/install -o /tmp/nix-install.sh && \
    sh /tmp/nix-install.sh --no-daemon && \
    rm /tmp/nix-install.sh

# Enable flakes
RUN mkdir -p /root/.config/nix && \
    echo "experimental-features = nix-command flakes" >> /root/.config/nix/nix.conf

# Clone portable with shared submodule
RUN git clone --recursive https://github.com/atomic-235/portable /root/portable

# Apply home-manager config
RUN cd /root/portable && \
    HOME=/root USER=root \
    . /root/.nix-profile/etc/profile.d/nix.sh && \
    nix run github:nix-community/home-manager -- switch --flake .#user --impure -b backup

# Source nix env on shell start
RUN echo '. /root/.nix-profile/etc/profile.d/nix.sh' >> /root/.bashrc

ENTRYPOINT ["bash", "-l"]
