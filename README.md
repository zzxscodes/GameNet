# GameNet  

>   基于协程和事件驱动的服务端开发框架，适用于游戏后端和网关开发
>   c和lua的轻量级框架，采用动态链接库和luajit提供lua代码的性能
>   底层实现了两种高效数据结构和buffer缓冲区，网络和io交给c实现框架底层
>   上层实现复杂逻辑，使用协程和最小堆实现高效异步和并发编程

### 依赖和注意事项
>   LuaJIT2，Ubuntu18.04以上，lua-protobuf
>   原生内存管理接口可在core层替换为jemalloc更高效的内存管理接口

### 安装
```shell
cd GameNet-master
make
```

### 使用说明
```shell
./gamenet service/xxx.lua
```
### 性能表现
```
实现简单的echo服务，一万次连接的cps表现如下图，下图中的qps实际为cps
```
![image](https://github.com/user-attachments/assets/e23718f4-fbcc-4a5d-a44d-047e639ec9b8)



