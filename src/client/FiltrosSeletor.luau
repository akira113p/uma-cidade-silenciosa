-- FiltrosSeletor: seção "Filtros de tela (DitherDown)" dentro da lista de Configuracoes (docs/filtro-ditherdown.md §6).
-- Só monta linhas; quem pede ao servidor é o `pedir` de Configuracoes (lote de 1 envio por segundo).
-- Configuracoes continua dona dos helpers de linha e os repassa em `opcoes`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FiltrosSeletor = {}

local COR_CINZA = Color3.fromRGB(140, 140, 136)
local TAMANHO_TITULO = 20
local TAMANHO_NOTA = 14
local RECUO = "  " -- Força e extras ficam recuados sob o filtro

export type Opcoes = {
	lista: Instance, -- ScrollingFrame com UIListLayout (SortOrder = LayoutOrder)
	ordemInicial: number, -- primeiro LayoutOrder livre
	config: any, -- Config/Filtro (usa .Seletor e .Retro.ativo)
	alturaLinha: number,
	fonte: Enum.Font,
	corTexto: Color3,
	criar: (classe: string, propriedades: { [string]: any }, pai: Instance?) -> any,
	botao: (texto: string, pai: Instance, propriedades: { [string]: any }?) -> TextButton,
	pedir: (chave: string, valor: any) -> (),
	linhaLigaDesliga: (ordem: number, rotulo: string, chave: string, lista: Instance) -> (),
	linhaOpcoes: (ordem: number, rotulo: string, chave: string, valores: { number }, lista: Instance) -> (),
}

-- Devolve o próximo LayoutOrder livre (igual a ordemInicial se não montou nada).
function FiltrosSeletor.montar(o: Opcoes): number
	local retro = o.config.Retro
	if type(retro) ~= "table" or not retro.ativo then
		return o.ordemInicial
	end
	local seletor = o.config.Seletor
	local Regras =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regras"):WaitForChild("FiltroSeletor"))

	local ordem = o.ordemInicial

	-- Texto corrido (título, nota, aviso, motivo): quebra linha e cresce em altura.
	local function texto(conteudo: string, tamanho: number, cor: Color3)
		o.criar("TextLabel", {
			BackgroundTransparency = 1,
			Text = conteudo,
			Font = o.fonte,
			TextSize = tamanho,
			TextColor3 = cor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			LayoutOrder = ordem,
		}, o.lista)
		ordem += 1
	end

	texto(seletor.titulo, TAMANHO_TITULO, o.corTexto)
	texto(seletor.nota, TAMANHO_NOTA, COR_CINZA)

	for _, f in seletor.filtros do
		if f.indisponivel then
			texto(f.rotulo .. " (indisponível): " .. f.motivo, TAMANHO_NOTA, COR_CINZA)
		else
			o.linhaLigaDesliga(ordem, f.rotulo, f.pref, o.lista)
			ordem += 1
			if f.aviso then
				texto(RECUO .. f.aviso, TAMANHO_NOTA, COR_CINZA)
			end
			if f.forca then
				o.linhaOpcoes(ordem, RECUO .. f.forca.rotulo, f.forca.pref, f.forca.opcoes, o.lista)
				ordem += 1
			end
			for _, extra in f.extras or {} do
				o.linhaOpcoes(ordem, RECUO .. extra.rotulo, extra.pref, extra.opcoes, o.lista)
				ordem += 1
			end
		end
	end

	-- Presets: uma linha de botões; cada um manda seus pares pelo mesmo `pedir` dos outros controles.
	local presets = seletor.presets
	if #presets > 0 then
		local area = o.criar("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, o.alturaLinha),
			LayoutOrder = ordem,
		}, o.lista)
		ordem += 1
		o.criar("UIGridLayout", {
			CellSize = UDim2.new(1 / #presets, -4, 1, 0),
			CellPadding = UDim2.fromOffset(4, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, area)
		for i, preset in presets do
			local b = o.botao(preset.rotulo, area, { LayoutOrder = i, TextSize = 16 })
			b.Activated:Connect(function()
				for pref, valor in Regras.aplicarPreset(preset) do
					o.pedir(pref, valor)
				end
			end)
		end
	end

	return ordem
end

return FiltrosSeletor
