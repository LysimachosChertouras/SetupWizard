extends Resource
class_name TokenData

# What kind of block is this? 
enum Type { KEYWORD, VALUE, SYMBOL, FUNCTION, VARIABLE }

@export_group("Data")
@export var type: Type = Type.KEYWORD
@export var display_text: String = "text"   # What the player sees
@export var code_string: String = "if"      # What the compiler reads

@export_group("Visuals")
@export var block_color: Color = Color("444444") 
@export var width_units: int = 1 

@export_group("Behavior")
@export var is_writable: bool = false # NEW: Allows typing into this block
