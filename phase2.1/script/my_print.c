#include <stdio.h>
#include <stdarg.h>

FILE* output_file;

void my_print(const char* format, ...)
{
    if (output_file == NULL){
        printf("No output file! find in my_print\n");
        return;
    }
    va_list args;
    // 打印到标准输出
    va_start(args, format);
    vprintf(format, args);
    // 打印到文件输出
    vfprintf(output_file, format, args);
    va_end(args);
}