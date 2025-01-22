#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <arpa/inet.h> 
#include <time.h> // Include time.h for time tracking

#define MAX_CONNECTION_NUM 1000000

int buildConnect(const char *lIp, const char *sIp, int sPort)
{
    int skFd; 
    if((skFd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        // Suppress error message
        return 0;
    }

    struct sockaddr_in cliAddr;
    cliAddr.sin_family = AF_INET;
    cliAddr.sin_addr.s_addr = inet_addr(lIp);
    cliAddr.sin_port = 0;
    if(bind(skFd,  (struct sockaddr *)&cliAddr, sizeof(cliAddr)) < 0)
    {
        // Suppress error message
        // Do not close the socket, continue to connect
    }

    struct sockaddr_in srvAddr;
    srvAddr.sin_family = AF_INET;
    srvAddr.sin_addr.s_addr = inet_addr(sIp);
    srvAddr.sin_port = htons(sPort); 
    if(connect(skFd, (struct sockaddr *)&srvAddr, sizeof(srvAddr)) < 0)
    {
       // Suppress error message
       close(skFd); // Close the socket if connect fails
    } 

    return skFd;
}

int main(int argc, char *argv[])
{
    int i = 0, sPort, fd;
    char lIp[16], sIp[16];
    int successful_connections = 0;
    time_t start_time = time(NULL);

    if(argc != 4)
    {
        printf("\n Usage: %s <local ip> <server ip> <server port>\n", argv[0]);
        return 1;
    }

    //1. 从命令行获取并解析local ip、server ip以及端口
    strcpy(lIp, argv[1]);
    strcpy(sIp, argv[2]);
    sPort = atoi(argv[3]);
    
    //2. 开始建立连接
    int *sockets = (int *)malloc(sizeof(int) * MAX_CONNECTION_NUM);
    for(i = 1; i <= MAX_CONNECTION_NUM; i++)
    {
        if(0 == i % 1000)
        {//稍稍停顿一下，避免把服务端的握手队列打满
            printf("%s 连接 %s:%d成功了 %d 条！\n", lIp, sIp, sPort, i);
            //sleep(1);
        }
        
        fd = buildConnect(lIp, sIp, sPort);
        if(fd > 0)
        {
            sockets[i-1] = fd;
            successful_connections++;
        }

        if(successful_connections % 10000 == 0)
        {
            time_t current_time = time(NULL);
            double elapsed_time = difftime(current_time, start_time);
            double qps = successful_connections / elapsed_time;
            printf("QPS: %.2f\n", qps);
        }
        // Do not exit the program on error
    }
    //sleep(10);

    //3. 释放所有的连接
    printf("关闭所有的连接...\n");
    for(i = 0; i < MAX_CONNECTION_NUM; i++)
    {
        close(sockets[i]);
    }
 
    return 0;
}

//gcc -o testclient testclient.c
//./testclient 192.168.1.2 192.168.1.100 8080