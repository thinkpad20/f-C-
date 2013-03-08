#include "datatype.h"

#define PI 3.141592654

/* Type identifiers */
#define Shape_OT 99
#define Circle_IT 100
#define Rectangle_IT 101

/* For casting purposes only */
struct Circle {
	int x, y;
	double r;
};

struct Rectangle {
	int x, y, width, height;
};

/* Constructors*/
struct datatype
Circle_constructor (int x, int y, double r) {
	struct Circle template = {x, y, r};
	struct datatype ret;
	ret.oType = Shape_OT;
	ret.iType = Circle_IT;
	ret.data = Malloc(sizeof(template));
	memcpy(ret.data, &template, sizeof(template));
	return ret;
}

struct datatype
Rectangle_constructor (int x, int y, int length, int width) {
	struct Rectangle template = {x, y, length, width};
	struct datatype ret;
	ret.oType = Shape_OT;
	ret.iType = Rectangle_IT;
	ret.data = Malloc(sizeof(template));
	memcpy(ret.data, &template, sizeof(template));
	return ret;
}

double
Area(struct datatype Shape) {
	if (Shape.oType == Shape_OT) {
		if (Shape.iType == Circle_IT) {
			return PI * ((struct Circle *)Shape.data)->r
					  * ((struct Circle *)Shape.data)->r;
		}
		if (Shape.iType == Rectangle_IT) {
			return ((struct Rectangle *)Shape.data)->width
					  * ((struct Rectangle *)Shape.data)->height;
		}
	}
	fprintf(stderr, "Exception: incorrect datatype\n");
	exit(0);
}

int
main() {
	struct datatype c, r;
	c = Circle_constructor(1, 5, 3.5);
	r = Rectangle_constructor(0, 10, 4, 5);
	printf("Circle area: %f\n", Area(c));
	printf("Rectangle area: %f\n", Area(r));
	return 0;
}