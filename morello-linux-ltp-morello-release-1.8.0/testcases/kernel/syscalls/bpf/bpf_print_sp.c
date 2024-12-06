// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) 2019 Richard Palethorpe <rpalethorpe@suse.com>
 * Copyright (c) 2024 Arm Ltd
 *
 * Trivial Extended Berkeley Packet Filter (eBPF) test to print the stack
 * pointer via bpf_trace_printk helper
 *
 * Test flow:
 * 1. Load eBPF program
 * 2. Attach program to socket
 * 3. Send packet on socket
 * 4. This triggers eBPF program to print SP
 */

#include <limits.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "tst_test.h"
#include "bpf_common.h"

const char MSG[] = "Ahoj!";
static char *msg;

static char *log;
static union bpf_attr *attr;

int load_prog()
{
	/*
	 * bpf regs
	 * r0 = return code
	 * r1 - r5 = scratch registers, used for function arguments
	 * r6 - r9 = registers preserved across function calls
	 * fp/r10 = stack frame pointer
	 *
	 * to see bpf_trace_printk() output:
	 *   echo "1" > /sys/kernel/debug/tracing/trace_on
	 *   cat /sys/kernel/debug/tracing/trace_pipe
	 */
	union fmt
	{
		char fmt[8];
		unsigned int val; // 32 bit/word size representation
	} f = {.fmt = "%lx\n"};

	printf("val: %d", f.val);

	struct bpf_insn PROG[] = {
		/* Push fmt str onto stack */
		BPF_ST_MEM(BPF_DW, BPF_REG_10, -8, f.val),

		/* Setup bpf_trace_printk args */
		BPF_MOV64_REG(BPF_REG_1, BPF_REG_10), // arg1 = ptr to fmt str
		BPF_ALU64_IMM(BPF_ADD, BPF_REG_1, -8),
		BPF_MOV64_IMM(BPF_REG_2, 8),	      // arg2 = size
		BPF_MOV64_REG(BPF_REG_3, BPF_REG_10), // arg3 = SP

		/* Call bpf_trace_printk helper */
		BPF_EMIT_CALL(BPF_FUNC_trace_printk),
		//BPF_MOV64_IMM(BPF_REG_0, 0), // set ret val if we don't call above

		BPF_EXIT_INSN(),
	};

	bpf_init_prog_attr(attr, PROG, sizeof(PROG), log, BUFSIZE);
	return bpf_load_prog(attr, log);
}

void setup(void)
{
	rlimit_bump_memlock();

	memcpy(msg, MSG, sizeof(MSG));
}

void run(void)
{
	int prog_fd;

	prog_fd = load_prog();

	/*
	 * debug:
	 * The JIT'd program is loaded to a different place in memory each time,
	 * add a delay so we can catch the printk'd location in dmesg to use as
	 * a kernel breakpoint
	*/
	// for(int i=0; i<10; i++)
	// 	sleep(1);

	bpf_run_prog(prog_fd, msg, sizeof(MSG));
	SAFE_CLOSE(prog_fd);
}

static struct tst_test test = {
	.setup = setup,
	.test_all = run,
	.min_kver = "3.19",
	.bufs = (struct tst_buffers []) {
		{&log, .size = BUFSIZ},
		{&attr, .size = sizeof(*attr)},
		{&msg, .size = sizeof(MSG)},
		{},
	}
};
