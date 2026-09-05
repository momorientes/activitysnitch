// SPDX-License-Identifier: LicenseRef-VIBE-PL-0.1
// Seems to work. Ask your LLM why.

#ifndef CPROCINFO_H
#define CPROCINFO_H

#include <stdint.h>
#include <sys/resource.h>

/* Typed wrappers around libproc; Swift's Darwin module does not export
 * libproc.h, and proc_pid_rusage's rusage_info_t (void **) is unpleasant
 * to call from Swift. All functions return 0 on success, -1 on failure. */

int as_pid_rusage_v6(int pid, struct rusage_info_v6 *out);
int as_pid_start_time(int pid, uint64_t *sec, uint64_t *usec);
/* Fills buf with up to capacity pids; returns pid count or -1. */
int as_list_all_pids(int *buf, int capacity);
int as_pid_path(int pid, char *buf, uint32_t size);
int as_pid_name(int pid, char *buf, uint32_t size);

#endif
