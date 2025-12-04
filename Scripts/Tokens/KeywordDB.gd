extends Node

# VS Code Style Colors
const COLOR_CONTROL = Color("ff8ccc") # Pink (if, for, while, return)
const COLOR_TYPE = Color("ff7084")    # Red (int, bool, func, var)
const COLOR_DEFAULT = Color("bcbaba") # Light Grey (Default text)
const COLOR_SYMBOL = Color("abc9ff") #  Sky Blue ({, (, =, <,)

# The Dictionary
var registry = {
	"if": COLOR_CONTROL,
	"else": COLOR_CONTROL,
	"for": COLOR_CONTROL,
	"while": COLOR_CONTROL,
	"return": COLOR_CONTROL,
	
	"int": COLOR_TYPE,
	"bool": COLOR_TYPE,
	"string": COLOR_TYPE,
	"float": COLOR_TYPE,
	"func": COLOR_TYPE,
	"var": COLOR_TYPE,
	"void": COLOR_TYPE,
	
	"}": COLOR_SYMBOL,
	"{": COLOR_SYMBOL,
	"(": COLOR_SYMBOL,
	")": COLOR_SYMBOL,
	"<": COLOR_SYMBOL,
	">": COLOR_SYMBOL,
	"=": COLOR_SYMBOL,
	"+": COLOR_SYMBOL,
	"-": COLOR_SYMBOL,
	"*": COLOR_SYMBOL,
	"&": COLOR_SYMBOL,
	"^": COLOR_SYMBOL,
	"%": COLOR_SYMBOL,
	
}


func get_keyword_color(word: String) -> Color:
	# Returns the specific color if found, otherwise returns default
	return registry.get(word, COLOR_DEFAULT)

func is_keyword(word: String) -> bool:
	return word in registry
