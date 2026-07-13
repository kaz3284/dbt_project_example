# syntax=docker/dockerfile:1.4
FROM python:3.10-bullseye
#
# VS Code Development Container Scripts
# https://github.com/microsoft/vscode-dev-containers/tree/v0.234.0/script-library
#
ARG INSTALL_ZSH="true"
ARG USERNAME="vscode"
ARG USER_UID="1000"
ARG USER_GID="${USER_UID}"
ARG UPGRADE_PACKAGES="true"
ARG INSTALL_OH_MYS="false"
# Configure apt and install packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends git curl ca-certificates direnv 2>&1 \
    && curl -sSL -o- "https://raw.githubusercontent.com/microsoft/vscode-dev-containers/v0.234.0/script-library/common-debian.sh" | bash /dev/stdin "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "${INSTALL_OH_MYS}" \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --upgrade pip

WORKDIR /tmp/.devcontainer
COPY requirements.txt requirements.txt
RUN python3 -m pip install --no-cache-dir -r requirements.txt && rm -rf /tmp/.devcontainer

USER ${USERNAME}

RUN <<EOR
cat <<EOT >> /home/${USERNAME}/.gitconfig
[core]
  hooksPath = .githooks
EOT

cat<<'EOT' >> /home/${USERNAME}/.bashrc
eval "$(direnv hook bash)"
direnv allow /workspace
EOT

cat <<'EOT' >> /home/${USERNAME}/.zshrc
eval "$(direnv hook zsh)"
direnv allow /workspace
EOT
EOR

WORKDIR /workspace
CMD ["sleep", "infinity"]
