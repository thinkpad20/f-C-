Musings and plannings: the beginnings of a true functional extension to C

At the urging of a friend of mine, I've begun to take interest in the functional programming paradigm. The paradigm offers many advantages which I don't need to enumerate here but include code readability, a high level of abstraction without loss of power, code safety and compatibility with multi-threaded methods. My favorite programming language, however, is C, which I love for its simplicity, efficiency and bit-level precision of routines.

Someone else at my school came up with some ways to "hack" functional programming into C. He introduced a fundamental list data type and using it, incorporated closures, maps, and a few other functional staples. Although the idea was somewhat in jest, and on its own demonstrated only a weak ability for C to be functional, it was nonetheless interesting, and I played around a bit with what he had come up with. Thinking more about it, I reasoned that C, being a very small and simple language, is quite readibly extensible. After all its most famous child C++ simply began by extending C with some ideas from object-oriented programming. My ideas on C++ notwithstanding, it remains the case that C provides an excellent framework upon which to append ideas. C++ originally compiled to C, and this made me wonder if I might not be able to accomplish something similar by designing some functional structures which I could paste on top of C, allowing me to use my favorite language while having access to some of the great things to be found in functional languages. Here are some of the ideas I've come up with - most are rudimentary to say the least, but I'd like to think they have promise.

One of the most advantageous aspects of Haskell are its algebraic types, especially when combined with its potent pattern-matching capabilities. In sketching out the ways in which C could be extended to adopt the functional paradigm, natively incorporating these along with other features of Haskell is an appealing prospect. Let's examine how we might do this.

Here's an example of an algebraic data type in Haskell (from Real World Haskell chapter 3):

```haskell
data BillingInfo = CreditCard CardNumber CardHolder Address
                 | CashOnDelivery
                 | Invoice CustomerID
```

Here's an implementation of the same idea in C:

```c
typedef struct BillingInfo BillingInfo; 
struct BillingInfo {
    enum { CreditCard_t, CashOnDelivery_t, Invoice_t } t;
    union {
        struct { int CardNumber; char *CardHolder; char *Address; } CreditCard;
        /* note that we don't need a struct to hold CashOnDelivery */
        struct { char *CustomerID; } Invoice;
    } data;
};

BillingInfo 
CreditCard(int CardNumber, char *CardHolder, char *Address) {
    BillingInfo bi;
    bi.t = CreditCard_t;
    bi.data.CreditCard.CardNumber = CardNumber;
    bi.data.CreditCard.CardHolder = CardHolder;
    bi.data.CreditCard.Address = Address;
    return bi;
}

BillingInfo 
CashOnDelivery(void) {
    BillingInfo bi;
    bi.t = CashOnDelivery_t;
    return bi;
}

BillingInfo 
Invoice(char *CustomerID) {
    BillingInfo bi;
    bi.t = Invoice_t;
    bi.data.Invoice.CustomerID = CustomerID;
    return bi;
}

```

As we can see, this is verbose and hides the simple idea that the data structure is supposed to convey - that it can be one of a few things. Furthermore, this structure is not safe - although the enum, if queried, will tell us the type of of BillingInfo we're dealing with, we cannot guarantee that it's being used properly, and it is subject to arbitrary change. A much cleaner syntax would mirror that of Haskell:

```
data BillingInfo {
    CreditCard(String cardNumber, String cardHolder, String address)
    CashOnDelivery()
    Invoice(String customerID)
}
```

Isn't that much better? In a functional C language, the above representation would be a concise way to tell the compiler to generate objects as we had seen above (along, possibly, with some additional functions which we might use for pattern matching, "deriving", etc). Note that we're tentatively getting rid of semicolons for as clean an interface as possible. This may be changed if it complicates parsing. Also note that if we want to keep this language a strict superset of C, then we might want to write `data` as `@data` or some other way to guarantee there won't be name conflicts. If only for aesthetic purposes, however, I'll keep it this way for now.

Another useful feature to be found in a language like Haskell is case-based function declarations. Take the following definition of the sum of a list in Haskell:

```haskell
sumList :: [Int] -> Int
sumList [] = 0
sumList (x:xs) = x + sumList xs

```

We could mirror this in C:

```c
struct list {
    int val;
    struct list *next;
};

int sumList(struct list *l) {
    if (l.next == NULL)
        return 0;
    return l->val + sumList(l->next); 
}

```

Now in this case, the C version isn't significantly longer than the Haskell, nor is it more difficult to understand. However, there are many cases where this is not the case, and having the ability to simply define base case/nth case, or even multiple disparate cases, comes in handy. Let's formulate a (prototypical) syntax for this in functional C:

```
int sumList(list *l) {
    sumList (l : l->next == NULL) { 
        return 0 
    }
    sumList (l) { 
        return l->val + sumList(l->next) 
    }
}
```

As in Haskell, this function will be evaluated in a fall-through manner. The first definition for which the predicate is true will be evaluated.

In functional programming, the singly-linked list will be such a fundamental data structure that it's probably best to make it a primitive, wrapped around something like:

```c
struct list {
    void *data;
    struct list *next;
}
```

Note that this may not actually be the internal representation of a list, especially if we create list using the algebraic type system (which is what we'll do - see below). Either way, let's assume that this can be denoted with a new primitive data type list (as with data, we may want to add an at sign to facilitate functional C being a strict superset of C). Let's also assume that we have some notation and operators that are essential for lists:

```
list!int a            // a is a pointer to a struct list (the * is implied). Internally it uses void *. Note we're using the ! syntax from D.
boolean isEmpty = !a  // isEmpty is true (the ! operator on a list l is the same thing as "l->next == NULL")
a = {1, 3, 5, 7}      // the compiler can read that a is a list of ints and construct it accordingly
int i = .a            // . is the head operator. i == 1
list!int b = a..    // .. is the tail operator. b == {3, 5, 7}
```

Keep in mind that all of these operators are tentative, but we definitely want to have an easy way to denote the head and tail of a list. We'll get to the pattern matching stuff later (I hope). OK, now that we have some operators, let's see if we can simplify our sumList function:

```
int sumList(list!int l) {
    sumList(l : !l) {
        return 0
    }
    sumList(l) {
        return .l + sumList(l..)
    }
}

```

What if we simplified it a bit further? Note that I'm still just kinda spitballing...

```
int sumList(list!int l) {
    match (!l) { return 0 }
    match (l) { return .l + sumList(l..) }
}
```

Here I'm envisioning match to be a boolean function which may be a simple if but could allow us to do pattern matching, perhaps allow us to do more advanced Haskell-like pattern matching (e.g. multiple representations of the same data) at some future point.

Now let's employ several more steps of evolution. We'll allow curly braces to be omitted as long as the function body is only one line. We'll borrow the keyword "auto" and use it in the D/C++ way, to indicate that the return value is inferred. Similarly, we won't explicitly define what kind of list l is. We'll drop the * from the list variable -- as a primitive data type, it's pointer-ness should be implied anyway (there could perhaps be special mechanisms to create non-heap list nodes). And we'll use the => symbol to declare that the next statement (or the final statement of a block) is a return. We could simply make this default behavior, but this gives a clearer syntax anyway. It might be desirable to have the => itself be optional -- just useful for clarification. We'll see. Note that we're allowing a return to be explicitly declared if desired. This would give us:

```
auto sumList(list l) {
    match (!l) => 0
    match (l) => .l + sumList(l..)
}
```

Let's imagine how this would look given an algebraic-type definition of a list. In Haskell, a list is defined as:

```haskell
data [] a = [] | a : [a]
```

Or equivalently:

```haskell
data List a = Empty | Cons a (List a)
```

Using our algebraic definitions from before, let's try to make one of these in functional C:

```
datatype list!auto {
    empty()
    cons(auto head, list!auto tail)
}
```

By adopting a C++ style auto keyword, we are also allowing parameterized types. Any framework which can reliably infer the type of a variable, can also do all of the appropriate conversions and casts in the code. It may also be desirable to let functions be defined multiple times for different types, but at least initially, we won't implement this.

Just so we don't lose track of what we're going for, let's see how this would look in ANSI C code, and let's switch to lower case letters for a more C-style look:

```c
typedef
struct list_ {
    enum {empty_t, cons_t} t; 
    union {
        struct { void *head; struct list_ *next; } cons;
    } data;
}
List;

List *
empty(void) {
    List *l = malloc(sizeof(List));
    if (!l) exit(1);
    l->t = empty_t;
    return l;
}

List *
cons(void *a, List *next) {
    List *l = malloc(sizeof(List));
    if (!l) exit(1);
    l->t = cons_t;
    l->data.cons.head = a;
    l->data.cons.next = next;
    return l;
}
```

So we can see that if we imagine including a "typedef List* list;" statement to our C code, then we are effectively modeling (assuming the dereferencing is automatic) the list type in functional C.

Now let's try to implement some fundamental list operations. We'll take the expression data.type to be a boolean expression which evaluates to true if the data is of the specified type.

```
// (Restatement)
datatype list!auto {
    empty()
    cons(auto head, list!auto tail)
}

bool op(asBool)(list a) {
    match(a.empty) => false
    match(a.cons) => true
}

auto op(.)(list a)
    match(a) => a.head

auto op(..)(list a)
    match(a) => a.tail

list op(~)(auto x, list a) => cons(x, a)

list op([])(auto a) => a ~ empty()

list op(++)(list a, list b) {
    match(!a, b) =>                // at this point ++ is already defined,
    match(a, b) => .a ~ (a.. ++ b) // so we can use it in our recursion
}

auto head(list a)
    match(a) => .a

list tail(list a)
    match(a) => a..

list init(list a) {
    match(a : !a..) => empty()
    match(a) => .a ~ init(a..)
}

auto last(list a) {
    match(a : !a..) => .a
    match(a) => last(a..)
}
```

A few things I've introduced here. For one, we've defined some operator overloaders; the syntax for this will be op(symbol)(params). Binary vs unary operators can be inferred from the parameters given. To be clear, the : symbol indicates "such that." Note that we're using the `.a` and `a..` syntax from above (and defined in the operator overloader functions). If that's confusing (or simply to keep it more C-like), we could use a struct-dereference style call. Also note that we have to inform our compiler that when evaluating a list as a boolean, we return true if in the C-version, `a->t != empty_t`. Realizing this is a valuable thing, I defined an `op(asBool)` function above (note that we'll probably make the default something like `bool op(asBool) (auto x) => true`). As our `op(asBool)` function tells us, we could use `match(a.cons)` or `match(a.empty)`, since the constructor names also match to boolean expressions which tell us which constructor was used to build `a`. This would probably be what we want in a data type with more than two possibilities. Either way, we have some pattern matching -- this may be somewhat primitive compared to what Haskell is doing, but it seems to work. Let's try a possible conversion of the above functions to C code. We'll skip over some of the operator overloaders and rename the other two to something readable -- in a "real" compiled-to-C version, these would probably be given generic (and ugly) names.

```c
typedef List* list;

list singleton(void *a) {
    return cons(a, empty());
}

list concat(list a, list b) {
    if (a->t == empty_t)
        return b;
    return cons(a->data.cons.head, concat(a->data.cons.tail, b));
}

void *head(list l) {
    if (l->t == cons_t)
        return l->data.cons.head;
    printf("Exception: calling head on an empty list\n");
    exit(1);
}

list tail(list l) {
    if (l->t == cons_t)
        return l->data.cons.tail;
    printf("Exception: calling tail on an empty list\n");
    exit(1);
}

list init(list l) {
    if (l->t == cons_t && l->data.cons.tail == NULL)
        return empty();
    if (l->t == cons_t)
        return concat(singleton(l->data.cons.head), init(l->data.cons.tail));
    printf("Exception: calling init on an empty list\n");
    exit(1);
}

void *last(list l) {
    if (l->t == cons_t && l->data.cons.tail == NULL)
        return l->data.cons.head;
    if (l->t == cons_t)
        return last(l->data.cons.tail);
    printf("Exception: calling last on an empty list\n");
    exit(1);
}
```

Note that our simplistic "exceptions" are thrown whenever we fail to satisfy any of the possible matches. Also note that the functional C code for head, tail, init and last is 15 lines, while the ANSI C for the same functions is double that, and considerably less readable. The difference is quite a bit more pronounced when the definition and constructors of the List data type are also included.

Obviously, much more needs to be done in order to solidify the ideas at work and the syntax - not to mention implementing more advanced functional concepts. One that we can address next is lambda functions. Let's imagine how one of them might look in a f(C) code:

```
list map(list a, function f) {
    match(!a, f) => empty()
    match(a, f) => f(.a) ~ map(a.., f)
}

datatype Num {
    Int(int i)
    Double(double d)
}

list!Num squareList(list!Num a) =>
    map(a, lambda(x) => x*x)
```

Here map is a function which takes a function (here declared generically as a simple type; this definition might need to be more robust) and a list, and returns a list where the function has been applied to each item in the list. The keyword 'lambda' in this case is fulfilling a similar function to 'match' in our normal function declarations. 


Assuming we have some pattern-matching capabilities in play, we could even make a pattern-matching lambda function:

```
list!int intSquareList(list!Num a) =>
    map(a,
        lambda(x.Int) => x*x
        lambda(x) => int(x*x) // like match, order matters
       )
```

This would be functionally equivalent to:

```
int intSquare(Num n) {
    match(n.Int) => n*n
    match(n.Double) => int(n*n)
}

list!int intSquareList(list!Num a) =>
    map(a, intSquare)
```

Let's remind ourselves how the Num datatype and its constructors would look after compilation to C (this may be a "prettier" version of how they would actually look, depending on how much modification to type names, etc is required to maintain uniqueness):

```c
struct Num {
    enum {Int_t, Double_t} t;
    struct {
        struct { int val; } Int;
        struct { double val; } Double;
    } data;
}

struct Num 
Int(int val) {
    struct Num newData;
    newData.t = Int_t;
    newData.data.Int.val = val;
    return newData;
}

struct Num 
Double(double val) {
    struct Num newData;
    newData.t = Double_t;
    newData.data.Double.val = val;
    return newData;
}
```

Once those definitions are out of the way, implementing a lambda function to C might be relatively straightforward: we simply write a version of the function outside of the function we're calling from, and call it as normal:

```c
struct Num lambda0(struct Num x) {
    if (x.t == Int_t)
        return Int(x.data.Int.val * x.data.Int.val);
    return Double(x.data.Double.val * x.data.Double.val);
}

list squareList(list l) {
    if (l->t == empty_t)
        return empty();
    if (l->t == cons_t)
        return concat(singleton(lambda0(l->data.cons.head)), 
                      squareList(l->data.cons.tail));
}
```

Note that our lambda function, just like its counterpart in f(C), returns the polymorphic type Num. In our example with pattern-matching lambdas, we guaranteed it returned an int. Let's see how this would look:

```c
int lambda0(Num x) {
    if (x.t == Int_t)
        return (x->data.Int.val)*(x->data.Int.val);
    return int(x->data.Double.val)*(x->data.Double.val);
}

list squareList(list l) {
    if (l->t == empty_t)
        return empty();
    if (l->t == cons_t)
        return concat(singleton(Int(lambda0(l->data.cons.head))), 
                      squareList(l->data.cons.tail));
}
```
Note that we are smoothing over the important issue that `singleton`, as defined above, takes a `void *` as its argument, and `Int` returns a value on the stack. This raises the essential question of how variables are allocated and deallocated. My idea on this one so far (which has not always been reflected in the code samples I've written) is to have all `data` objects be allocated on the heap and garbage-collected (as they are in Haskell), while allowing local variables, and any regular C datatypes to be allocated as indicated by the user. Clearly the performance of the garbage collector will be key, as will the efficacy of any number of optimizations possible by the code (such as tail-call optimizations in our list operations). All of these things will remain works in progress, presumably, for some time to come. For now, however, let's just maintain the pleasant assumption that `singleton` and all other functions are magically polymorphic.

Now that I mention it, the idea that all internal variables of an algebraic datatype might be pointers means that we might be able to simplify our structures by using an internal array of `void *`s rather than a tagged union.

Let's try this approach to build a datatype which can represent a circle or a rectangle:

```
datatype Shape {
    Circle(int x, int y, double radius)
    Rectangle(int x, int y, int length, int width)
}
```

In C:

```c

struct Shape {
    enum {Circle_t, Rectangle_t} t;
    void **vars;
}

struct Shape
Circle (int x, int y, double radius) {
    struct Shape newData;
    newData.t = Circle_t;
    newData.vars = malloc(3 * sizeof(void *)); // allocate a void * for each variable
    newData.vars[0] = malloc(sizeof(int));   // x
    newData.vars[1] = malloc(sizeof(int));   // y
    newData.vars[2] = malloc(sizeof(double));   // radius
    *newData.vars[0] = x;
    *newData.vars[1] = y;
    *newData.vars[2] = radius;
    return newData;
}

struct Shape
Rectangle (int x, int y, int length, int width) {
    struct Shape newData;
    newData.t = Rectangle_t;
    newData.vars = malloc(4 * sizeof(void *));
    newData.vars[0] = malloc(sizeof(int));
    newData.vars[1] = malloc(sizeof(int));
    newData.vars[2] = malloc(sizeof(int));
    newData.vars[3] = malloc(sizeof(int));
    *newData.vars[0] = x;
    *newData.vars[1] = y;
    *newData.vars[2] = length;
    *newData.vars[3] = width;
    return newData;
}
```
This seems a little more elegant to me, although it remains to be seen if it's superior in practice. Pulling data out of these guys should be simpler. Let's try some functions in f(C):

```
//assume pi is a Num type defined somewhere

Num Area(Shape s) {
    match(s.Circle) => pi*Double(s.radius*s.radius)
    match(s.Rectangle) => Int(s.length * s.height)
}

// Note that having to write a constructor for the Num type is a 
// little cumbersome; we might want to implement machinery to do this.
// also note that it's getting quite silly to write x*x over and over - 
// we'll probably wrap this in an operator.
```

Let's see that in C with our new formulation:

```c
#define PI 3.141592654

struct Num
Area(struct Shape s) {
    if (s.t == Circle_t)
        return PI * (*(double *)s.vars[2]) * (*(double *)s.vars[2]);
    return (*(int *)s.vars[2]) * (*(int *)s.vars[3]);
}
```

Although we have a somewhat hard-on-the-eyes pointer dereference situation, I think in the end this is cleaner (note that previously I had been smoothing that over). Pursuing this idea a bit further, we could do away with the num type entirely, instead defining a generic "data" type which we could customize to hold anything:

```c
struct datatype {
    int oType;
    int iType;
    void **vars;
}
```

"oType" and "iType" stand for inner and outer type: the former distinguishes different `data` from each other, and the latter distinguishes two `data` of the same type. (Presumably programmers won't require more than 4 billion data types, so an `int` should suffice to account for the type.)

Then to define a specific data type, all we need is to define the relevant constructors and add appropriate `#define` statements to indicate the type possibilities:

```c
#include "fc_data.h"
#define Shape_DATA_OTYPE 122
#define Circle_DATA_ITYPE 123
#define Rectangle_DATA_ITYPE 124

struct data
Circle_constructor (int x, int y, double radius) {
    struct datatype newData;
    newData.oType = Shape_DATA_OTYPE;
    newData.iType = Circle_DATA_ITYPE;
    [...]
}
```

This is much more elegant and extensible; I'm leaning towards this. If everything's allocated on the heap anyway, why worry? :) Also this allows us to define new datatypes without recompiling, or even create "anonymous" temporary datatypes inside of a single context! Perfect for an interpreter.
