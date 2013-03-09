#ifndef _Shape_H_
#define _Shape_H_
#include "datatype.h"

/* Type identifiers */
#define Shape_OT 99
#define Circle_IT 100
#define Rectangle_IT 101

/* Constructors*/
struct datatype
Circle_constructor (int x, int y, double r);

struct datatype
Rectangle_constructor (int x, int y, int length, int width);

double
Area(struct datatype Shape);

#endif /* _Shape_H_ */