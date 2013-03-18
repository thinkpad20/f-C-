#include "List.h"

void printInt(Auto i) {
	printf("%d\n", *((int *)i.data));
}

void printIntList(List l) {
	if (l.oType == List_OT) {
		if (isEmpty(l))
			return;
		printInt(head(l));
		printIntList(tail(l));
	}
	fprintf(stderr, "Exception: incorrect datatype, expected type List\n");
	exit(1);
}

int main() {
	List l0, l1, l2, l3;
	int i = 1, j = 2, k = 3;
	l0 = Empty_constructor();
	l1 = Cons_constructor(Auto_c(&i), l0);
	l2 = Cons_constructor(Auto_c(&j), l1);
	l3 = Cons_constructor(Auto_c(&k), l2);
	printIntList(l3);
	return 0;
}