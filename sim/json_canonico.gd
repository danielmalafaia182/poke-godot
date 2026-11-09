extends RefCounted
## Serialização JSON determinística: mantém a ordem de inserção das chaves (igual à do servidor),
## escreve inteiros sem ".0" e floats na menor forma que volta ao mesmo valor (como Python/JS).
## Mesma entrada → mesmos bytes.


static func texto(v: Variant) -> String:
	var partes := PackedStringArray()
	_escrever(v, partes)
	return "".join(partes)


static func _escrever(v: Variant, out: PackedStringArray) -> void:
	match typeof(v):
		TYPE_NIL:
			out.append("null")
		TYPE_BOOL:
			out.append("true" if v else "false")
		TYPE_INT:
			out.append(str(v))
		TYPE_FLOAT:
			out.append(numero(v))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(_aspas(String(v)))
		TYPE_DICTIONARY:
			out.append("{")
			var primeiro := true
			for k in v:
				if not primeiro:
					out.append(", ")
				primeiro = false
				out.append(_aspas(str(k)))
				out.append(": ")
				_escrever(v[k], out)
			out.append("}")
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			out.append("[")
			var i := 0
			for item in v:
				if i > 0:
					out.append(", ")
				_escrever(item, out)
				i += 1
			out.append("]")
		_:
			out.append(_aspas(str(v)))


static func numero(f: float) -> String:
	if is_nan(f) or is_inf(f):
		return "null"
	if f == floor(f) and absf(f) < 1e15:
		return str(int(f))
	for casas in range(1, 18):
		var s := String.num(f, casas)
		if s.to_float() == f:
			return s
	return String.num(f, 17)


static func _aspas(s: String) -> String:
	var r := s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
	return "\"" + r + "\""
