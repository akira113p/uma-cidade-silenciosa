-- Lanterna (cliente): desenha a luz da lanterna do próprio jogador (presa à câmera, com balanço, atraso e cintilação)
-- e as dos outros jogadores (SpotLight simples na cabeça). Dono: S7. Números: Config/Lanterna; fórmulas: Regras/Lanterna.
-- O cliente só PEDE (evento Lanterna, tecla F); quem liga é o servidor (atributo Character.LanternaLigada).
-- A lanterna é silenciosa: nada aqui chama Ruido.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Lanterna"))
local Texturas = require(Shared.Config:WaitForChild("Filtro"):WaitForChild("Texturas"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Lanterna"))
local Luz = require(Shared.Regras:WaitForChild("Luz"))
local Teclas = require(script.Parent.Teclas)

local Lanterna = {}

local jogador = Players.LocalPlayer
local ALCANCE_MAX_LUZ = 60 -- o Roblox corta Range de luz em 60 studs

local nivel = 3 -- qualidade (0..3, a mesma do filtro). Abaixo de 2 corta o núcleo e o preenchimento; abaixo de 2 sem cone
local ganho = 0 -- 0..1: fade da luz ao ligar/apagar
local direcao: Regras.Vec? = nil
local velocidade = 0 -- studs/s suavizada, para o balanço
local semente = 1

local pasta: Folder
local parte: Part
local principal: SpotLight
local nucleo: SpotLight
local preenchimento: PointLight
local feixe: Beam
local anexoFim: Attachment
local transpFeixe = 1

local function cor3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function criarLuzProprio()
	pasta = Instance.new("Folder")
	pasta.Name = "Lanterna"

	parte = Instance.new("Part")
	parte.Name = "LanternaLuz"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = false
	parte.Transparency = 1
	parte.Size = Vector3.new(0.2, 0.2, 0.2)
	parte.Parent = pasta

	local cor = cor3(Cfg.cor)

	local function spot(c: { angulo: number, alcance: number, brilho: number }, nome: string): SpotLight
		local s = Instance.new("SpotLight")
		s.Name = nome
		s.Face = Enum.NormalId.Front
		s.Angle = c.angulo
		s.Range = math.min(c.alcance, ALCANCE_MAX_LUZ)
		s.Color = cor
		s.Brightness = 0
		s.Shadows = false
		s.Enabled = false
		s.Parent = parte
		return s
	end
	principal = spot(Cfg.principal, "Principal")
	nucleo = spot(Cfg.nucleo, "Nucleo")

	preenchimento = Instance.new("PointLight")
	preenchimento.Name = "Preenchimento"
	preenchimento.Range = math.min(Cfg.preenchimento.alcance, ALCANCE_MAX_LUZ)
	preenchimento.Color = cor
	preenchimento.Brightness = 0
	preenchimento.Shadows = false
	preenchimento.Enabled = false
	preenchimento.Parent = parte

	-- Feixe volumétrico: a textura corre ao longo do feixe (Attachment0 -> Attachment1) e cone_luz já vem girada.
	local a0 = Instance.new("Attachment")
	a0.Name = "Inicio"
	a0.Parent = parte
	anexoFim = Instance.new("Attachment")
	anexoFim.Name = "Fim"
	anexoFim.Position = Vector3.new(0, 0, -Cfg.cone.alcance)
	anexoFim.Parent = parte
	feixe = Instance.new("Beam")
	feixe.Name = "Feixe"
	feixe.Attachment0 = a0
	feixe.Attachment1 = anexoFim
	feixe.FaceCamera = true
	feixe.LightEmission = 1
	feixe.LightInfluence = 0
	feixe.Segments = 1
	feixe.TextureMode = Enum.TextureMode.Stretch
	feixe.Texture = Texturas.coneLuz
	feixe.Color = ColorSequence.new(cor)
	feixe.Width0 = Cfg.cone.largura0
	feixe.Width1 = Cfg.cone.largura1
	feixe.Transparency = NumberSequence.new(1)
	feixe.Enabled = false
	feixe.Parent = a0
end

local function apagarProprio()
	principal.Enabled = false
	nucleo.Enabled = false
	preenchimento.Enabled = false
	feixe.Enabled = false
end

local function vec(v: Vector3): Regras.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function velocidadeHorizontal(personagem: Model?): number
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not (humanoide and raiz and raiz:IsA("BasePart")) or humanoide.MoveDirection.Magnitude < 0.1 then
		return 0
	end
	local v = raiz.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function passo(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if pasta.Parent ~= camera then
		pasta.Parent = camera
	end

	local personagem = jogador.Character
	local ligada = personagem ~= nil
		and personagem:GetAttribute("LanternaLigada") == true
		and jogador:GetAttribute("Morto") ~= true
	local fade = math.max(Cfg.fadeLigar, 0.01)
	ganho = math.clamp(ganho + (if ligada then dt else -dt) / fade, 0, 1)
	if ganho <= 0 then
		direcao = nil
		velocidade = 0
		apagarProprio()
		return
	end

	-- balanço: velocidade filtrada (sem salto ao parar/arrancar) -> deslocamento da mão no espaço da câmera
	local alvoVel = velocidadeHorizontal(personagem)
	velocidade += (alvoVel - velocidade) * (1 - 0.5 ^ (dt / Cfg.balanco.suavizacaoVelocidade))
	local t = os.clock()
	local dx, dy = Regras.balanco(t, velocidade, Cfg.balanco)

	local cf = camera.CFrame
	local d = Cfg.deslocamento
	local posicao = (cf * CFrame.new(d.x + dx, d.y + dy, d.z)).Position
	-- o facho mira o ponto que a câmera olha, à distância de convergência (a mão fica abaixo e à direita do olhar)
	local alvo = cf.Position + cf.LookVector * Cfg.convergencia
	local alvoDir = vec(alvo - posicao)
	direcao = if direcao
		then Regras.suavizarDirecao(direcao, alvoDir, dt, Cfg.meiaVidaDirecao)
		else Regras.suavizarDirecao(alvoDir, alvoDir, dt, 0)
	local frente = Vector3.new(direcao.x, direcao.y, direcao.z)
	parte.CFrame = CFrame.lookAt(posicao, posicao + frente)

	-- brilho: fade * cintilação (queda curta de 5..15%, nunca pisca forte)
	-- de dia a lanterna é atenuada (fatorDia): a mesma luz a 34 de brilho vira mancha branca na fachada sob a névoa clara
	local luzDia = math.clamp(Luz.luzDaHora(Lighting.ClockTime), 0, 1)
	local atenuacaoDia = 1 - (1 - Cfg.fatorDia) * luzDia
	local f = ganho * Regras.cintilacao(t, semente, Cfg.cintilacao) * atenuacaoDia
	principal.Brightness = Cfg.principal.brilho * f
	principal.Enabled = true
	local completo = nivel >= 2
	nucleo.Brightness = Cfg.nucleo.brilho * f
	nucleo.Enabled = completo
	preenchimento.Brightness = Cfg.preenchimento.brilho * f
	preenchimento.Enabled = completo

	-- feixe: mais visível quanto mais escuro; sem id de textura ou em qualidade baixa fica oculto (a luz continua)
	local mostrarFeixe = Cfg.cone.ligado and Texturas.coneLuz ~= "" and completo
	feixe.Enabled = mostrarFeixe
	if mostrarFeixe then
		local noite = 1 - math.clamp(Luz.luzDaHora(Lighting.ClockTime), 0, 1)
		local visivel = Cfg.cone.fatorDia + (1 - Cfg.cone.fatorDia) * noite
		local tr = 1 - (1 - Cfg.cone.transparencia) * visivel * f
		if math.abs(tr - transpFeixe) > 0.01 then
			transpFeixe = tr
			feixe.Transparency = NumberSequence.new(tr)
		end
	end
end

-- Luz dos outros jogadores ---------------------------------------------------------------------------------------

type LuzOutro = { anexo: Attachment, luz: SpotLight }
local outros: { [Player]: LuzOutro } = {}

local function removerOutro(p: Player)
	local rec = outros[p]
	if rec then
		rec.anexo:Destroy() -- leva a luz junto
		outros[p] = nil
	end
end

local function criarOutro(p: Player, cabeca: BasePart)
	local c = Cfg.outros
	local anexo = Instance.new("Attachment")
	anexo.Name = "LanternaLuz"
	anexo.Position = Vector3.new(c.deslocamento.x, c.deslocamento.y, c.deslocamento.z)
	local luz = Instance.new("SpotLight")
	luz.Face = Enum.NormalId.Front
	luz.Angle = c.angulo
	luz.Range = math.min(c.alcance, ALCANCE_MAX_LUZ)
	luz.Brightness = c.brilho
	luz.Color = cor3(Cfg.cor)
	luz.Shadows = false
	luz.Parent = anexo
	anexo.Parent = cabeca
	outros[p] = { anexo = anexo, luz = luz }
end

-- 4 Hz: cria a luz de quem acendeu e remove a de quem apagou, morreu ou saiu.
local function varrer()
	for p in outros do
		if p.Parent == nil then
			removerOutro(p)
		end
	end
	for _, p in Players:GetPlayers() do
		if p == jogador then
			continue
		end
		local personagem = p.Character
		local acesa = personagem ~= nil
			and personagem:GetAttribute("LanternaLigada") == true
			and p:GetAttribute("Morto") ~= true
		local cabeca = if acesa and personagem then personagem:FindFirstChild("Head") else nil
		local rec = outros[p]
		if cabeca and cabeca:IsA("BasePart") then
			if rec and rec.anexo.Parent ~= cabeca then
				removerOutro(p)
				rec = nil
			end
			if not rec then
				criarOutro(p, cabeca)
			end
		elseif rec then
			removerOutro(p)
		end
	end
end

-- Qualidade automática do filtro (0..3). Ninguém chama ainda: o orquestrador do Filtro não a expõe (docs/pendencias).
function Lanterna.qualidade(n: number)
	nivel = n
end

function Lanterna.iniciar()
	semente = jogador.UserId % 100000
	criarLuzProprio()
	apagarProprio()

	Teclas.ligar("lanterna", Cfg.teclas, function()
		local slot = jogador:GetAttribute("LanternaSlot")
		if type(slot) ~= "number" or jogador:GetAttribute("Morto") == true then
			return
		end
		local personagem = jogador.Character
		local ligada = personagem ~= nil and personagem:GetAttribute("LanternaLigada") == true
		Rede.evento("Lanterna"):FireServer(not ligada)
	end)

	-- depois da câmera do Roblox (Camera), da câmera dinâmica (Camera + 1) e antes do filtro (Camera + 5)
	RunService:BindToRenderStep("Lanterna", Enum.RenderPriority.Camera.Value + 3, passo)

	task.spawn(function()
		while true do
			varrer()
			task.wait(Cfg.outros.intervaloVarredura)
		end
	end)
end

return Lanterna
