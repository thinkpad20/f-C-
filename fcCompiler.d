import std.stdio, std.string, std.conv, std.algorithm, fcTokenizer, symbolTable;

bool showReports = false;
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
		writeCLine(format("    new%s.data = Malloc(sizeof(struct %s_%s));", ot.type, ot.type, it.type));
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
		writeCLine(format("typedef struct %s_%s * %s_%s_P;\n", ot.type, it.type, ot.type, it.type));
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
	return t.type == "true" || t.type == "false" || t.type == "null" || t.type == "this";
}

//bool isTerm(Token t) {
//	return t.type == "integerConstant" || t.type == "stringConstant" || isKeywordConstant(t)
//					|| t.type == "identifier" || t.type == "(" || isUnaryOp(t);
//}

bool isConstructorDec() {
	return isTerminal(tokens[next], "identifier") && isTerminal(tokens[next+1], "(");
}

bool isFCObject(Token t) {
	return false;
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
	int braceCount=1;
	Entry e;
	while (next < tokens.length && braceCount != 0) {
		report("LOOP");
		writeln("processing: ", tokens[next].symbol);
		if (isTerminal(tokens[next], "{")) {
			writeCLine(demand("{").symbol);
			++braceCount;
		}
		else if (isTerminal(tokens[next], "}")) {
			writeCLine(demand("}").symbol);
			--braceCount;
		}
		else if (isTerminal(tokens[next], "@match")) {
			e = processMatch();
			writeCInLine(format("if(%s.iType == %s_%s_T)", 
						e.symbol,
						e.oType.type,
						e.currentIType.type));
		}
		else if (isFCObject(tokens[next])) {
			report("1");
			e = sts.lookup(tokens[next++].symbol);
			// at this point, test if we're accessing a member of the object.
			if (isTerminal(tokens[next], ".")) {

			} else {

			}

			//writeCInLine(format("((%s_%s_P)%s)", 
			//	currentObject.oType.type, 
			//	currentIType.type, obj));
		}
		else if (e = sts.lookup(tokens[next].symbol), e !is null) {
			writeln("found a symbol ", e.symbol, " in the symbolTable");
			if (isTerminal(tokens[++next], ".")) {//are we accessing a member?
				demand(".");
				// check what the type of the member it's accessing is
				string fieldName = demand("identifier").symbol;
				string typ = e.currentIType.getType(fieldName);
				if (typ == "auto") {
					typ = e.pType;
					writeCInLine(format("*((%s *)(((%s_%s_P)%s.data)->%s))",
						typ, e.oType.type, e.currentIType.type, e.symbol, fieldName));
				} else {
					writeCInLine(format("((%s_%s_P)%s.data)->%s",
						e.oType.type, e.currentIType.type, e.symbol, fieldName));
				}
			}

		}
		else {
			string thingy = tokens[next++].symbol;
			writeln("unrecognized input: ", thingy);
			writeCInLine(thingy);
			if (thingy == ",")
				writeCInLine(" ");
			if (thingy == ";")
				writeCLine("");
		}
	}
	writeCLine("");
}

Entry processMatch() {
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

void compileParameters(innerType it) {
	writeIndented("<parameters>\r\n");
	++indentation;
	while (next < tokens.length && isType(tokens[next])) {
		string paramType = writeXML(tokens[next++]).symbol; // parameter type (int, char, etc)
		string paramName = writeXML(demand("identifier")).symbol; // parameter name
		it.addParam(paramType, paramName);
		if (next < tokens.length && isTerminal(tokens[next], ","))
			writeXML(tokens[next++]);
		else
			break;
	}
	--indentation;
	writeIndented("</parameters>\r\n");
}

/* <HIGHEST-LEVEL STRUCTURES> */
void compileData() {
	writeIndented("<@data>\r\n");
	++indentation;
	writeXML(demand("@data"));
	compileDataInfo();
	writeXML(demand("{"));
	while (isConstructorDec())
		compileConstructorDec();
	writeXML(demand("}"));
	--indentation;
	writeIndented("</@data>\r\n");
}

void compileDataInfo() {
	string dataInfo = writeXML(demand("identifier")).symbol; // get datatype name
	outerType t = new outerType(dataInfo, typeNum++);
	if (isTerminal(tokens[next], "!")) { // if parameterized
		t.isParametric = true;
		writeXML(demand("!"));
		string typ = writeXML(demandOneOf(varTypes)).symbol; //this will only be auto for now
		if (typ != "auto")
			throw new Exception("Parametric types must be declared with auto.");
	}
	types ~= t;
	outerTypeDict[dataInfo] = t; // add it to the type dictionary
	varTypes ~= dataInfo; // add it to the type list
}

void compileConstructorDec() {
	writeIndented("<constructorDec>\r\n");
	++indentation;
	string iType = writeXML(demand("identifier")).symbol; // name of the constructor
	innerType newInner = types[$-1].addInnerType(iType, typeNum++);
	// get the parameters
	writeXML(demand("("));
	compileParameters(newInner);
	writeXML(demand(")"));
	writeXML(demand(";")); // sadly, semicolons are probably necessary for now
	--indentation;
	writeIndented("</constructorDec>\r\n");
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
		compileData();
		writeDeclarations();
		compileFunctionHeader();
		compileFunctionBody();
		auto outputFile = File(filenameRoot ~ ".c", "w");
		//foreach(str; outputLines)
		//	outputFile.write(str);
		foreach(type; types) {
			write(type);
		}
		foreach(ln; outputC) {
			//write(ln);
			outputFile.write(ln);
		}
		//foreach(line; outputVM)
		//	outputFile.writeln(line);
		outputFile.close();
	}
}