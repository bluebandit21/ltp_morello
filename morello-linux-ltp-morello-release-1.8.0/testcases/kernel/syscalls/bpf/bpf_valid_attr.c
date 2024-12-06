// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) Arm Ltd. 2023. All rights reserved.
 * Author: Zachary Leaf <zachary.leaf@arm.com>
 *
 * The bpf syscall should fail when there is non-zero memory in the
 * bpf_attr input union beyond the last element of the active sub-command
 * struct.
 */

#include <stddef.h>

#include "tst_test.h"
#include "bpf_common.h"

static union bpf_attr *attr;

#define sizeof_field(TYPE, MEMBER) sizeof((((TYPE *)0)->MEMBER))
#define offsetofend(TYPE, MEMBER) \
	(offsetof(TYPE, MEMBER)	+ sizeof_field(TYPE, MEMBER))

void run(void)
{
	size_t offset;
	char *ptr;

	memset(attr, 0, sizeof(*attr));
	attr->map_type = BPF_MAP_TYPE_ARRAY;
	attr->key_size = 4;
	attr->value_size = 8;
	attr->max_entries = 1;
	attr->map_flags = 0;

	/*
	 * check syscall fails if there is non-null data somewhere beyond
	 * the last struct member for the BPF_MAP_CREATE option
	 */
	offset = offsetofend(union bpf_attr, map_extra);
	ptr = (char *)attr;
	*(ptr+offset) = 'x';
	TST_EXP_FAIL(bpf(BPF_MAP_CREATE, attr, sizeof(*attr)), EINVAL);

	/* remove the non-null data and BPF_MAP_CREATE should pass */
	*(ptr+offset) = '\0';
	TST_EXP_POSITIVE(bpf_map_create(attr));
}

static struct tst_test test = {
	.test_all = run,
	.min_kver = "5.16", /* map_extra field added in commit 9330986c0300 */
	.bufs = (struct tst_buffers []) {
		{&attr, .size = sizeof(*attr)},
		{},
	}
};
