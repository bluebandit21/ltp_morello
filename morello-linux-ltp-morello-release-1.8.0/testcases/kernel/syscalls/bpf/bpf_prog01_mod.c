// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) 2019 Richard Palethorpe <rpalethorpe@suse.com>
 *
 * Trivial Extended Berkeley Packet Filter (eBPF) test.
 *
 * Sanity check loading and running bytecode.
 *
 * Test flow:
 * 1. Create array map
 * 2. Load eBPF program
 * 3. Attach program to socket
 * 4. Send packet on socket
 * 5. This should trigger eBPF program which writes to array map
 * 6. Verify array map was written to
 */
/*
 * If test is executed in a loop and limit for locked memory (ulimit -l) is
 * too low bpf() call can fail with EPERM due to deffered freeing.
 */

#include <limits.h>
#include <string.h>
#include <stdio.h>

#include "config.h"
#include "tst_test.h"
#include "bpf_common.h"

const char MSG[] = "Ahoj!";
static char *msg;

static char *log;
static union bpf_attr *attr;

int load_prog(int fd)
{
	/*
	 * The following is a byte code template. We copy it to a guarded buffer and
	 * substitute the runtime value of our map file descriptor.
	 *
	 * r0 - r10 = registers 0 to 10
	 * r0 = return code
	 * r1 - r5 = scratch registers, used for function arguments
	 * r6 - r9 = registers preserved across function calls
	 * fp/r10 = stack frame pointer
	 */
	struct bpf_insn PROG[] = {
		/* Load the map FD into r1 (place holder) */
		BPF_LD_MAP_FD(BPF_REG_1, fd),
		/* Put (key = 0) on stack and key ptr into r2 */
		BPF_MOV64_REG(BPF_REG_2, BPF_REG_10),   /* r2 = fp */
		BPF_ALU64_IMM(BPF_ADD, BPF_REG_2, -8),  /* r2 = r2 - 8 */
		BPF_ST_MEM(BPF_DW, BPF_REG_2, 0, 0),    /* *r2 = 0 */

		BPF_MOV64_REG(BPF_REG_3, BPF_REG_10),   /* r3 = fp */
		BPF_ALU64_IMM(BPF_ADD, BPF_REG_3, -16),  /* r3 = r3 - 16 */
		BPF_ST_MEM(BPF_DW, BPF_REG_3, 0, 1),    /* *r3 = 1 */

		BPF_MOV64_IMM(BPF_REG_4, BPF_ANY),            /* r4 = BPF_ANY */

		/* r0 = bpf_map_update_elem(r1=&map, r2=&key, r3=&val, r4=flags) */
		BPF_EMIT_CALL(BPF_FUNC_map_update_elem),

		BPF_EXIT_INSN(),		         /* return r0 */
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
	int map_fd, prog_fd;
	uint32_t key = 0;
	uint64_t val;

	map_fd = bpf_map_array_create(1);
	prog_fd = load_prog(map_fd);

	bpf_run_prog(prog_fd, msg, sizeof(MSG));
	SAFE_CLOSE(prog_fd);

	bpf_map_array_get(map_fd, &key, &val);
	if (val != 1) {
		tst_res(TFAIL,
			"val = %lu, but should be val = 1",
			val);
        } else {
	        tst_res(TPASS, "val = 1");
	}

	SAFE_CLOSE(map_fd);
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
