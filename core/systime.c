#include <sys/time.h>
#include <stddef.h>
#include "systime.h"

uint64_t
systime_wall() {
    // 使用结构体初始化器，避免未初始化变量
    struct timeval tv = {0};
    gettimeofday(&tv, NULL);
    // 先将秒转换为微秒，再相加，避免乘法和除法的精度损失
    uint64_t t = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;
    // 统一单位为 100 微秒
    t /= 10000;
    return t;
}

uint64_t
systime_mono() {
    struct timeval tv = {0};
    gettimeofday(&tv, NULL);
    // 先将秒转换为微秒，再相加，避免乘法和除法的精度损失
    uint64_t t = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;
    // 统一单位为 100 微秒
    t /= 10000;
    return t;
}