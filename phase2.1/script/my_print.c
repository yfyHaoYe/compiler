#include <stdio.h>
#include <stdarg.h>
#include <stdbool.h>
#ifndef MY_PRINT
#define MY_PRINT
FILE* output_file;
bool info = true, warning = true, eror = true, table = true,  phase1 = false;

typedef enum Level {
    INFO,
    WARNING,
    ERROR,
    TABLE,
    PHASE1
} Level;

void my_print(Level level, const char* format, ...)
{
    if (output_file == NULL){
        printf("No output file! find in my_print\n");
        return;
    }
    if (
        level == INFO  && info ||
        level == WARNING && warning ||
        level == ERROR && eror ||
        level == TABLE && table ||
        level == PHASE1 && phase1
    ) {
        va_list args;
        // 打印到标准输出
        va_start(args, format);
        vprintf(format, args);
        // 打印到文件输出
        vfprintf(output_file, format, args);
        va_end(args);
    }
}
#endif