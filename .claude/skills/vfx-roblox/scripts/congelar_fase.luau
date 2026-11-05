-- congelar_fase.luau
-- "Congelamento de fase": um efeito dura menos de 1 s, então um screenshot comum é cara ou coroa.
-- Este script dispara o efeito, espera o tempo exato e congela as partículas (TimeScale = 0).
-- Rodar pelo MCP: execute_luau (datamodel Edit) com ALVO e TEMPO ajustados, depois screen_capture,
-- depois rodar de novo com MODO = "soltar". Repetir para início (~0.05 s), meio e fim do efeito.

local ALVO = "workspace.Bancada.Efeito" -- caminho do Model/Part/Attachment que contém o efeito
local TEMPO = 0.15 -- segundos depois do disparo
local MODO = "congelar" -- "congelar" | "soltar"
local QUANTIDADE_PADRAO = 20 -- partículas por emissor quando o emissor não tem atributo "Emitir"

local function achar(caminho: string): Instance?
	local atual: Instance? = game
	for parte in string.gmatch(caminho, "[^%.]+") do
		if parte ~= "game" then
			atual = atual and atual:FindFirstChild(parte)
		end
	end
	return atual
end

local alvo = achar(ALVO)
if not alvo then
	return "não achei " .. ALVO
end

local emissores = {}
for _, d in alvo:GetDescendants() do
	if d:IsA("ParticleEmitter") then
		table.insert(emissores, d)
	end
end
if alvo:IsA("ParticleEmitter") then
	table.insert(emissores, alvo)
end

if MODO == "soltar" then
	for _, e in emissores do
		e.TimeScale = 1
		e:Clear()
	end
	return string.format("soltos %d emissores", #emissores)
end

for _, e in emissores do
	e.TimeScale = 1
	e:Clear()
end
for _, e in emissores do
	e:Emit(e:GetAttribute("Emitir") or QUANTIDADE_PADRAO)
end
task.wait(TEMPO)
for _, e in emissores do
	e.TimeScale = 0
end
return string.format("congelado em t=%.2fs: %d emissores. Agora screen_capture.", TEMPO, #emissores)
