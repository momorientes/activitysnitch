// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

#include "CProcInfo.h"

#include <libproc.h>
#include <string.h>
#include <sys/proc_info.h>

int as_pid_rusage_v6(int pid, struct rusage_info_v6 *out) {
    memset(out, 0, sizeof(*out));
    return proc_pid_rusage(pid, RUSAGE_INFO_V6, (rusage_info_t *)out) == 0 ? 0 : -1;
}

int as_pid_start_time(int pid, uint64_t *sec, uint64_t *usec) {
    struct proc_bsdinfo info;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != (int)sizeof(info)) {
        return -1;
    }
    *sec = info.pbi_start_tvsec;
    *usec = info.pbi_start_tvusec;
    return 0;
}

int as_list_all_pids(int *buf, int capacity) {
    int n = proc_listallpids(buf, capacity * (int)sizeof(int));
    return n > 0 ? n : -1;
}

int as_pid_path(int pid, char *buf, uint32_t size) {
    return proc_pidpath(pid, buf, size) > 0 ? 0 : -1;
}

int as_pid_name(int pid, char *buf, uint32_t size) {
    return proc_name(pid, buf, size) > 0 ? 0 : -1;
}
