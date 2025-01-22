#include "anet.h"

enum TCP_SOCK_OPTION {
    SOCK_OPT_KEEPALIVE = 1,
    SOCK_OPT_REUSEADDR,
    SOCK_OPT_TCP_NODELAY,
    SOCK_OPT_SNDBUF,
    SOCK_OPT_RCVBUF,
};

int
anet_tcp_listen(const char *bindaddr, int port, int backlog) {
    int s;
    struct sockaddr_in servaddr;

    if ((s = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        return -1;
    }

    if (anet_tcp_setoption(s, SOCK_OPT_REUSEADDR, 1) == -1) goto error;

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(port);
    servaddr.sin_addr.s_addr = bindaddr ? inet_addr(bindaddr) : INADDR_ANY;

    if (bind(s, (struct sockaddr*)&servaddr, sizeof(servaddr)) == -1) goto error;
    if (listen(s, backlog) == -1) goto error;
    if (_anet_tcp_set_nonblock(s) == -1) goto error;

    return s;

error:
    close(s);
    return -1;
}

int anet_tcp_accept(int fd, char* ip, int *port) {
    int clientfd;
    struct sockaddr_storage sa;
    socklen_t salen = sizeof(sa);
    while (1) {
        clientfd = accept(fd, (struct sockaddr*)&sa, &salen);
        if (clientfd == -1) {
            if (errno == EINTR)
                continue;
            else if (errno == EWOULDBLOCK)
                return 0;
            else {
                return -1;
            }
        }
        break;
    }
    struct sockaddr_in *s = (struct sockaddr_in *)&sa;
    if (ip) inet_ntop(AF_INET, (void*)&(s->sin_addr), ip, INET_ADDRSTRLEN);
    if (port) *port = ntohs(s->sin_port);
    return clientfd;
}

int anet_tcp_connect(const char *addr, int port) {
    int s;
    struct sockaddr_in servaddr;

    if ((s = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        return -1;
    }

    if (anet_tcp_setoption(s, SOCK_OPT_REUSEADDR, 1) == -1) goto error;
    if (anet_tcp_setoption(s, SOCK_OPT_KEEPALIVE, 1) == -1) goto error;
    if (_anet_tcp_set_nonblock(s) == -1) goto error;

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(port);
    if (inet_pton(AF_INET, addr, &servaddr.sin_addr) <= 0) {
        goto error;
    }

    if (connect(s, (struct sockaddr*)&servaddr, sizeof(servaddr)) == -1 && errno != EINPROGRESS) {
        close(s);
        return -1;
    }

    return s;

error:
    close(s);
    return -1;
}

int anet_tcp_close(int fd) {
    return close(fd);
}

int anet_tcp_read(int fd, void* buf, int sz) {
    while (1) {
        int n = read(fd, buf, sz);
        if (n == 0) return 0;
        if (n == -1) {
            if (errno == EINTR)
                continue;
            if (errno == EWOULDBLOCK)
                return -2;
            return -1;
        }
        return n;
    }
    return 0;
}

int anet_tcp_write(int fd, const void *buf, int sz) {
    while (1) {
        int n = write(fd, buf, sz);
        if (n == -1) {
            if (errno == EINTR)
                continue;
            if (errno == EWOULDBLOCK)
                return -2;
            return -1;
        }
        return n;
    }
    return 0;
}

int _anet_tcp_set_nonblock(int fd) {
    int flag = fcntl(fd, F_GETFL, 0);
    if (flag == -1) {
        return -1;
    }
    return fcntl(fd, F_SETFL, flag | O_NONBLOCK);
}

int anet_tcp_getoption(int fd, int option, int *val) {
    socklen_t len = sizeof(int);
    int level, optname;
    switch (option) {
    case SOCK_OPT_KEEPALIVE:
        level = SOL_SOCKET;
        optname = SO_KEEPALIVE;
        break;
    case SOCK_OPT_REUSEADDR:
        level = SOL_SOCKET;
        optname = SO_REUSEADDR;
        break;
    case SOCK_OPT_TCP_NODELAY:
        level = IPPROTO_TCP;
        optname = TCP_NODELAY;
        break;
    case SOCK_OPT_SNDBUF:
        level = SOL_SOCKET;
        optname = SO_RCVBUF;
        break;
    case SOCK_OPT_RCVBUF:
        level = SOL_SOCKET;
        optname = SO_SNDBUF;
        break;
    default:
        return -2;
    }
    return getsockopt(fd, level, optname, (void *) val, &len);
}

int anet_tcp_setoption(int fd, int option, int val) {
    socklen_t len = sizeof(int);
    int level, optname;
    switch (option) {
    case SOCK_OPT_KEEPALIVE:
        level = SOL_SOCKET;
        optname = SO_KEEPALIVE;
        break;
    case SOCK_OPT_REUSEADDR:
        level = SOL_SOCKET;
        optname = SO_REUSEADDR;
        break;
    case SOCK_OPT_TCP_NODELAY:
        level = IPPROTO_TCP;
        optname = TCP_NODELAY;
        break;
    case SOCK_OPT_SNDBUF:
        level = SOL_SOCKET;
        optname = SO_RCVBUF;
        break;
    case SOCK_OPT_RCVBUF:
        level = SOL_SOCKET;
        optname = SO_SNDBUF;
        break;
    default:
        return -2;
    }
    return setsockopt(fd, level, optname, (const void *) &val, len);
}
