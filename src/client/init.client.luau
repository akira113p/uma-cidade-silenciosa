-- Início do cliente: inicia cada controlador na ordem de docs/arquitetura.md §2.
-- Erro de um controlador é impresso e os outros continuam.

local ORDEM = {
	"Versao",
	"Mouse",
	"SonsLocal",
	"Filtro",
	"Controles",
	"Camera",
	"Configuracoes",
	"HudSom",
	"Voz",
	"DebugRuido",
	"HudVida",
	"InventarioUI",
	"Mangueira", -- depois de InventarioUI: usa o mesmo remote Inventario para saber se há recipiente vazio
	-- Armas: quem MOSTRA (viewmodel, efeitos, HUD) liga antes de quem ATUA (ArmasCliente), para ouvir o primeiro sinal.
	"ArmasViewmodel",
	"EfeitosArma",
	"HudMunicao",
	"ArmasCliente",
	"ArmasTerceira", -- corpo animado em 3ª pessoa e mira dos outros; escuta os sinais de ArmasCliente
	"Lanterna",
	"Admin",
	"Aparencia",
	"Direcao",
	"Cabine",
	"HudVeiculo",
	"ItensChaoCliente", -- depois de Mouse (menu aberto) e Direcao (dentro do carro), que ele consulta
}

local modulos = {}
for _, nome in ORDEM do
	local arquivo = script:FindFirstChild(nome)
	if not arquivo then
		warn("[cliente] controlador ausente: " .. nome)
		continue
	end
	local ok, modulo = pcall(require, arquivo)
	if ok then
		modulos[nome] = modulo
	else
		warn("[cliente] erro ao carregar " .. nome .. ": " .. tostring(modulo))
	end
end

for _, nome in ORDEM do
	local modulo = modulos[nome]
	if modulo and modulo.iniciar then
		local ok, erro = pcall(modulo.iniciar)
		if not ok then
			warn("[cliente] erro ao iniciar " .. nome .. ": " .. tostring(erro))
		end
	end
end

-- Só no Studio: o atributo TesteUI do jogador abre um menu ("inventario#1", "admin#2", "config#3"...). A simulação
-- de teclado do MCP não chega ao jogo, então o playtest automático usa isto no lugar de Tab/O/P.
if game:GetService("RunService"):IsStudio() then
	local jogador = game:GetService("Players").LocalPlayer
	local MENUS = { inventario = "InventarioUI", admin = "Admin", config = "Configuracoes", camera = "Camera" }
	jogador:GetAttributeChangedSignal("TesteUI"):Connect(function()
		local valor = jogador:GetAttribute("TesteUI")
		local nome = type(valor) == "string" and valor:match("^(%a+)")
		local modulo = nome and modulos[MENUS[nome]]
		if modulo and modulo.alternar then
			modulo.alternar()
		end
	end)
end
