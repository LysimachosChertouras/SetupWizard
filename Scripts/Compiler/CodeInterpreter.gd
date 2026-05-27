extends Node
class_name CodeInterpreter

signal log_message(text: String)
signal error_occurred(message: String)
signal memory_updated(current_memory: Dictionary) # For UI/Memory Inspector
signal action_triggered(function_name: String, args: Array)
signal step_started(token_index: int)
signal execution_finished

# Dedicated signal to resume the async loop after a physical action
signal resume_requested

@export var step_delay: float = 0.3
## Drag your Wizard/Apprentice node here in the Inspector
@export var apprentice: Node2D

const TILE_SIZE = 32
## These variables can be READ in code, but will throw an error if written to
const READ_ONLY_VARS = ["apprentice_x", "apprentice_y", "is_blocked"]

var memory: Dictionary = {}
var variable_types: Dictionary = {} # Track 'int', 'float', 'bool' for C-style behavior
var tokens: Array[String] = []
var current_index: int = 0
var control_stack: Array[Dictionary] = []
var last_if_result: bool = false

var expression_module = Expression.new()
var _waiting_for_action: bool = false
var _abort_execution: bool = false

const MULTI_DELIMS = ["<=", ">=", "==", "!=", "&&", "||", "++", "--", "+=", "-="]
const DELIMITERS = [" ", ";", "{", "}", "(", ")", "[", "]", ",", "=", "+", "-", "*", "/", "<", ">", ":", "!", "%"]

## run_code is an async function to allow the "Glow" and physical animations to pause execution
func run_code(raw_code: String):
	memory.clear()
	variable_types.clear()
	control_stack.clear()
	last_if_result = false
	tokens = _tokenize(raw_code)
	current_index = 0
	_waiting_for_action = false
	_abort_execution = false
	
	var safety_counter = 0
	while current_index < tokens.size() and not _abort_execution:
		step_started.emit(current_index)
		
		if step_delay > 0:
			await get_tree().create_timer(step_delay).timeout
		
		if _abort_execution: break
		
		execute_next_instruction()
		
		if _waiting_for_action and not _abort_execution:
			await self.resume_requested
		
		safety_counter += 1
		if safety_counter > 2000:
			error_occurred.emit("Infinite loop detected.")
			break
			
	execution_finished.emit()

## Stops execution (e.g., on collision or syntax error)
func stop():
	_abort_execution = true
	if _waiting_for_action:
		resume_execution()

## Called by ChallengeManager when the Apprentice finishes moving
func resume_execution():
	_waiting_for_action = false
	resume_requested.emit()

func execute_next_instruction():
	if current_index >= tokens.size(): return
	var token = tokens[current_index]
	
	# Type Declarations
	if token in ["int", "float", "bool", "string", "var"]:
		handle_declaration()
	# Unary Prefix (++x, --x)
	elif token == "++" or token == "--":
		handle_unary_op(true)
	# Control Flow
	elif token == "if": handle_if()
	elif token == "else": handle_else()
	elif token == "while": handle_while()
	elif token == "for": handle_for()
	elif token == "switch": handle_switch()
	elif token == "break": handle_break()
	elif token == "continue": handle_continue()
	# Variables & Postfix (Including Read-Only Sensor access)
	elif memory.has(token) or token in READ_ONLY_VARS:
		if peek(1) == "=":
			handle_assignment()
		elif peek(1) == "[" and peek(2) != "=":
			handle_array_assignment()
		elif peek(1) == "++" or peek(1) == "--":
			handle_unary_op(false)
		else:
			current_index += 1
	# Block terminators & Structural symbols
	elif token == "}" or token == ";" or token == "case" or token == "default" or token == ":":
		if token == "}": handle_block_end()
		else: current_index += 1
	# Functions
	else:
		if peek(1) == "(":
			handle_function_call()
		else:
			current_index += 1

# --- INTERNAL SENSORS ---

## Blends current script memory with live physical world data
func _get_live_memory() -> Dictionary:
	var live_mem = memory.duplicate()
	if apprentice:
		live_mem["apprentice_x"] = int(apprentice.global_position.x / TILE_SIZE)
		live_mem["apprentice_y"] = int(apprentice.global_position.y / TILE_SIZE)
		if apprentice.has_node("RayCast2D"):
			live_mem["is_blocked"] = apprentice.get_node("RayCast2D").is_colliding()
	return live_mem

# --- SYNTAX ENFORCEMENT ---

func _consume_semicolon(context: String):
	if _abort_execution: return
	if current_index < tokens.size() and tokens[current_index] == ";":
		current_index += 1
		return
	error_occurred.emit("Syntax Error: Missing ';' after " + context)
	stop()

# --- HANDLERS ---

func handle_unary_op(is_prefix: bool):
	var op = ""
	var var_name = ""
	
	if is_prefix:
		op = tokens[current_index]
		current_index += 1
		var_name = tokens[current_index]
		current_index += 1
	else:
		var_name = tokens[current_index]
		current_index += 1
		op = tokens[current_index]
		current_index += 1
		
	if var_name in READ_ONLY_VARS:
		error_occurred.emit("Runtime Error: Cannot modify read-only variable '" + var_name + "'")
		stop()
		return
		
	if not memory.has(var_name):
		error_occurred.emit("Runtime Error: Undefined variable '" + var_name + "'")
		stop()
		return
		
	if op == "++":
		memory[var_name] += 1
	elif op == "--":
		memory[var_name] -= 1
		
	if variable_types.get(var_name) == "int":
		memory[var_name] = int(memory[var_name])
		
	memory_updated.emit(_get_live_memory())
	_consume_semicolon("unary operation on '" + var_name + "'")

func handle_function_call():
	var func_name = tokens[current_index]
	current_index += 2 # Skip name and (
	
	var args = []
	if current_index < tokens.size() and tokens[current_index] != ")":
		while current_index < tokens.size():
			var arg_end = _find_argument_end()
			
			if arg_end >= tokens.size() and (current_index >= tokens.size() or tokens[clamp(arg_end - 1, 0, tokens.size() - 1)] != ")"):
				error_occurred.emit("Syntax Error: Missing ')' in call to " + func_name)
				stop()
				return
				
			var expr_str = get_tokens_as_string(current_index, arg_end)
			args.append(evaluate_expression(expr_str))
			current_index = arg_end
			
			if current_index < tokens.size():
				if tokens[current_index] == ")":
					current_index += 1
					break
				elif tokens[current_index] == ",":
					current_index += 1
			else:
				error_occurred.emit("Syntax Error: Unexpected end of code in function arguments.")
				stop()
				break

	if _abort_execution: return

	if func_name == "print":
		log_message.emit(str(args))
	else:
		if func_name in ["move", "turn_left", "turn_right"]:
			_waiting_for_action = true
		action_triggered.emit(func_name, args)
	
	_consume_semicolon("function call '" + func_name + "()'")

func _find_argument_end() -> int:
	var depth = 0
	for i in range(current_index, tokens.size()):
		if tokens[i] == "(": depth += 1
		elif tokens[i] == ")":
			if depth == 0: return i
			depth -= 1
		elif tokens[i] == ",":
			if depth == 0: return i
	return tokens.size()

func handle_array_assignment():
	if current_index + 2 >= tokens.size(): return
	var var_name = tokens[current_index]
	
	if var_name in READ_ONLY_VARS:
		error_occurred.emit("C-04: Permission Denied. '" + var_name + "' is Read-Only.")
		stop(); return

	current_index += 2
	var idx_end = find_matching_token(current_index - 1, "[", "]")
	if idx_end == -1: return
	
	var idx_str = get_tokens_as_string(current_index, idx_end)
	var index_val = evaluate_expression(idx_str)
	current_index = idx_end + 1
	
	if current_index < tokens.size() and tokens[current_index] == "=":
		current_index += 1
		var expr_end = find_next_token(";")
		var expr_str = get_tokens_as_string(current_index, expr_end)
		var value = evaluate_expression(expr_str)
		
		if variable_types.get(var_name) == "int" and value is float:
			value = int(value)
			
		if memory.has(var_name) and memory[var_name] is Array:
			var arr = memory[var_name]
			if index_val != null and index_val >= 0 and index_val < arr.size():
				arr[index_val] = value
		current_index = expr_end
		
	memory_updated.emit(_get_live_memory())
	_consume_semicolon("array assignment '" + var_name + "[]'")

func handle_declaration():
	if current_index + 1 >= tokens.size(): return
	var type = tokens[current_index]
	current_index += 1
	var var_name = tokens[current_index]
	current_index += 1
	
	if var_name in READ_ONLY_VARS:
		error_occurred.emit("Syntax Error: Cannot shadow reserved name '" + var_name + "'")
		stop(); return
	
	variable_types[var_name] = type

	# Array declaration: int arr[5]
	if current_index < tokens.size() and tokens[current_index] == "[":
		current_index += 1
		var size_end = find_next_token("]")
		if size_end >= tokens.size():
			error_occurred.emit("Syntax Error: Missing ']' in array declaration.")
			stop(); return
			
		var size = int(evaluate_expression(get_tokens_as_string(current_index, size_end)))
		current_index = size_end + 1
		var new_arr = []; new_arr.resize(size); new_arr.fill(0)
		memory[var_name] = new_arr
		
		if current_index < tokens.size() and tokens[current_index] == "=":
			current_index += 1
			var expr_end = find_next_token(";")
			var val = evaluate_expression(get_tokens_as_string(current_index, expr_end))
			if val is Array: memory[var_name] = val
			current_index = expr_end
		
		memory_updated.emit(_get_live_memory())
		_consume_semicolon("array declaration '" + var_name + "[]'")
		return

	# Standard assignment: int x = 5
	if current_index < tokens.size() and tokens[current_index] == "=":
		current_index += 1
		var expr_end = find_next_token(";")
		var result = evaluate_expression(get_tokens_as_string(current_index, expr_end))
		if type == "int" and result is float: result = int(result)
		memory[var_name] = result
		current_index = expr_end
	else:
		memory[var_name] = 0
		
	memory_updated.emit(_get_live_memory())
	_consume_semicolon("variable declaration '" + var_name + "'")

func handle_if():
	current_index += 1
	var end = find_matching_token(current_index, "(", ")")
	if end == -1: return
	
	var res = evaluate_expression(get_tokens_as_string(current_index + 1, end))
	last_if_result = (res == true)
	current_index = end + 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if res:
			control_stack.append({"type": "if"})
			current_index += 1
		else: skip_block()

func handle_else():
	current_index += 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if not last_if_result:
			control_stack.append({"type": "else"})
			current_index += 1
		else: skip_block()

func handle_while():
	var start_idx = current_index
	current_index += 1
	var end = find_matching_token(current_index, "(", ")")
	if end == -1: return
	
	var res = evaluate_expression(get_tokens_as_string(current_index + 1, end))
	current_index = end + 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if res:
			control_stack.append({"type": "while", "return_to": start_idx})
			current_index += 1
		else: skip_block()

func handle_for():
	current_index += 1
	var h_open = current_index
	var h_close = find_matching_token(h_open, "(", ")")
	if h_close == -1: return
	
	var s1 = -1; var s2 = -1
	for i in range(h_open + 1, h_close):
		if tokens[i] == ";":
			if s1 == -1: s1 = i
			else: s2 = i; break
			
	if s1 == -1 or s2 == -1:
		error_occurred.emit("Syntax Error: Invalid 'for' loop header. Expected (init; cond; inc)")
		stop(); return

	current_index = h_open + 1
	while current_index < s1:
		var token = tokens[current_index]
		if token in ["int", "float", "var"]:
			current_index += 2
			if tokens[current_index] == "=":
				current_index += 1
				var var_name = tokens[current_index - 2]
				var val = evaluate_expression(get_tokens_as_string(current_index, s1))
				variable_types[var_name] = token
				if token == "int" and val is float: val = int(val)
				memory[var_name] = val
			current_index = s1
		else: current_index += 1
	
	current_index = s1 + 1
	var cond_str = get_tokens_as_string(current_index, s2)
	var res = evaluate_expression(cond_str)
	
	current_index = h_close + 1
	if current_index < tokens.size() and tokens[current_index] == "{":
		if res:
			control_stack.append({"type": "for", "condition_str": cond_str, "increment_start": s2 + 1, "increment_end": h_close, "body_start": current_index + 1})
			current_index += 1
		else: skip_block()

func handle_switch():
	current_index += 1
	if current_index >= tokens.size() or tokens[current_index] != "(": return
	var h_open = current_index
	var h_close = find_matching_token(h_open, "(", ")")
	if h_close == -1: return
	
	var val = evaluate_expression(get_tokens_as_string(h_open + 1, h_close))
	current_index = h_close + 1
	if current_index >= tokens.size() or tokens[current_index] != "{": return
	
	var block_end = find_matching_token(current_index, "{", "}")
	if block_end == -1: return
	
	control_stack.append({"type": "switch", "end_index": block_end})
	var match_idx = -1; var def_idx = -1; var scan = current_index + 1
	while scan < block_end:
		if tokens[scan] == "case":
			if scan + 1 < tokens.size():
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
		
	if match_idx != -1 and match_idx < tokens.size(): current_index = match_idx
	elif def_idx != -1 and def_idx < tokens.size(): current_index = def_idx
	else:
		current_index = block_end + 1
		control_stack.pop_back()

func handle_break():
	var stack_idx = control_stack.size() - 1
	var found_ctx = false
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
						found_ctx = true; break
			if found_ctx: break
		elif ctx.type == "switch":
			current_index = ctx.end_index + 1
			control_stack.resize(stack_idx)
			found_ctx = true; break
		stack_idx -= 1
	if not found_ctx: current_index += 1
	_consume_semicolon("keyword 'break'")

func handle_continue():
	var stack_idx = control_stack.size() - 1
	var found_ctx = false
	while stack_idx >= 0:
		var ctx = control_stack[stack_idx]
		if ctx.type == "while":
			current_index = ctx.return_to
			control_stack.resize(stack_idx + 1)
			found_ctx = true; break
		elif ctx.type == "for":
			current_index = ctx.increment_start
			control_stack.resize(stack_idx + 1)
			found_ctx = true; break
		stack_idx -= 1
	if not found_ctx: current_index += 1
	_consume_semicolon("keyword 'continue'")

func handle_assignment():
	var var_name = tokens[current_index]
	
	if var_name in READ_ONLY_VARS:
		error_occurred.emit("C-04: Permission Denied. '" + var_name + "' is Read-Only.")
		stop(); return

	current_index += 2
	var expr_end = find_next_token(";")
	var result = evaluate_expression(get_tokens_as_string(current_index, expr_end))
	
	if variable_types.get(var_name) == "int" and result is float:
		result = int(result)
		
	memory[var_name] = result
	memory_updated.emit(_get_live_memory())
	current_index = expr_end
	_consume_semicolon("assignment to '" + var_name + "'")

func handle_block_end():
	if control_stack.is_empty():
		current_index += 1
		return
	var ctx = control_stack.pop_back()
	if ctx.type == "while": current_index = ctx.return_to
	elif ctx.type == "for":
		current_index = ctx.increment_start
		while current_index < ctx.increment_end:
			var t = tokens[current_index]
			if t == "++" or t == "--":
				var next = peek(1)
				if memory.has(next) and not next in READ_ONLY_VARS:
					if t == "++": memory[next] += 1
					else: memory[next] -= 1
					if variable_types.get(next) == "int": memory[next] = int(memory[next])
				current_index += 2
			elif memory.has(t) and not t in READ_ONLY_VARS:
				var op = peek(1)
				if op == "++": memory[t] += 1
				elif op == "--": memory[t] -= 1
				if variable_types.get(t) == "int": memory[t] = int(memory[t])
				current_index += 2
			else: current_index += 1
		
		if evaluate_expression(ctx.condition_str):
			control_stack.append(ctx)
			current_index = ctx.body_start
		else:
			var b_end = find_matching_token(ctx.body_start - 1, "{", "}")
			if b_end != -1: current_index = b_end + 1
			else: current_index = tokens.size()
	else: current_index += 1

func skip_block():
	var idx = find_matching_token(current_index, "{", "}")
	if idx != -1: current_index = idx + 1

func parse_value(token: String):
	if token.is_valid_int(): return token.to_int()
	elif token.is_valid_float(): return token.to_float()
	elif token == "true": return true
	elif token == "false": return false
	elif token in READ_ONLY_VARS: return _get_live_memory()[token]
	elif memory.has(token): return memory[token]
	return token

func evaluate_expression(math_string: String):
	var live_mem = _get_live_memory()
	if expression_module.parse(math_string, live_mem.keys()) != OK:
		return null
	var result = expression_module.execute(live_mem.values(), self )
	if expression_module.has_execute_failed():
		return null
	return result

func find_matching_token(start: int, open: String, close: String) -> int:
	var depth = 0
	for i in range(start, tokens.size()):
		if tokens[i] == open: depth += 1
		elif tokens[i] == close:
			depth -= 1
			if depth == 0: return i
	error_occurred.emit("Syntax Error: Missing closing '" + close + "'.")
	stop(); return -1

func find_next_token(target: String) -> int:
	for i in range(current_index, tokens.size()):
		if tokens[i] == target: return i
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
	var i = 0
	var cur = ""
	while i < source.length():
		var character = source[i]
		if i + 1 < source.length():
			var pair = character + source[i + 1]
			if pair in MULTI_DELIMS:
				if cur.strip_edges() != "": t.append(cur)
				t.append(pair); cur = ""; i += 2; continue
		if character in DELIMITERS:
			if cur.strip_edges() != "": t.append(cur); cur = ""
			if character.strip_edges() != "": t.append(character)
		else: cur += character

		i += 1
	if cur.strip_edges() != "": t.append(cur)
	return t
