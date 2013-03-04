module cTokenizer;
import std.stdio, std.string, std.conv, std.algorithm;

enum TokenCat {
	KW, SYM, INTCONST, STRCONST, IDENT, WS, CHARCONST, PARTIALCHAR,
	NONE, PARTIALSTRING, COMMENT, PARTIALCOMMENT, PREPDIRECTIVE,
	PARTIALPREPDIRECTIVE
}

struct Token {
	string symbol;
	TokenCat category;
	string type;
	int val;
	string str;
	static string[TokenCat] descriptions;
	this(string sym, TokenCat cat) { // Token struct initializer
		descriptions = [TokenCat.KW:"keyword", 
				TokenCat.IDENT:"identifier", TokenCat.SYM:"symbol", TokenCat.CHARCONST:"charConstant",
				TokenCat.INTCONST:"integerConstant", TokenCat.STRCONST:"stringConstant",
				TokenCat.PREPDIRECTIVE:"preprocessorDirective"];
		symbol = sym;
		category = cat;
		if (cat == TokenCat.INTCONST) {
			val = to!int(sym);
			type = "integerConstant";
		} else if (cat == TokenCat.STRCONST) {
			str = sym[1..$-1];
			type = "stringConstant";
		} else if (cat == TokenCat.IDENT) {
			type = "identifier";
		} else {
			type = symbol;
		}
	}

	string getXML() {
		if (category == TokenCat.STRCONST)
			return format("<%s> %s </%s>\r\n", descriptions[category], str, descriptions[category]);
		if (category == TokenCat.INTCONST)
			return format("<%s> %s </%s>\r\n", descriptions[category], val, descriptions[category]);
		if (symbol == "<")
			return format("<%s> &lt; </%s>\r\n", descriptions[category], descriptions[category]);
		if (symbol == ">")
			return format("<%s> &gt; </%s>\r\n", descriptions[category], descriptions[category]);
		if (symbol == "&")
			return format("<%s> &amp; </%s>\r\n", descriptions[category], descriptions[category]);
		return format("<%s> %s </%s>\r\n", descriptions[category], symbol, descriptions[category]);
	}

	string toString() {
		return symbol ~ " (" ~ type ~ ")";
	}
}

struct cTokenizer {
	int[string] keywords, symbols, prepDirectives;
	int[char] identFirstChar, identOtherChars, numbers;
	int lineNumber, indentAmount;
	string preparedCode;
	Token[] tokens;

	void init() {
		string[] keywordList = ["static", "int", "char", "boolean", "void", "true", "false", 
								"if", "else", "while", "for", "switch", "return", "auto", "break", 
								"case", "const", "continue", "default", "do", "double", "enum", "extern", 
								"float", "goto", "long", "register", "short", "signed", "sizeof", "struct",
								"switch", "typedef", "union", "unsigned", "volatile",
								"data", "match"];
		foreach (kw; keywordList) { keywords[kw] = 0; }

		string[] symbolList = ["...", ">>=", "<<=", "+=", "-=", "*=", "/=", "%=", "&=", "^=",
								"|=", ">>", "<<", "++", "--", "->", "&&", "||", "<=", ">=", "==", "!=", ";",
								"{","<%", "}","%>", ",", ":", "=", "(", ")","[","<:", "]",":>",
								".", "&", "!", "~", "-", "+", "*", "/", "%", "<", ">", "^", "|", "?",
								"=>", ".."];
		foreach (sym; symbolList) { symbols[sym] = 0; }

		string[] prepDirectiveList = ["#define", "#error", "#import", "#undef", "#elif", "#if", "#include",
									  "#using", "#else", "#ifdef", "#line", "#endif", "#ifndef", "#pragma"];
		foreach (sym; prepDirectiveList) { prepDirectives[sym] = 0; }
		
		string lowerCase = "abcdefghijklmnopqrstuvwxyz_";
		string upperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		string digits = "0123456789";
		foreach (ch; lowerCase ~ upperCase)
			identFirstChar[ch] = 0;
		foreach (ch; lowerCase ~ upperCase ~ digits)
			identOtherChars[ch] = 0;
		foreach (ch; digits)
			numbers[ch] = 0;
	}

	bool matchPartialPrepDirective(string str) {
		if (str[0] != '#') return false;
		foreach(ch; str)
			if (matchWhiteSpace(to!string(ch))) return false;
		return true;
	}

	bool matchIdent(string str) {
		if (!str) return false;
		if (!(str[0] in identFirstChar)) { return false; }
		for (int i=1; i<str.length; ++i)
			if (!(str[i] in identOtherChars)) { return false; }
		return true;
	}

	bool matchNum(string str) {
		if (!str) return false;
		for (int i=0; i<str.length; ++i)
			if (!(str[i] in numbers)) { return false; }
		return true;
	}

	bool matchPartialCharConstant(string str) {
		return (str.length < 3 && str[0] == '\'');
	}
	bool matchCharConstant(string str) {
		return (str.length == 3 && str[0] == '\'' && str[$-1] == '\'');
	}

	bool matchWhiteSpace(string str) {
		foreach(ch; str)
			if (ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t')
				return false;
		return true;
	}


	TokenCat bestMatch(string token) {
		if (token in keywords)
			return TokenCat.KW;
		else if (token in symbols)
			return TokenCat.SYM;
		else if (matchNum(token))
			return TokenCat.INTCONST;
		else if (token[0] == '"' && token[$-1] == '"')
			return TokenCat.STRCONST;
		else if (token[0] == '"' && !canFind(token[1..$-1], '"'))
			return TokenCat.PARTIALSTRING; // this will never be a terminal type
		else if (matchIdent(token))
			return TokenCat.IDENT;
		else if (matchCharConstant(token))
			return TokenCat.CHARCONST;
		else if (matchPartialCharConstant(token))
			return TokenCat.PARTIALCHAR;
		else if (token in prepDirectives)
			return TokenCat.PREPDIRECTIVE;
		else if (matchPartialPrepDirective(token))
			return TokenCat.PARTIALPREPDIRECTIVE;
		else if (token.length >= 4 && token[0..2] == "/*" && token[$-2..$] == "*/")
			return TokenCat.COMMENT;
		else if (token.length >= 2 && token[0..2] == "/*" && token.split("*/")[0] == token)
			return TokenCat.PARTIALCOMMENT;
		else if (matchWhiteSpace(token))
			return TokenCat.WS;
		else
			return TokenCat.NONE;
	}

	void lex() {
		lex(preparedCode);
	}

	void lex(string line) {
		write("Tokenizer lexing...");
		tokens = [];
		int cursor; // keeps track of our position in the line
		writeln("Input:\r\n", line);
		string current = "", prev = "";
		TokenCat bestCat = TokenCat.NONE;
		for (cursor = 0; cursor < line.length; ++cursor) {
			char c = line[cursor];
			current ~= c; // append next character onto our working token
			if (bestMatch(current) == TokenCat.NONE) { // then we've encountered an illegal expression
				if (prev == "") // this would mean we started off with something illegal
					throw new Exception(format("Error: illegal input on line %s: %s", lineNumber, current));
				if (matchPartialCharConstant(prev))
					throw new Exception(format("Error line %s: char input %s is malformed 
						 					   (only one character is allowed between two '')", lineNumber, prev));
				if (bestCat != TokenCat.WS && bestCat != TokenCat.COMMENT) // skip whitespaces & comments
					tokens ~= Token(prev, bestCat);
				current = to!string(c); // start new partial token with just c
				prev = "";
			}
			bestCat = bestMatch(current);
			prev = current;
		}
		// we'll have one character left over, so process it:
		bestCat = bestMatch(current);
		if (bestCat != TokenCat.WS && bestCat != TokenCat.NONE)
			if (bestCat == TokenCat.PARTIALSTRING)
				throw new Exception("Error: unbounded string constant.");
			else if (bestCat == TokenCat.PARTIALCOMMENT)
				throw new Exception("Error: unbounded comment.");
			else
				tokens ~= Token(prev, bestCat);
		writeln("done lexing");
	}

	void prepare(string filename) {
		write("jackTokenizer preparing ", filename, "... ");
		string noComments;
		auto file = File(filename, "r");
		foreach (line; file.byLine) {
			string[] lines = to!string(line).split("//");
			if (lines.length > 0) {
				string strippedLine = to!string(line).split("//")[0];
				if (strippedLine != "")
					noComments ~= strippedLine ~ "\r\n";
			}
		}
		preparedCode = noComments;
		file.close();
		writeln("done");
	}

	void writeTokens(string filename) {
		write("jackTokenizer writing tokens to ", filename, "... ");
		auto file = File(filename, "w");
		file.write("<tokens>\r\n");
		foreach (token; tokens)
			file.write(token.getXML());
		file.writeln("</tokens>\r\n");
		file.close();
		writeln("done");
	}

	void prepareLexWrite(string inputFilename, string outputFilename) {
		prepare(inputFilename);
		lex();
		writeTokens(outputFilename);
	}

	Token[] getTokens() {
		writeln("Tokens: ", tokens);
		return tokens;
	}
}

void main(string args[]) {
	if (args.length < 3) {
		writefln("usage: %s <c input file)> <xml output file>", args[0]);
		return;
	}
	cTokenizer t;
	t.init();
	t.prepareLexWrite(args[1], args[2]);
}