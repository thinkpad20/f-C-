#include "c/datatype.h"

#define Shape_T 100
#define Shape_Circle_T 101
#define Shape_Rectangle_T 102
#define Shape_NoShape_T 103
#define Shape_Foo_T 104


typedef struct datatype Shape;

struct Circle {
    int x;
    int y;
    double r;
};
typedef struct Circle * Circle_P;

struct Rectangle {
    int x;
    int y;
    int l;
    int w;
};
typedef struct Rectangle * Rectangle_P;

struct Foo {
    double x;
    double y;
    long toto;
};
typedef struct Foo * Foo_P;

Shape
Circle_constructor(int x, int y, double r) {
    Shape newShape;
    newShape.iType = Shape_Circle_T;
    newShape.data = Malloc(sizeof(struct Circle));
    ((Circle_P)newShape.data)->x = x;
    ((Circle_P)newShape.data)->y = y;
    ((Circle_P)newShape.data)->r = r;
    return newShape;
}

Shape
Rectangle_constructor(int x, int y, int l, int w) {
    Shape newShape;
    newShape.iType = Shape_Rectangle_T;
    newShape.data = Malloc(sizeof(struct Rectangle));
    ((Rectangle_P)newShape.data)->x = x;
    ((Rectangle_P)newShape.data)->y = y;
    ((Rectangle_P)newShape.data)->l = l;
    ((Rectangle_P)newShape.data)->w = w;
    return newShape;
}

Shape
NoShape_constructor() {
    Shape newShape;
    newShape.iType = Shape_NoShape_T;
    return newShape;
}

Shape
Foo_constructor(double x, double y, long toto) {
    Shape newShape;
    newShape.iType = Shape_Foo_T;
    newShape.data = Malloc(sizeof(struct Foo));
    ((Foo_P)newShape.data)->x = x;
    ((Foo_P)newShape.data)->y = y;
    ((Foo_P)newShape.data)->toto = toto;
    return newShape;
}

