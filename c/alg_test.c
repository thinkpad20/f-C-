#include "Shape.h"


int
main() {
	struct datatype c, r;
	c = Circle_constructor(1, 5, 3.5);
	r = Rectangle_constructor(0, 10, 4, 5);
	printf("Circle area: %f\n", Area(c));
	printf("Rectangle area: %f\n", Area(r));
	return 0;
}