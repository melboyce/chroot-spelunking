# training environment for github.com/weirdtales/chroot-spelunking

FROM voidlinux/voidlinux

RUN xbps-install -Syy zsh gcc strace wget \
    && wget https://raw.githubusercontent.com/grml/grml-etc-core/master/etc/zsh/zshrc -O /root/.zshrc

ENTRYPOINT ["/usr/bin/zsh"]
