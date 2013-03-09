#include "datatype.h"

/* Type identifiers */
#define List_OT 102
#define List_Empty_IT 103
#define List_Cons_IT 104

typedef struct datatype List;
typedef struct datatype Auto;

List
Empty_constructor(void);

List
Cons_constructor(Auto head, List tail);

Auto 
head(List lst);

List 
tail(List a);

List 
init(List a);