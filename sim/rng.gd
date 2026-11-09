extends RefCounted
## Gerador pseudoaleatório determinístico (xoshiro128**), só com inteiros de 32 bits mascarados.
## Não depende do RandomNumberGenerator do Godot: a mesma semente dá a mesma sequência em qualquer versão/plataforma.
## `randf()` imita `Math.random()` do cliente original: [0, 1) com 32 bits.

const M32 := 0xFFFFFFFF

var _s := PackedInt64Array([0, 0, 0, 0])
var chamadas: int = 0


func _init(semente: int = 1) -> void:
	semear(semente)


static func _mul32(a: int, b: int) -> int:
	# (a * b) mod 2^32 sem estourar int64.
	a &= M32
	b &= M32
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & M32


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & M32


func semear(semente: int) -> void:
	# splitmix32 sobre a semente (64 bits divididos em duas metades) para preencher o estado.
	var x := (semente ^ (semente >> 32)) & M32
	for i in 4:
		x = (x + 0x9E3779B9) & M32
		var z := x
		z = _mul32(z ^ (z >> 16), 0x85EBCA6B)
		z = _mul32(z ^ (z >> 13), 0xC2B2AE35)
		z = (z ^ (z >> 16)) & M32
		_s[i] = z
	if _s[0] == 0 and _s[1] == 0 and _s[2] == 0 and _s[3] == 0:
		_s[0] = 1
	chamadas = 0


func proximo_u32() -> int:
	var s0 := _s[0]
	var s1 := _s[1]
	var s2 := _s[2]
	var s3 := _s[3]
	var resultado := (_rotl((s1 * 5) & M32, 7) * 9) & M32
	var t := (s1 << 9) & M32
	s2 ^= s0
	s3 ^= s1
	s1 ^= s2
	s0 ^= s3
	s2 ^= t
	s3 = _rotl(s3, 11)
	_s[0] = s0
	_s[1] = s1
	_s[2] = s2
	_s[3] = s3
	chamadas += 1
	return resultado


func randf() -> float:
	return float(proximo_u32()) / 4294967296.0


func randi_intervalo(a: int, b: int) -> int:
	## Inteiro uniforme em [a, b] (inclusive), como `a + floor(rand * (b - a + 1))`.
	if b <= a:
		return a
	# Atenção: não chamar `randf()` sem `self` aqui — o GDScript resolve para o randf() global, sem semente.
	return a + int(floor(float(proximo_u32()) / 4294967296.0 * float(b - a + 1)))


func estado() -> PackedInt64Array:
	return _s.duplicate()
