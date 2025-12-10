extends Node
class_name CodeInterpreter

signal log_message(text: String)
signal error_occurred(message: String)

var memory: Dictionary = {}
var tokens: Array[String] = []
var current_index: int = 0

# Nested scopes stack
var control_stack: Array[Dictionary] = []
var last_if_result: bool = false

var expression_module = Expression.new()

const DELIMITERS = [" ", ";", "{", "}", "(", ")", ",", "=", "+", "-", "*", "/", "<", ">"]

func run_code(raw_code: String):
	print("--- INTERPRETER START ---")
	memory.clear()
	control_stack.clear()
	last_if_result = false
	
	tokens = _tokenize(raw_code)
	current_index = 0
	
	print("Tokens: ", tokens)
	
	var safety_counter = 0
	var max_steps = 2000
	
	while current_index < tokens.size():
		execute_next_instruction()
		safety_counter += 1
		if safety_counter > max_steps:
			print("Error: Infinite loop detected or code too long.")
			break
	
	print("Final Memory: ", memory)

func execute_next_instruction():
	if current_index >= tokens.size(): return
	
	var token = tokens[current_index]
	
	if token in ["int", "float", "bool", "string", "var"]:
		handle_declaration()
	elif token == "if":
		handle_if()
	elif token == "else":
		handle_else()
	elif token == "while":
		handle_while()
	elif token == "for":
		handle_for()
	elif memory.has(token):
		# Variable found. Is it assignment (=) or increment (++)?
		if peek(1) == "=":
			handle_assignment()
		elif peek(1) == "+" and peek(2) == "+":
			handle_increment()
		else:
			current_index += 1
	elif token == "}" or token == ";":
		if token == "}": handle_block_end()
		else: current_index += 1
	else:
		if peek(1) == "(":
			current_index += 1
		else:
			print("Unknown token: ", token)
			current_index += 1

# --- CONTROL FLOW ---

func handle_if():
	current_index += 1
	if tokens[current_index] != "(":
		print("Error: Expected '(' after if")
		return
		
	var condition_start_idx = current_index
	var condition_end_idx = find_matching_token(current_index, "(", ")")
	
	if condition_end_idx == -1: return
		
	var condition_str = get_tokens_as_string(condition_start_idx + 1, condition_end_idx)
	var result = evaluate_expression(condition_str)
	
	print("-> IF Check: ", condition_str, " == ", result)
	last_if_result = (result == true)
	
	current_index = condition_end_idx + 1
	
	if current_index < tokens.size() and tokens[current_index] == "{":
		if result == true:
			control_stack.append({"type": "if"})
			current_index += 1
		else:
			skip_block()
	else:
		print("Error: Expected '{' after if condition")

func handle_else():
	current_index += 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if last_if_result == false:
			control_stack.append({"type": "else"})
			current_index += 1
		else:
			skip_block()
	else:
		print("Error: Expected '{' after else")

func handle_while():
	var loop_start_index = current_index
	current_index += 1
	
	if tokens[current_index] != "(": return
		
	var condition_start_idx = current_index
	var condition_end_idx = find_matching_token(current_index, "(", ")")
	
	var condition_str = get_tokens_as_string(condition_start_idx + 1, condition_end_idx)
	var result = evaluate_expression(condition_str)
	
	print("-> WHILE Check: ", condition_str, " == ", result)
	
	current_index = condition_end_idx + 1
	
	if current_index < tokens.size() and tokens[current_index] == "{":
		if result == true:
			control_stack.append({
				"type": "while", 
				"return_to": loop_start_index
			})
			current_index += 1
		else:
			skip_block()
	else:
		print("Error: Expected '{' after while condition")

func handle_for():
	# Format: for ( init ; condition ; increment ) { body }
	current_index += 1 # Skip 'for'
	
	if tokens[current_index] != "(":
		print("Error: Expected '(' after for")
		return
	
	# 1. Define Boundaries using matching parentheses
	var header_open_idx = current_index
	var header_close_idx = find_matching_token(header_open_idx, "(", ")")
	
	if header_close_idx == -1:
		print("Error: Malformed for loop header")
		return

	# 2. Find the two semicolons INSIDE the header
	var first_semi = -1
	var second_semi = -1
	
	for i in range(header_open_idx + 1, header_close_idx):
		if tokens[i] == ";":
			if first_semi == -1:
				first_semi = i
			elif second_semi == -1:
				second_semi = i
				break
	
	if first_semi == -1 or second_semi == -1:
		print("Error: For loop must have 3 parts separated by ';'")
		return

	# 3. RUN INIT (Once)
	# We temporarily move current_index to run the init code, then restore it
	current_index = header_open_idx + 1
	# Run until we hit the first semicolon
	while current_index < first_semi:
		if tokens[current_index] in ["int", "float", "var"]:
			handle_declaration()
		elif memory.has(tokens[current_index]):
			if peek(1) == "=":
				handle_assignment()
			elif peek(1) == "+" and peek(2) == "+":
				handle_increment()
			else:
				current_index += 1
		else:
			current_index += 1
			
	# 4. PREPARE LOOP CONTEXT
	var condition_str = get_tokens_as_string(first_semi + 1, second_semi)
	var result = evaluate_expression(condition_str)
	
	print("-> FOR Check: ", condition_str, " == ", result)
	
	# Move pointer to Body Start
	current_index = header_close_idx + 1
	
	if current_index < tokens.size() and tokens[current_index] == "{":
		if result == true:
			control_stack.append({
				"type": "for",
				"condition_str": condition_str, # Store string to re-eval later
				"increment_start": second_semi + 1,
				"increment_end": header_close_idx,
				"body_start": current_index + 1
			})
			current_index += 1
		else:
			skip_block()
	else:
		print("Error: Expected '{' after for loop header")

func handle_block_end():
	if control_stack.is_empty():
		current_index += 1
		return
		
	var context = control_stack.pop_back()
	
	if context.type == "while":
		current_index = context.return_to
		
	elif context.type == "for":
		# 1. Run Increment
		current_index = context.increment_start
		while current_index < context.increment_end:
			if memory.has(tokens[current_index]):
				if peek(1) == "=":
					handle_assignment()
				elif peek(1) == "+" and peek(2) == "+":
					handle_increment()
				else:
					current_index += 1
			else:
				current_index += 1
				
		# 2. Check Condition
		var result = evaluate_expression(context.condition_str)
		print("-> FOR Loopback Check: ", context.condition_str, " == ", result)
		
		if result == true:
			control_stack.append(context)
			current_index = context.body_start
		else:
			var body_end = find_matching_token(context.body_start - 1, "{", "}")
			current_index = body_end + 1
			
	else:
		current_index += 1

func skip_block():
	var block_end_idx = find_matching_token(current_index, "{", "}")
	if block_end_idx != -1:
		current_index = block_end_idx + 1
	else:
		print("Error: Missing closing '}' for block")

# --- HANDLERS ---

func handle_declaration():
	var type = tokens[current_index] 
	current_index += 1
	var var_name = tokens[current_index]
	current_index += 1
	
	if tokens[current_index] == "=":
		current_index += 1 
		var expr_end = find_next_terminator()
		var expr_str = get_tokens_as_string(current_index, expr_end)
		
		memory[var_name] = evaluate_expression(expr_str)
		current_index = expr_end
		if current_index < tokens.size() and tokens[current_index] == ";": current_index += 1
		
		print("-> Memory Update: ", var_name, " = ", memory[var_name])
	else:
		memory[var_name] = 0
		if current_index < tokens.size() and tokens[current_index] == ";": current_index += 1
		print("-> Declared: ", var_name)

func handle_assignment():
	var var_name = tokens[current_index]
	current_index += 2 # Skip name and '='
	
	var expr_end = find_next_terminator()
	var expr_str = get_tokens_as_string(current_index, expr_end)
	
	memory[var_name] = evaluate_expression(expr_str)
	
	current_index = expr_end
	if current_index < tokens.size() and tokens[current_index] == ";": 
		current_index += 1
		
	print("-> Assigned: ", var_name, " = ", memory[var_name])

func handle_increment():
	# Format: [i] [+] [+]
	var var_name = tokens[current_index]
	if memory.has(var_name):
		memory[var_name] += 1
		print("-> Incremented: ", var_name, " to ", memory[var_name])
	
	current_index += 3 # Skip name, +, +
	
	# Skip optional semicolon
	if current_index < tokens.size() and tokens[current_index] == ";":
		current_index += 1

# --- HELPERS ---

func evaluate_expression(math_string: String):
	var error = expression_module.parse(math_string, memory.keys())
	if error != OK:
		print("Expression Error: ", expression_module.get_error_text())
		return null
		
	var result = expression_module.execute(memory.values(), self)
	if expression_module.has_execute_failed():
		print("Execution Failed for: ", math_string)
		return null
		
	return result

func find_matching_token(start_index: int, open_char: String, close_char: String) -> int:
	var depth = 0
	for i in range(start_index, tokens.size()):
		if tokens[i] == open_char:
			depth += 1
		elif tokens[i] == close_char:
			depth -= 1
			if depth == 0:
				return i
	return -1

# Helper to find ; OR ) depending on if we are in a loop header
func find_next_terminator() -> int:
	for i in range(current_index, tokens.size()):
		if tokens[i] == ";" or tokens[i] == ")":
			return i
	return tokens.size()

func get_tokens_as_string(from: int, to: int) -> String:
	var s = ""
	for i in range(from, to):
		s += tokens[i] + " " 
	return s

func peek(offset: int) -> String:
	if current_index + offset < tokens.size():
		return tokens[current_index + offset]
	return ""

func _tokenize(source: String) -> Array[String]:
	var t: Array[String] = []
	var current_token = ""
	
	for i in range(source.length()):
		var char = source[i]
		if char in DELIMITERS:
			if current_token.strip_edges() != "":
				t.append(current_token)
				current_token = ""
			if char.strip_edges() != "":
				t.append(char)
		else:
			current_token += char
			
	if current_token.strip_edges() != "":
		t.append(current_token)
	return t
