/* Benchmark launcher only; not part of the Swift library.
 * Fork after this small executable has replaced Python, so the measured child
 * does not inherit the collector's much larger resident-memory high-water mark.
 */
#include <errno.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc < 3) return 2;
    pid_t child = fork();
    if (child == -1) { perror("fork"); return 2; }
    if (child == 0) {
        execvp(argv[2], argv + 2);
        perror("execvp");
        _exit(127);
    }
    int status;
    struct rusage usage;
    pid_t result;
    do { result = wait4(child, &status, 0, &usage); } while (result == -1 && errno == EINTR);
    if (result == -1) { perror("wait4"); return 2; }
    FILE *output = fopen(argv[1], "w");
    if (!output) { perror("fopen"); return 2; }
    double cpu = (usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1000.0
        + (usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1000.0;
    double rss = usage.ru_maxrss;
#ifdef __APPLE__
    rss /= 1024.0;
#endif
    fprintf(output, "{\"process_cpu_ms\":%.3f,\"rss_kib\":%.3f}\n", cpu, rss);
    if (fclose(output) != 0) return 2;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
