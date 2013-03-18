module symbolTable;
import std.stdio, std.string, std.algorithm, std.conv, std.container, fcTokenizer;

bool toPrint = true;

class Entry {
	string symbol; //symbolic representation of the variable
	outerType oType; // outer type of the variable
	string type; // if a non-fC type (not used for now)
	string pType; // type and parametric type of the variable (name only)
	innerType currentIType;
	this(string symbol, outerType oType) {
		this.symbol = symbol;
		this.oType = oType;
		this.type = type;
	}
	this(string symbol, outerType oType, string pType) {
		this(symbol, oType); this.pType = pType;
	}
	string toStr() {
		return symbol ~ ": type " ~ oType.typeStr();
	}
}

// given a symbol, returns the appropriate vm code and type
class SymbolTable {
	Entry[string] table;
	void set(string symbol, outerType oType) {
		Entry ste = new Entry(symbol, oType);
		table[symbol] = ste;
	}
	void set(string symbol, outerType oType, string pType) {
		Entry ste = new Entry(symbol, oType, pType);
		table[symbol] = ste;
	}

	void set(string symbol, Entry ste) {
		table[symbol] = ste;
	}

	Entry get(string symbol) {
		if (!(symbol in table))
			return null;
		return table[symbol];
	}
	bool contains(string symbol) {
		if (symbol in table) return true;
		return false;
	}
	string toStr() {
		string ret = "";
		foreach(symbol; table.keys) {
			ret ~= table[symbol].toStr();
			ret ~= "\n";
		}
		return ret;
	}
}

struct SymbolTableStack {
	SymbolTableStackNode first;

	void push() {
		if (toPrint) writeln("*******************\nPushing a new SymbolTable\n*******************");
		SymbolTable st = new SymbolTable();
		push(st);
	}
	void push(SymbolTable st) {
		auto newFirst = new SymbolTableStackNode(st);
		newFirst.next = first;
		first = newFirst;
	}
	SymbolTable pop() {
		if (toPrint) writeln("*******************\nPopping a new SymbolTable\n*******************");
		SymbolTable toReturn = first.table;
		first = first.next;
		return toReturn;
	}
	string toString() {
		string res = "********Printing symbol table********\n";
		auto current = first;
		while (current !is null) {
			res ~= current.toStr() ~ "\n";
			current = current.next;
		}
		return res ~ "******** finished printing ********\n";
	}
	SymbolTableStackNode top() {
		return first;
	}
	Entry lookup(string symbol) {
		auto current = first;
		while (current !is null) {
			if (current.table.contains(symbol))
				return current.table.get(symbol);
			current = current.next;
		}
		return null;
	}
	void addSymbol(string symbol, outerType oType, string pType) {
		if (toPrint) writefln("adding %s: %s (auto = %s) to table", symbol, oType.typeStr(), pType);
		top().table.set(symbol, oType, pType);
	}

	void addSymbol(string symbol, outerType oType) {
		if (toPrint) writefln("adding %s: %s to table", symbol, oType.typeStr());
		top().table.set(symbol, oType);
	}
}

class SymbolTableStackNode {
	SymbolTable table;
	SymbolTableStackNode next = null;
	this(SymbolTable table) {
		this.table = table;
	}
	string toStr() {
		return table.toStr();
	}
}

class innerType {
	string type;
	string[][] vars;
	int num;
	this(string type, int typeNum) {
		writeln("Creating new inner type: ", type);
		this.type = type;
		this.num = typeNum;
	}
	void addParam(string type, string name) {
		writefln("Added parameter: %s %s", type, name);
		vars ~= [type, name];
	}
	override string toString() {
		string ret = "   " ~ type ~ ": ";
		foreach (var; vars) {
			ret ~= format("%s %s, ", var[0], var[1]);
		}
		return ret;
	}
	int numParams() {
		return to!int(vars.length);
	}
	string getType(string varName) {
		foreach(var; vars) {
			if (var[1] == varName)
				return var[0];
		}
		throw new Exception(format("No member called '%s' in type '%s'", varName, type));
	}
}

class outerType {
	string type;
	bool isParametric;
	innerType[] innerTypes;
	int num;
	this(string type, int typeNum) {
		writeln("Creating new outer type: ", type);
		this.type = type;
		this.num = typeNum;
	}
	innerType addInnerType(string type, int typeNum) {
		innerType it = new innerType(type, typeNum);
		innerTypes ~= it;
		return it;
	}
	override string toString() {
		string ret;
		if (isParametric)
			ret = "'" ~ type ~ "!" ~ "auto:\n";
		else
			ret = "'" ~ type ~ ":\n";
		foreach(iType; innerTypes) {
			ret ~= iType.toString() ~ "\n";
		}
		return ret ~ "'";
	}
	string typeStr() {
		string ret = type;
		if (isParametric) ret ~= "!auto";
		return ret;
	}
	innerType getInnerType(string typeName) {
		foreach (iType; innerTypes)
			if (iType.type == typeName)
				return iType;
		throw new Exception(format("Outer type %s does not have an inner type '%s'", 
									type, typeName));
	}
}