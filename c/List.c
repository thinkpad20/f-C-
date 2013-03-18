#include "List.h"

struct Cons {
	Auto head;
	List tail;
};
/* simplifies code */
typedef struct Cons* Cons;

List
Empty_constructor() {
	struct datatype ret;
	ret.oType = List_OT;
	ret.iType = List_Empty_IT;
	ret.data = NULL;
	return ret;
}

List
Cons_constructor(Auto head, List tail) {
	struct Cons template = {head, tail};
	struct datatype ret;
	ret.oType = List_OT;
	ret.iType = List_Cons_IT;
	ret.data = Malloc(sizeof(template));
	memcpy(ret.data, &template, sizeof(template));
	return ret;
}

Auto 
head(List lst) {
	if (lst.oType == List_OT) {
		if (lst.iType == List_Cons_IT)
			return ((Cons)lst.data)->head;
		fprintf(stderr, "Exception: calling head on empty list\n");
		exit(1);
	}
	fprintf(stderr, "Exception: incorrect datatype, expected type List\n");
	exit(1);
}

List 
tail(List lst) {
	if (lst.oType == List_OT) {
		if (lst.iType == List_Cons_IT)
			return ((Cons)lst.data)->tail;
		fprintf(stderr, "Exception: calling tail on empty list\n");
		exit(1);
	}
	fprintf(stderr, "Exception: incorrect datatype, expected type List\n");
	exit(1);	
}

List 
init(List lst) {
	if (lst.oType == List_OT) {
		if (lst.iType == List_Cons_IT) {
			/* need to examine the type of the tail */
			if (((Cons)lst.data)->tail.iType == List_Empty_IT)
				return Empty_constructor();
			return Cons_constructor(((Cons)lst.data)->head, init(((Cons)lst.data)->tail));
		}
		fprintf(stderr, "Exception: calling init on empty list\n");
		exit(1);
	}
	fprintf(stderr, "Exception: incorrect datatype, expected type List\n");
	exit(1);
}

Auto 
last(List lst) {
	if (lst.oType == List_OT) {
		if (lst.iType == List_Cons_IT) {
			/* need to examine the type of the tail */
			if (((Cons)lst.data)->tail.iType == List_Empty_IT)
				return ((Cons)lst.data)->head;
			return last(((Cons)lst.data)->tail);
		}
		fprintf(stderr, "Exception: calling last on empty list\n");
		exit(1);
	}
	fprintf(stderr, "Exception: incorrect datatype, expected type List\n");
	exit(1);
}

bool
isAuto (struct datatype a) {
	if (a.oType == List_OT)
		return (a.iType == List_Empty_IT);
	fprintf(stderr, "Exception: incorrect datatype, expected type List\n");
	exit(1);
}