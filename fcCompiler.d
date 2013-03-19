import std.stdio, std.string, std.conv, std.algorithm, fcTokenizer, symbolTable;

bool showReports = true;
int next, indentation, ifStatementCount, whileCount, numClassVars, typeNum = 100;
Token[] tokens;
string[] outputLines;
string[] outputC;
SymbolTableStack sts;
string className;
innerType currentIType;
string[] varTypes;
string[string] pointerCasts;
outerType[string] outerTypeDict;

bool printPush = false;
bool printPop = false;
bool printAdd = false;
bool printStack = false;
bool printVM = true;
bool printIfCount = true;

string constructorTemplate;

outerType[] types;

class TempPool {
	static int count;
	
}

void init() {
	varTypes = ["long", "short", "signed", "unsigned", "int", "char",
				"void", "bool", "float", "double", "identifier", "auto"];
}

/* Code generation */
void writeConstructor(outerType ot, innerType it) {
	writeCLine(format("%s", ot.type));
	string line = ot.type ~ "_" ~ it.type ~ "_constructor(";
	for (int i = 0; i < it.vars.length; ++i) {
		if (it.vars[i][0] != "auto")
			line ~= it.vars[i][0] ~ " " ~ it.vars[i][1];
		else
			line ~= "void *" ~ it.vars[i][1];
		if (i < it.vars.length - 1)
			line ~= ", ";
	}
	writeCLine(line ~ ") {");
	writeCLine(format("    %s new%s;", ot.type, ot.type));
	writeCLine(format("    new%s.iType = %s_%s_T;", ot.type, ot.type, it.type));
	if (it.numParams() > 0)
		writeCLine(format("    new%s.data = Malloc(sizeof(struct %s_%s));", 
							ot.type, ot.type, it.type));
	foreach(var; it.vars) {
		writeCLine(format("    ((%s_%s_P)new%s.data)->%s = %s;", 
			ot.type, it.type, ot.type, var[1], var[1]));
	}
	writeCLine(format("    return new%s;", ot.type));
	writeCLine("}\n");
}

void writeStruct(outerType ot, innerType it) {
	if (it.numParams() > 0) {
		// write the struct definition
		writeCLine("struct " ~ ot.type ~ "_" ~ it.type ~ " {");
		foreach(var; it.vars) {
			if (var[0] != "auto")
				writeCLine("    " ~ var[0] ~ " " ~ var[1] ~ ";");
			else
				writeCLine("    void *" ~ var[1] ~ ";");
		}
		writeCLine("};");
		writeCLine(format("typedef struct %s_%s * %s_%s_P;\n", 
						ot.type, it.type, ot.type, it.type));
	}
}

/* /code generation */

void report(string location = "") {
	if (showReports) {
		if (next < tokens.length)
			writefln("%s next = %s, tokens[next] = %s", location, next, tokens[next]);
		else
			writefln("%s next = %s, end of file", location, next);
	}
}

Token demand(string type) {
	Token ret = tokens[next++];
	if (type != ret.type)
		throw new Exception(format("Error: expected type %s", type));
	return ret;
}

Token demandOneOf(string[] typeList) {
	Token ret = tokens[next++];
	if (!canFind(typeList, ret.type))
		throw new Exception(format("Error: expected one of types %s", typeList));
	return ret;	
}

///* <FORMATTING FUNCTIONS> */
string indent(string str) {
	string res;
	for (int i=0; i<indentation; ++i)
		res ~= "  ";
	return res ~ str;
}

void writeIndented(string str) {
	outputLines ~= indent(str);
	write(indent(str));
}

void writeCLine(string str) {
	outputC ~= str ~ "\n";
}

void writeCInLine(string str) {
	outputC ~= str;
}

Token writeXML(Token t) {
	writeIndented(t.getXML());
	//writeln(t.getXML());
	return t;
}

///* </FORMATTING FUNCTIONS */

///* <CHECKING FUNCTIONS> */
bool isTerminal(Token t, string type) {
	return t.type == type;
}

bool isType(Token t) {
	foreach(type; varTypes) {
		if (isTerminal(t, type)) return true;
	}
	return false;
}

bool isFCType(Token t) {
	if (t.symbol in outerTypeDict)
		return true;
	else
		return false;
}

bool isKeywordConstant(Token t) {
	return t.type == "true" || t.type == "false" 
	|| t.type == "null" || t.type == "this";
}

outerType isConstructor(Token t) {
	foreach(ot; outerTypeDict.values) {
		if (ot.hasInnerType(t.symbol) && tokens[next-1].symbol != ":")
			return ot;
	}
	return null;
}

bool isConstructorDec() {
	return isTerminal(tokens[next], "identifier") && isTerminal(tokens[next+1], "(");
}

/* </STATEMENT COMPILERS> */

void compileFunctionHeader() {
	sts.push(); // new symbol table
	/* ex: List!auto foo(List!auto l, int i, Maybe m) */
	if (isFCType(tokens[next])) // check if return type is an f(C) type
		writeCInLine(processType(true) ~ " ");
	else
		writeCInLine(demandOneOf(varTypes).symbol ~ " "); // otherwise write down the original C
	writeCInLine(demand("identifier").symbol); //next is the function name, leave it as-is
	writeCInLine(demand("(").symbol);
	while (!isTerminal(tokens[next], ")")) {
		if (isFCType(tokens[next])) {
			string type = processType(); // scan the arguments list for f(C) types
			writeCInLine(type ~ " "); // the C-version only gets the outer type name
		} else
			writeCInLine(tokens[next++].symbol ~" "); // otherwise just write it down
	}
	writeCInLine(demand(")").symbol);
}

void compileFunctionBody() {
	// start with the opening brace, and continue until we've encountered the last closing brace
	writeCLine(demand("{").symbol);
	string varDecs, funcBody;
	int braceCount=1;
	Entry e, e2;
	int declaredTemps = 0, declaredIters = 0;
	outerType ot;
	bool newStatement;
	while (next < tokens.length && braceCount != 0) {
		report("LOOP");
		report("processing: " ~ tokens[next].symbol);
		//look ahead to the end of the line to see if there are any constructors;
		// if so this may require us writing out some additional statements.
		if (newStatement)
			scanForPreDecs(funcBody);

		if (isTerminal(tokens[next], "{")) {
			funcBody ~= demand("{").symbol ~ "\n";
			++braceCount;
		}
		else if (isTerminal(tokens[next], "}")) {
			funcBody ~= demand("}").symbol ~ "\n";
			--braceCount;
		}
		else if (isTerminal(tokens[next], "@match")) {
			processMatch(funcBody);
		}
		else if (isFCType(tokens[next])) {
			convertFCType(varDecs);
		}
		else if (e = sts.lookup(tokens[next].symbol), e !is null) {
			++next;
			//writeln("found a symbol ", e.symbol, " in the symbolTable");
			if (isTerminal(tokens[next], ".")) {//are we accessing a member?
				convertMemberAccess(e, funcBody);
			} else if (isTerminal(tokens[next], "=")) { // assignment
				convertFCAssignment(e, e2, varDecs, funcBody, declaredTemps, declaredIters);
			} else { // then it's being used as-is as an argument
				funcBody ~= e.symbol;
			}

		}
		else if (ot = isConstructor(tokens[next]), ot !is null) {
			Entry tempE = new Entry("temp", ot);
			convertConstructor(tempE, varDecs, funcBody, declaredTemps, false);
		}
		else {
			string thingy = tokens[next].symbol;
			//writeln("unrecognized input: ", thingy);
			funcBody ~= thingy ~ " ";
			if (thingy == ";") {
				newStatement = true;
				funcBody ~= "\n";
			}
			next++;
		}
	}
	writeCInLine(varDecs ~ "\n" ~ funcBody);
}

void scanForPreDecs(ref string funcBody) {
	outerType ot;
	string dummy1, dummy2; int dummy3;
	int save = next;
	//for each ;, do one pass where we don't write anything except
	// predeclarations. then a second pass where we act as normal.
	while (next < tokens.length && tokens[next].symbol != ";") {
		// we'll just write the "pre-declarations" that need to happen
		// to facilitate the constructor call.
		if (isTerminal(tokens[next], "@match")) {
			processMatch(funcBody, true);
		}
		else if (ot = isConstructor(tokens[next]), ot !is null) {
			Entry tempE = new Entry("temp", ot);
			writeln("gonna make a constructor for an ", ot.type);
			funcBody ~= convertConstructor(tempE, dummy1, dummy2, 
											dummy3, false);
		}
		else {
			next++;
		}
	}
	next = save;
}

void convertFCAssignment(Entry e, Entry e2, ref string varDecs, 
					ref string funcBody, ref int declaredTemps, 
					ref int declaredIters) {
	++next; // skip the = sign
	if (e.oType.hasInnerType(tokens[next].symbol)) { // constructor
		report("converting a constructor");
		convertConstructor(e, varDecs, funcBody, declaredTemps, true);
		report("finished converting constructor");
	} else if (isTerminal(tokens[next], "{")) { // list-specific constructor
		report("converting an initializer list");
		convertInitializerList(e, varDecs, funcBody, 
			declaredTemps, declaredIters);
	} else if (tokens[next].category == TokenCat.STRCONST) {
		convertStringConstant(e, varDecs, funcBody, 
			declaredTemps, declaredIters);
	} else if (e2 = sts.lookup(tokens[next].symbol), e2) { 
			// assignment to another object
			if (e2.oType.type == e.oType.type) {
				writeln("copy constructor invoked here?");
				funcBody ~= e.symbol ~ " = " ~ e2.symbol ~ ";\n";
			} else
				throw new Exception("Type mismatch!");
	} else
		throw new Exception("Invalid assignment");
}

void convertFCType(ref string varDecs) {
	string varName, paramT;
	outerType ot = outerTypeDict[tokens[next++].symbol]; // get the OT
	// if it's a parametric type, we require the type to be declared
	if (ot.isParametric) {
		demand("!");
		paramT = tokens[next++].symbol;
		varName = tokens[next++].symbol;
		sts.addSymbol(varName, ot, paramT);
	} else {
		varName = tokens[next++].symbol;
		sts.addSymbol(varName, ot);
	}
	varDecs ~= format("%s %s;\n", ot.type, varName);
}

void convertMemberAccess(Entry e, ref string funcBody) {
	demand(".");
	// check what the type of the member it's accessing is
	string fieldName = demand("identifier").symbol;
	string typ = e.currentIType.getType(fieldName);
	if (typ == "auto") {
		typ = e.pType;
		funcBody ~= format("*((%s *)(((%s_%s_P)%s.data)->%s))",
			typ, e.oType.type, e.currentIType.type, e.symbol, fieldName);
	} else {
		funcBody ~= format("((%s_%s_P)%s.data)->%s",
			e.oType.type, e.currentIType.type, e.symbol, fieldName);
	}
}

string getNextArg() {
	Entry e;
	string arg;
	while (tokens[next].symbol != "," && tokens[next].symbol != ")") {
		if (e = sts.lookup(tokens[next].symbol), e !is null) {
				++next;
				if (isTerminal(tokens[next], "."))
					convertMemberAccess(e, arg);
				else
					arg ~= e.symbol;
		} else {
			arg = tokens[next++].symbol;
		}
	}
	return arg;
}

string convertConstructor(Entry e, ref string varDecs, 
						ref string funcBody, ref int declaredTemps,
						bool assignment) {
	// find the list of variables expected for this inner type.
	int usedTemps = 0;
	innerType it = e.oType.getInnerType(tokens[next++].symbol);
	demand("("); // get the opening parens
	int paramCount = 0;
	string args = "";
	string preDecs;
	while (paramCount < it.numParams()) {
		report("x1");
		string arg = getNextArg();
		if (it.vars[paramCount][0] == "auto") {
			report("x2");
			if (++usedTemps > declaredTemps) {
				++declaredTemps;
				varDecs ~= format("void *temp%s;\n", usedTemps);
			}
			preDecs ~= format("temp%s = Malloc(sizeof(%s));\n", 
								usedTemps, e.pType);
			preDecs ~= format("*(%s *)temp%s = %s;\n", e.pType, usedTemps, 
				arg);
			args ~= format("temp%s", usedTemps);
		} else {
			args ~= arg;
		}
		++paramCount;
		report("x3");
		if (paramCount != it.numParams()) {
			args ~= demand(",").symbol;
		}
	}
	demand(")");
	if (assignment) funcBody ~= e.symbol ~ " = ";
	funcBody ~= format("%s_%s_constructor(%s)", e.oType.type, it.type, args);

	return preDecs;
}

void convertInitializerList(Entry e, ref string varDecs, 
							ref string funcBody, ref int declaredTemps,
							ref int declaredIters) {
	if (declaredTemps == 0) {
		varDecs ~= "void *temp1;\n";
		++declaredTemps;
	}
	if (declaredIters == 0) {
		varDecs ~= "int __it1;\n";
		++declaredIters;
	}
	string arrDec = format("%s %svals[] = {", e.pType, e.symbol);
	demand("{");
	int numItems = 0;
	//for now, we'll only allow primitives to be declared here.
	while(!isTerminal(tokens[next], "}")) {
		if (isTerminal(tokens[next], ","))
			++numItems;
		arrDec ~= tokens[next++].symbol;
	}
	arrDec ~= demand("}").symbol ~ ";\n";
	varDecs ~= arrDec;
	funcBody ~= e.symbol ~ " = List_Empty_constructor();\n";
	funcBody ~= format("for(__it1 = %s; __it1 >= 0; --__it1) {\n"
						~ "temp1 = Malloc(sizeof(%s));\n"
	    				~ "*(%s*)temp1 = %svals[__it1];\n"
	    				~ "%s = List_Cons_constructor(temp1, %s);\n}\n",
	    				numItems, e.pType, e.pType, e.symbol, e.symbol, e.symbol);
	demand(";");
}

void convertStringConstant(Entry e, ref string varDecs, 
							ref string funcBody, ref int declaredTemps,
							ref int declaredIters) {
	if (e.pType != "char")
		throw new Exception("You cannot use a string literal without a char list.");
	if (declaredTemps == 0) {
		varDecs ~= "void *temp1;\n";
		++declaredTemps;
	}
	if (declaredIters == 0) {
		varDecs ~= "int __it1;\n";
		++declaredIters;
	}
	string arrDec = format("char %schars[] = \"", e.symbol);
	ulong numItems = tokens[next].str.length;
	arrDec ~= tokens[next++].str ~ "\"";
	//for now, we'll only allow primitives to be declared here.
	arrDec ~= ";\n";
	varDecs ~= arrDec;
	funcBody ~= e.symbol ~ " = List_Empty_constructor();\n";
	funcBody ~= format("for(__it1 = %s; __it1 >= 0; --__it1) {\n"
						~ "temp1 = Malloc(sizeof(%s));\n"
	    				~ "*(%s*)temp1 = %schars[__it1];\n"
	    				~ "%s = List_Cons_constructor(temp1, %s);\n}\n",
	    				numItems-1, e.pType, e.pType, e.symbol, e.symbol, e.symbol);
	demand(";");

}

Entry processMatch(ref string funcBody, bool readOnly = false) {
	++next; // skip over the "@match"
	demand("(");
	string name = demand("identifier").symbol;
	Entry e = sts.lookup(name);
	if (e) {
		demand(":");
		// the next identifier tells us which of the inner types we're dealing with
		e.currentIType = e.oType.getInnerType(demand("identifier").symbol);
		demand(")");
	} else {
		throw new Exception("Symbol " ~ name ~ " is undefined.");
	}
	if (!readOnly)
		funcBody ~= format("if(%s.iType == %s_%s_T)", 
								e.symbol,
								e.oType.type,
								e.currentIType.type);
	return e;
}

string processType(bool isReturnType = false) {
	string variableName;
	string typeName = demand("identifier").symbol; // get the main type
	string paramTypeName;
	bool isParametric = false;
	if (isTerminal(tokens[next], "!")) {
		if (outerTypeDict[typeName].isParametric) {// make sure the outer type is parametric
			++next;
			paramTypeName = demandOneOf(varTypes).symbol;
			isParametric = true;
		} else {
			throw new Exception(format("%s is not a parametric type.", typeName));
		}
	}
	//next, grab the name of the variable itself
	if (isReturnType)
		variableName = "__RETURN_TYPE__";
	else
		variableName = tokens[next].symbol; // note we're not incrementing the pointer
	// record the instance if it's an fC type
	if (typeName in outerTypeDict) {
		if (isParametric)
			sts.addSymbol(variableName, outerTypeDict[typeName], paramTypeName);
		else
			sts.addSymbol(variableName, outerTypeDict[typeName]);
	}

	return typeName;
}

void compileParameters(innerType it, bool skip = false) {
	while (next < tokens.length && isType(tokens[next])) {
		string paramType = tokens[next++].symbol; // parameter type (int, char, etc)
		if (isTerminal(tokens[next], "!")) {
			demand("!"); next++;
			//paramType ~= "!" ~ tokens[++next].symbol;
			//++next;
		}
		string paramName = demand("identifier").symbol; // parameter name
		if (!skip) it.addParam(paramType, paramName);
		if (next < tokens.length && isTerminal(tokens[next], ","))
			next++; // skip the comma
		else
			break;
	}
}

/* <HIGHEST-LEVEL STRUCTURES> */
void compileData(bool skip = false) {
	demand("@data");
	compileDataInfo(skip);
	demand("{");
	while (isConstructorDec())
		compileConstructorDec(skip);
	demand("}");
}

void compileDataInfo(bool skip = false) {
	string dataInfo = demand("identifier").symbol; // get datatype name
	outerType t = new outerType(dataInfo, typeNum++);
	if (isTerminal(tokens[next], "!")) { // if parameterized
		t.isParametric = true;
		demand("!");
		string typ = demandOneOf(varTypes).symbol; //this will only be auto for now
		if (typ != "auto")
			throw new Exception("Parametric types must be declared with auto.");
	}
	if (!skip) {
		types ~= t;
		outerTypeDict[dataInfo] = t; // add it to the type dictionary
		varTypes ~= dataInfo; // add it to the type list
	}
}

void compileConstructorDec(bool skip = false) {
	//if (!skip) writeIndented("<constructorDec>\r\n");
	innerType newInner;
	string iType = demand("identifier").symbol; // name of the constructor
	if (!skip) newInner = types[$-1].addInnerType(iType, typeNum++);
	// get the parameters
	demand("(");
	compileParameters(newInner, skip);
	demand(")");
	demand(";"); // sadly, semicolons are probably necessary for now
}

/* </HIGHEST-LEVEL STRUCTURES> */

void reset() {
	ifStatementCount = whileCount = 0;
	outputLines = [];
	outputC = [];
	next = 0;
	numClassVars = 0;
}

void writeDeclarations() {
	writeCLine("#include \"c/datatype.h\"\n");
	foreach(type; types) {
		writeCLine(format("#define %s_T %s", type.type, type.num));
		foreach(iType; type.innerTypes) {
			writeCLine(format("#define %s_%s_T %s", type.type, iType.type, iType.num));
		}
		writeCLine("\n");
		writeCLine(format("typedef struct datatype %s;\n", type.type));
		foreach(iType; type.innerTypes) {
			writeStruct(type, iType);
		}
	}

	foreach(type; types) {
		foreach(iType; type.innerTypes)
			writeConstructor(type, iType);
	}
}

void compileDataDecs() {
	int save = next;
	int dataDecCount = 0;
	while (next < tokens.length) {
		if (isTerminal(tokens[next], "@data")) {
			compileData();
			dataDecCount++;
		}
		else
			next++;
	}
	writeDeclarations();
	next = save;
	//writefln("Found and compiled %s datatypes", dataDecCount);
}

void compileFunctions() {
	int save = next;
	int funcCount;
	while (next < tokens.length) {
		if (isTerminal(tokens[next], "@data"))
			compileData(true); //skip over it
		else if (isType(tokens[next])) {
			compileFunctionHeader();
			compileFunctionBody();
			funcCount++;
		}
		else
			next++;
	}
	next = save;
}

void main(string[] args) {
	init();
	Tokenizer t;
	t.init();
	for (int i=1; i<args.length; ++i) {
		string filenameRoot = args[i].split(".")[$-2];
		t.prepare(args[i]);
		t.lex();
		tokens = t.getTokens();
		reset();
		compileDataDecs();
		compileFunctions();
		auto outputFile = File(filenameRoot ~ ".c", "w");
		//foreach(type; types) {
		//	write(type);
		//}
		foreach(ln; outputC) {
			outputFile.write(ln);
		}
		//foreach(line; outputVM)
		//	outputFile.writeln(line);
		outputFile.close();
	}
}