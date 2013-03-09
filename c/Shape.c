#include "Shape.h"

#define PI 3.141592654

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
	fprintf(stderr, "Exception: incorrect datatype, expected type Shape\n");
	exit(0);
}