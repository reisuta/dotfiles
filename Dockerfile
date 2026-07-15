# syntax=docker/dockerfile:1
# WSL Ubuntu のシステム層。`just wsl-image` でビルドして WSL ディストロに import する。

FROM ubuntu:24.04

# identity はビルド時に注入する。`just image-build` が手元の id を --build-arg で渡す。
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# systemd は base image に無いが wsl.conf の systemd=true に必須。
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        systemd systemd-sysv dbus \
        sudo locales ca-certificates curl wget git \
 && rm -rf /var/lib/apt/lists/*

COPY aptpkgs.txt /tmp/aptpkgs.txt
RUN apt-get update \
 && sed 's/#.*//' /tmp/aptpkgs.txt | awk 'NF{print $1}' \
      | xargs apt-get install -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* /tmp/aptpkgs.txt

RUN printf '[boot]\nsystemd=true\n\n[user]\ndefault=%s\n' "${USERNAME}" > /etc/wsl.conf

# ubuntu:24.04 は UID 1000 を 'ubuntu' が占有済みなので退かす。
# NOPASSWD: import 直後はパスワード未設定で、無いと sudo 自体が打てず詰む。
RUN userdel -r ubuntu 2>/dev/null || true \
 && groupadd -g "${GID}" "${USERNAME}" \
 && useradd -m -u "${UID}" -g "${GID}" -s /usr/bin/zsh "${USERNAME}" \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
 && chmod 0440 "/etc/sudoers.d/${USERNAME}"

USER ${USERNAME}
WORKDIR /home/${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

RUN curl https://mise.run | sh \
 && curl -LsSf https://astral.sh/uv/install.sh | sh \
 && curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "${HOME}/.local/bin" \
 && curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh \
 && curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
      | bash -s -- --to "${HOME}/.local/bin" \
 && sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${HOME}/.local/bin"

COPY --chown=${UID}:${GID} mise.docker.toml /home/${USERNAME}/.config/mise/config.toml
COPY --chown=${UID}:${GID} npmpkgs.txt /tmp/npmpkgs.txt
RUN eval "$(mise activate bash --shims)" \
 && mise install \
 && mise exec -- corepack enable pnpm \
 && mise exec -- npm install -g $(sed 's/#.*//' /tmp/npmpkgs.txt | awk 'NF{print $1}') \
 && rm /tmp/npmpkgs.txt

COPY --chown=${UID}:${GID} . /home/${USERNAME}/dotfiles
RUN chezmoi init --source="${HOME}/dotfiles" --apply \
 && rm -rf "${HOME}/.cache/chezmoi"

CMD ["/usr/bin/zsh", "-l"]
