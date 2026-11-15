// Camada de sombra de um andar (render/sombras.gd), desenhada como canvas group: os filhos (sombras pretas) viram uma
// imagem só, que aqui recebe blur e o alpha do grupo — como BlurFilter(strength = soft, quality 1) + AlphaFilter
// (opacidade) do cliente (C). O blur é aproximado (F): 9 pontos em cruz, a `suave` px de tela de distância.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;
uniform float opacidade = 0.45;
uniform float suave = 1.0;

void fragment() {
	vec2 d = SCREEN_PIXEL_SIZE * suave;
	float a = texture(tela, SCREEN_UV).a * 0.2;
	a += (texture(tela, SCREEN_UV + vec2(d.x, 0.0)).a + texture(tela, SCREEN_UV - vec2(d.x, 0.0)).a
		+ texture(tela, SCREEN_UV + vec2(0.0, d.y)).a + texture(tela, SCREEN_UV - vec2(0.0, d.y)).a) * 0.12;
	a += (texture(tela, SCREEN_UV + d).a + texture(tela, SCREEN_UV - d).a
		+ texture(tela, SCREEN_UV + vec2(d.x, -d.y)).a + texture(tela, SCREEN_UV + vec2(-d.x, d.y)).a) * 0.08;
	COLOR = vec4(0.0, 0.0, 0.0, a * opacidade);
}
