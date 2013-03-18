#include "c/datatype.h"

#define Shape_T 100
#define Shape_Circle_T 101
#define Shape_Square_T 102
#define Shape_Rectangle_T 103
#define Shape_Triangle_T 104


typedef struct datatype Shape;

struct Shape_Circle {
    int x;
    int y;
    double r;
};
typedef struct Shape_Circle * Shape_Circle_P;

struct Shape_Square {
    int x;
    void *y;
    void *len;
};
typedef struct Shape_Square * Shape_Square_P;

struct Shape_Rectangle {
    int x;
    int y;
    int l;
    int w;
};
typedef struct Shape_Rectangle * Shape_Rectangle_P;

struct Shape_Triangle {
    int x1;
    int y1;
    int x2;
    int y2;
    int x3;
    int y3;
};
typedef struct Shape_Triangle * Shape_Triangle_P;

Shape
Shape_Circle_constructor(int x, int y, double r) {
    Shape newShape;
    newShape.iType = Shape_Circle_T;
    newShape.data = Malloc(sizeof(struct Shape_Circle));
    ((Shape_Circle_P)newShape.data)->x = x;
    ((Shape_Circle_P)newShape.data)->y = y;
    ((Shape_Circle_P)newShape.data)->r = r;
    return newShape;
}

Shape
Shape_Square_constructor(int x, void *y, void *len) {
    Shape newShape;
    newShape.iType = Shape_Square_T;
    newShape.data = Malloc(sizeof(struct Shape_Square));
    ((Shape_Square_P)newShape.data)->x = x;
    ((Shape_Square_P)newShape.data)->y = y;
    ((Shape_Square_P)newShape.data)->len = len;
    return newShape;
}

Shape
Shape_Rectangle_constructor(int x, int y, int l, int w) {
    Shape newShape;
    newShape.iType = Shape_Rectangle_T;
    newShape.data = Malloc(sizeof(struct Shape_Rectangle));
    ((Shape_Rectangle_P)newShape.data)->x = x;
    ((Shape_Rectangle_P)newShape.data)->y = y;
    ((Shape_Rectangle_P)newShape.data)->l = l;
    ((Shape_Rectangle_P)newShape.data)->w = w;
    return newShape;
}

Shape
Shape_Triangle_constructor(int x1, int y1, int x2, int y2, int x3, int y3) {
    Shape newShape;
    newShape.iType = Shape_Triangle_T;
    newShape.data = Malloc(sizeof(struct Shape_Triangle));
    ((Shape_Triangle_P)newShape.data)->x1 = x1;
    ((Shape_Triangle_P)newShape.data)->y1 = y1;
    ((Shape_Triangle_P)newShape.data)->x2 = x2;
    ((Shape_Triangle_P)newShape.data)->y2 = y2;
    ((Shape_Triangle_P)newShape.data)->x3 = x3;
    ((Shape_Triangle_P)newShape.data)->y3 = y3;
    return newShape;
}

void PrintShape(Shape s ){
if(s.iType == Shape_Circle_T){
printf("%d\n", ((Shape_Circle_P)s.data)->x);
}
}

