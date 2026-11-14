-- Filtro/RetroTextura: texturas dos filtros do DitherDown sem upload (docs/filtro-ditherdown.md §4).
-- Ordem: (1) id fixo em Config/Filtro/Texturas[chave]; (2) EditableImage gerada a partir dos bytes RGBA; (3) falhou = nil
-- (um warn por chave) e a camada fica oculta. Nunca derruba o filtro.
-- NÃO VERIFICADO no Studio: AssetService:CreateEditableImage, EditableImage:WritePixelsBuffer, Content.fromObject e
-- ImageLabel.ImageContent. Cada uso está em pcall; confirmar quando a dona do Studio puder testar.
local AssetService = game:GetService("AssetService")

export type Resultado = { imagem: string?, conteudo: any? }

type Entrada = { largura: number, altura: number, hash: number, img: any, resultado: Resultado }

local RetroTextura = {}

local cache: { [string]: Entrada } = {}
local avisadas: { [string]: boolean } = {}

local function avisar(chave: string, motivo: any)
	if avisadas[chave] then
		return
	end
	avisadas[chave] = true
	warn(`[Filtro/Retro] textura "{chave}" indisponível, camada fica oculta: {motivo}`)
end

-- Hash simples dos bytes (mod 2^32): basta para saber se o conteúdo mudou; colisão só custaria uma imagem desatualizada.
local function hashBytes(bytes: { number }): number
	local h = 5381
	for i = 1, #bytes do
		h = (h * 33 + bytes[i]) % 4294967296
	end
	return h
end

local function gerar(largura: number, altura: number, bytes: { number }): (any, Resultado)
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(largura, altura) })
	local buf = buffer.create(largura * altura * 4)
	for i = 1, largura * altura * 4 do
		buffer.writeu8(buf, i - 1, math.clamp(math.floor(bytes[i] + 0.5), 0, 255))
	end
	local ok, erro = pcall(function()
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(largura, altura), buf)
	end)
	if not ok then
		pcall(function()
			img:Destroy()
		end)
		error(erro, 0)
	end
	return img, { conteudo = (Content :: any).fromObject(img) }
end

-- chave: nome em Config/Filtro/Texturas (ex. "retroDither"); bytes: largura*altura*4 inteiros RGBA, linha a linha de cima para baixo.
function RetroTextura.criar(
	chave: string,
	largura: number,
	altura: number,
	bytes: { number },
	ctxConfig: any
): Resultado?
	local id = ctxConfig and ctxConfig.Texturas and ctxConfig.Texturas[chave]
	if type(id) == "string" and id ~= "" then
		return { imagem = id }
	end

	if #bytes ~= largura * altura * 4 then
		avisar(chave, `bytes ({#bytes}) não bate com {largura}x{altura}x4`)
		return nil
	end

	local hash = hashBytes(bytes)
	local antiga = cache[chave]
	if antiga and antiga.largura == largura and antiga.altura == altura and antiga.hash == hash then
		return antiga.resultado
	end

	local ok, img, resultado = pcall(gerar, largura, altura, bytes)
	if not ok or not img then
		avisar(chave, img)
		return nil
	end
	cache[chave] = { largura = largura, altura = altura, hash = hash, img = img, resultado = resultado }
	-- destrói a antiga só depois da nova existir; quem usava troca a imagem logo em seguida (aplicar)
	if antiga then
		pcall(function()
			antiga.img:Destroy()
		end)
	end
	return resultado
end

-- Põe o resultado no ImageLabel. false = nil (a camada deve ficar oculta).
function RetroTextura.aplicar(rotulo: ImageLabel, resultado: Resultado?): boolean
	if not resultado then
		return false
	end
	if resultado.imagem then
		rotulo.Image = resultado.imagem
		return true
	end
	local alvo: any = rotulo
	local ok = pcall(function()
		alvo.Image = ""
		alvo.ImageContent = resultado.conteudo
	end)
	return ok
end

return RetroTextura
