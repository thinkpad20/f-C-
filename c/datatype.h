#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Generic datatype container */
struct datatype {
	int iType, oType;
	void *data;
};

void *Malloc(size_t sz) {
	void *ret = malloc(sz);
	if (!ret) {
		fprintf(stderr, "Error in memory allocation.\n");
		exit(1);
	}
	return ret;
}