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

# Added '[' and ']' to delimiters
const DELIMITERS = [" ", ";", "{", "}", "(", ")", "[", "]", ",", "=", "+", "-", "*", "/", "<", ">", ":"]

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
	elif token == "switch":
		handle_switch()
	elif token == "break":
		handle_break()
	elif token == "continue":
		handle_continue()
	elif memory.has(token):
		# Variable logic
		if peek(1) == "=":
			handle_assignment()
		elif peek(1) == "[" and peek(2) != "=": # Array assignment check arr[0] = ...
			# We need to scan ahead to see if this is an assignment or just an expression start (which shouldn't be here on its own)
			# Assuming statement starts with var, it's assignment: arr[i] = val;
			handle_array_assignment()
		elif peek(1) == "+" and peek(2) == "+":
			handle_increment()
		else:
			current_index += 1
	elif token == "}" or token == ";" or token == "case" or token == "default" or token == ":":
		if token == "}": handle_block_end()
		else: current_index += 1
	else:
		if peek(1) == "(":
			current_index += 1
		else:
			print("Unknown token: ", token)
			current_index += 1

# --- ARRAY LOGIC ---

func handle_array_assignment():
	# Format: name [ index ] = value ;
	var var_name = tokens[current_index]
	current_index += 2 # Skip name and '['
	
	# Evaluate Index
	var idx_end = find_matching_token(current_index - 1, "[", "]") # -1 because we are at token AFTER [
	# Actually, easier to just find the next ']' if we assume simple structure, 
	# but find_matching is safer for arr[x+1]
	
	# We advanced current_index to start of index expression
	# Reset it slightly to use find_matching properly if we pass the opening bracket index?
	# My find_matching logic scans from start_index. 
	# Let's find the closing bracket relative to the opening one at (current_index - 1)
	idx_end = find_matching_token(current_index - 1, "[", "]")
	
	var idx_str = get_tokens_as_string(current_index, idx_end)
	var index_val = evaluate_expression(idx_str)
	
	current_index = idx_end + 1 # Skip ']'
	
	if tokens[current_index] != "=":
		print("Error: Expected '=' after array index")
		return
		
	current_index += 1 # Skip '='
	
	# Evaluate Value
	var expr_end = find_next_terminator()
	var expr_str = get_tokens_as_string(current_index, expr_end)
	var value = evaluate_expression(expr_str)
	
	# Apply
	if memory.has(var_name) and memory[var_name] is Array:
		var arr = memory[var_name]
		if index_val >= 0 and index_val < arr.size():
			arr[index_val] = value
			print("-> Array Update: ", var_name, "[", index_val, "] = ", value)
		else:
			print("Error: Array index out of bounds: ", index_val)
	else:
		print("Error: Variable is not an array: ", var_name)
		
	current_index = expr_end
	if current_index < tokens.size() and tokens[current_index] == ";":
		current_index += 1

# --- HANDLERS (Declaration Updated) ---

func handle_declaration():
	var type = tokens[current_index] 
	current_index += 1
	var var_name = tokens[current_index]
	current_index += 1
	
	# Check for Array Declaration: int arr[5];
	if tokens[current_index] == "[":
		current_index += 1 # Skip '['
		
		# Read size
		var size_end = find_next_token("]")
		var size_str = get_tokens_as_string(current_index, size_end)
		var size = 0
		if size_str != "":
			size = int(evaluate_expression(size_str))
			
		current_index = size_end + 1 # Skip ']'
		
		# Initialize Array
		var new_arr = []
		new_arr.resize(size)
		new_arr.fill(0)
		memory[var_name] = new_arr
		print("-> Declared Array: ", var_name, " size: ", size)
		
		# Check for immediate initialization? int arr[] = [1,2];
		if current_index < tokens.size() and tokens[current_index] == "=":
			# Handle assignment
			current_index += 1
			var expr_end = find_next_terminator()
			var expr_str = get_tokens_as_string(current_index, expr_end)
			var val = evaluate_expression(expr_str)
			if val is Array:
				memory[var_name] = val
				print("-> Array Initialized: ", val)
			current_index = expr_end
			
		if current_index < tokens.size() and tokens[current_index] == ";": current_index += 1
		return

	# Standard Declaration
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

# --- CONTROL FLOW (Existing) ---

func handle_if():
	current_index += 1
	if tokens[current_index] != "(": return
	var start = current_index
	var end = find_matching_token(start, "(", ")")
	if end == -1: return
	var res = evaluate_expression(get_tokens_as_string(start + 1, end))
	print("-> IF Check: ", res)
	last_if_result = (res == true)
	current_index = end + 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if res == true:
			control_stack.append({"type": "if"})
			current_index += 1
		else:
			skip_block()

func handle_else():
	current_index += 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if last_if_result == false:
			control_stack.append({"type": "else"})
			current_index += 1
		else:
			skip_block()

func handle_while():
	var start_idx = current_index
	current_index += 1
	if tokens[current_index] != "(": return
	var start = current_index
	var end = find_matching_token(start, "(", ")")
	var res = evaluate_expression(get_tokens_as_string(start + 1, end))
	print("-> WHILE Check: ", res)
	current_index = end + 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if res == true:
			control_stack.append({"type": "while", "return_to": start_idx})
			current_index += 1
		else:
			skip_block()

func handle_for():
	current_index += 1
	if tokens[current_index] != "(": return
	var header_open = current_index
	var header_close = find_matching_token(header_open, "(", ")")
	var s1 = -1
	var s2 = -1
	for i in range(header_open + 1, header_close):
		if tokens[i] == ";":
			if s1 == -1: s1 = i
			elif s2 == -1: s2 = i; break
	if s1 == -1 or s2 == -1: return

	# Init
	current_index = header_open + 1
	while current_index < s1:
		if tokens[current_index] in ["int", "float", "var"]: handle_declaration()
		elif memory.has(tokens[current_index]): handle_assignment()
		else: current_index += 1
	
	# Condition
	var cond_str = get_tokens_as_string(s1 + 1, s2)
	var res = evaluate_expression(cond_str)
	print("-> FOR Check: ", res)
	current_index = header_close + 1
	
	if current_index < tokens.size() and tokens[current_index] == "{":
		if res == true:
			control_stack.append({
				"type": "for",
				"condition_str": cond_str,
				"increment_start": s2 + 1,
				"increment_end": header_close,
				"body_start": current_index + 1
			})
			current_index += 1
		else:
			skip_block()

func handle_switch():
	current_index += 1
	if tokens[current_index] != "(": return
	var h_open = current_index
	var h_close = find_matching_token(h_open, "(", ")")
	var val = evaluate_expression(get_tokens_as_string(h_open + 1, h_close))
	print("-> SWITCH on: ", val)
	current_index = h_close + 1
	if tokens[current_index] != "{": return
	var block_end = find_matching_token(current_index, "{", "}")
	control_stack.append({"type": "switch", "end_index": block_end})
	var match_idx = -1
	var def_idx = -1
	var scan = current_index + 1
	while scan < block_end:
		if tokens[scan] == "case":
			var check = parse_value(tokens[scan + 1])
			if str(check) == str(val):
				match_idx = scan + 3
				break
			scan += 1
		elif tokens[scan] == "default":
			def_idx = scan + 2
			scan += 1
		elif tokens[scan] == "{":
			scan = find_matching_token(scan, "{", "}") + 1
		else: scan += 1
	if match_idx != -1: current_index = match_idx
	elif def_idx != -1: current_index = def_idx
	else:
		current_index = block_end + 1
		control_stack.pop_back()

func handle_break():
	print("-> BREAK")
	var stack_idx = control_stack.size() - 1
	while stack_idx >= 0:
		var ctx = control_stack[stack_idx]
		if ctx.type in ["while", "for"]:
			var depth = 0
			for i in range(current_index, tokens.size()):
				if tokens[i] == "{": depth += 1
				elif tokens[i] == "}":
					depth -= 1
					if depth < 0:
						current_index = i + 1
						control_stack.resize(stack_idx)
						return
			break
		elif ctx.type == "switch":
			current_index = ctx.end_index + 1
			control_stack.resize(stack_idx)
			return
		stack_idx -= 1
	current_index += 1

func handle_continue():
	print("-> CONTINUE")
	var stack_idx = control_stack.size() - 1
	while stack_idx >= 0:
		var ctx = control_stack[stack_idx]
		if ctx.type == "while":
			current_index = ctx.return_to
			control_stack.resize(stack_idx + 1)
			return
		elif ctx.type == "for":
			current_index = ctx.increment_start
			control_stack.resize(stack_idx + 1)
			return
		stack_idx -= 1
	current_index += 1

func handle_assignment():
	var var_name = tokens[current_index]
	current_index += 2
	var expr_end = find_next_terminator()
	var expr_str = get_tokens_as_string(current_index, expr_end)
	memory[var_name] = evaluate_expression(expr_str)
	current_index = expr_end
	if current_index < tokens.size() and tokens[current_index] == ";": current_index += 1
	print("-> Assigned: ", var_name, " = ", memory[var_name])

func handle_increment():
	var var_name = tokens[current_index]
	if memory.has(var_name):
		memory[var_name] += 1
		print("-> Incremented: ", var_name, " to ", memory[var_name])
	current_index += 3
	if current_index < tokens.size() and tokens[current_index] == ";": current_index += 1

func handle_block_end():
	if control_stack.is_empty():
		current_index += 1
		return
	var ctx = control_stack.pop_back()
	if ctx.type == "while":
		current_index = ctx.return_to
	elif ctx.type == "for":
		current_index = ctx.increment_start
		while current_index < ctx.increment_end:
			if memory.has(tokens[current_index]):
				if peek(1) == "=": handle_assignment()
				elif peek(1) == "+" and peek(2) == "+": handle_increment()
				else: current_index += 1
			else: current_index += 1
		var res = evaluate_expression(ctx.condition_str)
		print("-> FOR Loopback: ", res)
		if res == true:
			control_stack.append(ctx)
			current_index = ctx.body_start
		else:
			var body_end = find_matching_token(ctx.body_start - 1, "{", "}")
			current_index = body_end + 1
	else:
		current_index += 1

func skip_block():
	var idx = find_matching_token(current_index, "{", "}")
	if idx != -1: current_index = idx + 1
	else: print("Error: Missing closing '}'")

# --- HELPERS ---

func parse_value(token: String):
	if token.is_valid_int(): return token.to_int()
	elif token.is_valid_float(): return token.to_float()
	elif token == "true": return true
	elif token == "false": return false
	elif memory.has(token): return memory[token]
	return token

func evaluate_expression(math_string: String):
	var error = expression_module.parse(math_string, memory.keys())
	if error != OK: return null
	return expression_module.execute(memory.values(), self)

func find_matching_token(start_index: int, open_char: String, close_char: String) -> int:
	var depth = 0
	for i in range(start_index, tokens.size()):
		if tokens[i] == open_char: depth += 1
		elif tokens[i] == close_char:
			depth -= 1
			if depth == 0: return i
	return -1

func find_next_token(target: String) -> int:
	for i in range(current_index, tokens.size()):
		if tokens[i] == target: return i
	return tokens.size() 

func find_next_terminator() -> int:
	for i in range(current_index, tokens.size()):
		if tokens[i] == ";" or tokens[i] == ")": return i
	return tokens.size()

func get_tokens_as_string(from: int, to: int) -> String:
	var s = ""
	for i in range(from, to): s += tokens[i] + " " 
	return s

func peek(offset: int) -> String:
	if current_index + offset < tokens.size(): return tokens[current_index + offset]
	return ""

func _tokenize(source: String) -> Array[String]:
	var t: Array[String] = []
	var cur = ""
	for i in range(source.length()):
		var char = source[i]
		if char in DELIMITERS:
			if cur.strip_edges() != "":
				t.append(cur)
				cur = ""
			if char.strip_edges() != "": t.append(char)
		else: cur += char
	if cur.strip_edges() != "": t.append(cur)
	return t
