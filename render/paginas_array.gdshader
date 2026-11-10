// Mapa em lote (2b.6): todas as páginas do atlas do mapa num Texture2DArray de 2048×2048 por camada.
// O sprite é desenhado com uma textura branca de 1×1, então o UV chega em pixels; a camada vai codificada no x da
// região (x + camada·2048; a página tem no máximo 2046 de largura). texelFetch = amostragem "nearest" exata, como o
// original. Todos os sprites do mapa usam a mesma textura e o mesmo material → o GL junta os lotes.
shader_type canvas_item;

uniform sampler2DArray paginas : filter_nearest;

void fragment() {
	float camada = floor(UV.x / 2048.0);
	ivec3 p = ivec3(int(floor(UV.x - camada * 2048.0)), int(floor(UV.y)), int(camada));
	COLOR = texelFetch(paginas, p, 0) * COLOR;
}
