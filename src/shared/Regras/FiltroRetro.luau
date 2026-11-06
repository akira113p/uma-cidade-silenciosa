--!strict
-- Contas puras dos filtros do DitherDown (docs/filtro-ditherdown.md §3). Sem Roblox. Dono: Agente A.
-- Multiplicar a cena por k = sobrepor preto com alfa 1-k; o dither sobrepõe branco ou preto com alfa proporcional ao desvio.

local FiltroRetro = {}

local PI2 = 2 * math.pi

local function arredondar(v: number): number
	return math.floor(v + 0.5)
end

-- Arredonda para a potência de 2 suportada mais próxima (2, 4, 8 ou 16); empate sobe (3 -> 4, 6 -> 8, 12 -> 16).
-- O servidor valida só o intervalo 2..16, então 3 ou 5 podem chegar; não-número ou nan cai no padrão 4.
function FiltroRetro.potenciaValida(n: number): number
	local v: any = n
	if type(v) ~= "number" or v ~= v then
		return 4
	end
	if v <= 2 then
		return 2
	elseif v >= 16 then
		return 16
	end
	local melhor, melhorDist = 2, math.huge
	for _, p in { 2, 4, 8, 16 } do
		local d = math.abs(v - p)
		-- `<=`: com empate vence a potência maior (a lista é crescente)
		if d <= melhorDist then
			melhor, melhorDist = p, d
		end
	end
	return melhor
end

-- Matriz de Bayer n×n com os inteiros 0..n*n-1 sem repetir. M2 = {{0,2},{3,1}}; M2n = {{4M, 4M+2}, {4M+3, 4M+1}}.
-- n fora de {2,4,8,16} é normalizado por potenciaValida.
function FiltroRetro.bayer(n: number): { { number } }
	local lado = FiltroRetro.potenciaValida(n)
	if lado == 2 then
		return { { 0, 2 }, { 3, 1 } }
	end
	local meio = lado // 2
	local m = FiltroRetro.bayer(meio)
	local r: { { number } } = {}
	for i = 1, lado do
		r[i] = table.create(lado, 0)
	end
	for i = 1, meio do
		for j = 1, meio do
			local v = m[i][j] * 4
			r[i][j] = v
			r[i][j + meio] = v + 2
			r[i + meio][j] = v + 3
			r[i + meio][j + meio] = v + 1
		end
	end
	return r
end

-- Limiar em (0,1) do valor de Bayer: o centro do degrau, para a média ficar em 0.5.
function FiltroRetro.limiarBayer(valor: number, n: number): number
	return (valor + 0.5) / (n * n)
end

-- Um texel do dither: branco se o limiar passa de 0.5, preto se não; alfa = 2·amplitude·|d| (aproxima C + a·d perto do cinza médio).
function FiltroRetro.texelDither(valor: number, n: number, amplitude: number): (number, number)
	local d = FiltroRetro.limiarBayer(valor, n) - 0.5
	local cor = if d >= 0 then 255 else 0
	local alfa = math.min(1, 2 * amplitude * math.abs(d))
	return cor, alfa
end

-- Textura n×n em RGBA (n*n*4 inteiros 0..255), linha a linha de cima para baixo.
function FiltroRetro.texturaDither(n: number, amplitude: number): { number }
	local m = FiltroRetro.bayer(n)
	local lado = #m
	local bytes: { number } = table.create(lado * lado * 4, 0)
	local k = 0
	for i = 1, lado do
		for j = 1, lado do
			local cor, alfa = FiltroRetro.texelDither(m[i][j], lado, amplitude)
			bytes[k + 1] = cor
			bytes[k + 2] = cor
			bytes[k + 3] = cor
			bytes[k + 4] = arredondar(alfa * 255)
			k += 4
		end
	end
	return bytes
end

-- Força da preferência (0..100) vira escala 0..1 da amplitude. nan ou não-número = 0.
function FiltroRetro.escalaForca(forca: number): number
	local v: any = forca
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(v, 0, 100) / 100
end

-- Scanlines duras: `contagem` ciclos por tela, com piso em px para não virar ruído em tela pequena.
function FiltroRetro.cicloScanDuraPx(alturaTela: number, contagem: number, minimoPx: number): number
	if contagem <= 0 then
		return minimoPx
	end
	return math.max(alturaTela / contagem, minimoPx)
end

-- Scanlines suaves: o shader usa sin(y*contagem) sem 2π, então o período é 2π/contagem da altura.
function FiltroRetro.periodoScanSuavePx(alturaTela: number, contagem: number, minimoPx: number): number
	if contagem <= 0 then
		return minimoPx
	end
	return math.max(alturaTela * PI2 / contagem, minimoPx)
end

-- Alfa do preto sobre a cena na fração `frac` (0..1) do ciclo duro: 1ª metade escura (brilho mínimo), 2ª clara.
function FiltroRetro.alfaScanDura(frac: number, minimo: number, maximo: number): number
	local s = if frac >= 0.5 then 1 else 0
	local k = minimo + (maximo - minimo) * s
	return 1 - k
end

-- Idem para o ciclo suave: brilho segue o seno, de `minimo` a `maximo`.
function FiltroRetro.alfaScanSuave(frac: number, minimo: number, maximo: number): number
	local s = math.sin(PI2 * frac)
	local k = minimo + (s + 1) / 2 * (maximo - minimo)
	return 1 - k
end

-- Brilho das bandas rolando no ponto y (fração da altura) no instante t, como o shader RollingBands.
function FiltroRetro.brilhoBandas(
	y: number,
	t: number,
	velocidade: number,
	frequencia: number,
	minimo: number,
	maximo: number
): number
	return minimo + (math.sin((t * velocidade + y) * frequencia) + 1) / 2 * (maximo - minimo)
end

-- Período vertical das bandas em px: sin(y*f) repete a cada 2π/f da altura.
function FiltroRetro.periodoBandasPx(alturaTela: number, frequencia: number): number
	return alturaTela * PI2 / frequencia
end

-- Quanto a textura de 1 período já desceu em px: t·velocidade telas, módulo o período (sem costura na volta).
function FiltroRetro.deslocBandasPx(t: number, velocidade: number, alturaTela: number, periodoPx: number): number
	if periodoPx <= 0 then
		return 0
	end
	return (t * velocidade * alturaTela) % periodoPx
end

-- Alfa do preto das bandas na fração `frac` do período (a rolagem fica por conta do deslocamento).
function FiltroRetro.alfaBandas(frac: number, minimo: number, maximo: number): number
	return 1 - (minimo + (math.sin(PI2 * frac) + 1) / 2 * (maximo - minimo))
end

-- Textura 1×altura em RGBA, toda preta; só o alfa varia, amostrado no centro de cada texel (de cima para baixo).
-- `amplitudeEscala` (escalaForca) multiplica o alfa.
function FiltroRetro.texturaPerfilVertical(
	altura: number,
	alfaDeFrac: (number) -> number,
	amplitudeEscala: number
): { number }
	local bytes: { number } = table.create(altura * 4, 0)
	for i = 1, altura do
		local alfa = math.clamp(alfaDeFrac((i - 0.5) / altura) * amplitudeEscala, 0, 1)
		local k = (i - 1) * 4
		bytes[k + 1] = 0
		bytes[k + 2] = 0
		bytes[k + 3] = 0
		bytes[k + 4] = arredondar(alfa * 255)
	end
	return bytes
end

-- Deslocamento horizontal em px do VHS linear: offset (fração da largura) limitado a ±1% como no shader.
function FiltroRetro.vhsDeslocPx(offset: number, larguraTela: number): number
	return math.clamp(offset, -0.01, 0.01) * larguraTela
end

return FiltroRetro
