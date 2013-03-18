#ifndef __Datatype_H_
#define __Datatype_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define Auto_OT 1
#define NO_IT 0

/* Generic datatype container */
struct datatype {
	int iType, oType;
	void *data;
};

typedef struct datatype Auto;

Auto
Auto_c(void *data) {
	Auto newAuto;
	newAuto.oType = Auto_OT;
	newAuto.iType = NO_IT;
	newAuto.data = data;
	return newAuto;
}

void 
*Malloc(size_t sz) {
	void *ret = malloc(sz);
	if (!ret) {
		fprintf(stderr, "Error in memory allocation.\n");
		exit(1);
	}
	return ret;
}

#endif