-- Caixa de céu da névoa (docs/filtro.md §5 S3). PROVISÓRIO: afinar no Studio (Filtro_Ceu_<chave>).
return {
	margem = 40, -- studs: a caixa fica a FogEnd + margem da câmera
	ladoMaximo = 2048, -- studs: limite de tamanho de Part por eixo
	espessura = 8, -- studs: espessura de cada placa
	profundidadeChao = 80, -- studs abaixo da câmera: placa do chão (só tampa buracos do terreno)
	toleranciaFogEnd = 1, -- studs: só redimensiona se o FogEnd mudar mais que isto
}
