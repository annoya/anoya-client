//go:build darwin && cgo

package engine

/*
#include <mach/mach.h>

static long long engine_phys_footprint(void) {
	task_vm_info_data_t info;
	mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
	if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
		return -1;
	}
	return (long long)info.phys_footprint;
}
*/
import "C"

func physFootprint() int64 { return int64(C.engine_phys_footprint()) }
