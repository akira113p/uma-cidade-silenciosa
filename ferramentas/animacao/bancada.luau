-- Bancada de animação (ferramenta de teste do agente A4; NÃO faz parte do jogo, o Rojo não sincroniza esta pasta).
-- Colar este arquivo como ModuleScript em ServerStorage.Bancada (execute_luau, modo Edição). Cinemática direta (FK) das poses de
-- assets/animacoes/armas/<classe>.json num R15 revestido como o jogo, em workspace.Bancada, para tirar folhas de quadros sem playtest
-- (animação não roda fora do playtest). Uso: B.carregar(textoJson); B.folha({classe=, clipe=, tempos={...}, angulo=90})
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Dados: any = {} -- Dados[classe][clipe] = { duracao, loop, prioridade, quadros = { {t, easing, marcadores, juntas} } }
local MAO: any = { C0 = { -90, 0, 0, 0, -0.16, 0 }, porClasse = {} }

local Bancada = {}

local ORIGEM = Vector3.new(0, 3000, 0)
local CORPO = {
	"HumanoidRootPart",
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- armas de teste: caixas em coordenadas do Cabo (origem = empunhadura, cano para -Z, cima +Y), apoio = ApoioEsquerdo
local V = Vector3.new
local ARMAS = {
	faca = {
		caixas = { { V(0.1, 0.12, 0.34), V(0, 0, 0.0) }, { V(0.03, 0.17, 0.6), V(0, 0.02, -0.45) } },
	},
	contundente = {
		caixas = { { V(0.09, 0.09, 1.75), V(0, 0, -0.55) }, { V(0.09, 0.3, 0.09), V(0, -0.1, -1.4) } },
	},
	machado = {
		caixas = { { V(0.1, 0.1, 2.0), V(0, 0, -0.7) }, { V(0.1, 0.55, 0.7), V(0, 0, -1.65) } },
		apoio = V(0, 0, -0.9),
	},
	pistola = {
		caixas = { { V(0.14, 0.2, 0.58), V(0, 0.14, -0.2) }, { V(0.12, 0.38, 0.16), V(0, -0.1, 0.02) } },
	},
	fuzil = {
		caixas = {
			{ V(0.16, 0.22, 1.8), V(0, 0.1, -0.85) },
			{ V(0.14, 0.34, 0.7), V(0, 0.0, 0.95) },
			{ V(0.12, 0.3, 0.14), V(0, -0.16, 0.0) },
			{ V(0.1, 0.4, 0.22), V(0, -0.28, -0.5) },
		},
		apoio = V(0, 0.14, -0.97),
	},
	escopeta = {
		caixas = {
			{ V(0.14, 0.18, 2.1), V(0, 0.1, -1.05) },
			{ V(0.14, 0.3, 0.9), V(0, -0.02, 0.9) },
			{ V(0.2, 0.2, 0.55), V(0, -0.05, -0.95) },
		},
		apoio = V(0, 0.09, -1.59),
	},
	lancador = {
		caixas = { { V(0.5, 0.5, 2.76), V(0, 0.28, -0.4) }, { V(0.12, 0.3, 0.14), V(0, -0.16, 0.0) } },
		apoio = V(0, 0.15, -0.75),
	},
}

local function pasta(): Folder
	local p = workspace:FindFirstChild("Bancada")
	if not p then
		p = Instance.new("Folder")
		p.Name = "Bancada"
		p.Parent = workspace
	end
	return p :: Folder
end

local function ehCorpo(nome: string): boolean
	return table.find(CORPO, nome) ~= nil
end

local function ancorar(rig: Model)
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- Rig molde: R15 escalado e revestido como no jogo (blocos), escondido longe.
function Bancada.molde(): Model
	local f = pasta()
	local m = f:FindFirstChild("Molde")
	if m then
		return m :: Model
	end
	local d = Instance.new("HumanoidDescription")
	d.HeightScale = 1.05
	d.WidthScale = 0.68
	d.DepthScale = 0.78
	d.HeadScale = 1
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	local rig = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	rig.Name = "Molde"
	rig.Parent = f
	rig:PivotTo(CFrame.new(ORIGEM))
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Aparencia")).revestir(rig)
	ancorar(rig)
	local a = rig:FindFirstChild("Animate")
	if a then
		a:Destroy()
	end
	rig:PivotTo(CFrame.new(ORIGEM + Vector3.new(0, -30, 0)))
	return rig
end

local function juntasDe(rig: Model): { Instance }
	local lista = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			table.insert(lista, d)
		end
	end
	return lista
end

-- Anexos (blocos, sola, cabelo): posição relativa à peça do corpo a que pertencem.
local function anexos(rig: Model): { { parte: BasePart, dono: BasePart, rel: CFrame } }
	local lista = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") and not (d.Parent == rig and ehCorpo(d.Name)) then
			local dono: Instance? = d.Parent
			while dono and dono.Parent ~= rig do
				dono = dono.Parent
			end
			if dono and dono:IsA("BasePart") then
				table.insert(lista, { parte = d, dono = dono, rel = dono.CFrame:ToObjectSpace(d.CFrame) })
			end
		end
	end
	return lista
end

local function easing(estilo: string?, a: number): number
	if not estilo then
		return a
	end
	local tipo, dir = string.match(estilo, "^(%a+)%-?(%a*)$")
	if tipo ~= "Cubic" then
		return a
	end
	if dir == "Out" then
		return 1 - (1 - a) ^ 3
	elseif dir == "InOut" then
		return if a < 0.5 then 4 * a ^ 3 else 1 - (-2 * a + 2) ^ 3 / 2
	end
	return a ^ 3
end

-- valor da junta no instante t (graus/studs, 6 números) ou nil
local function valor(clipe, junta: string, t: number): { number }?
	local a, b
	for _, q in clipe.quadros do
		local v = q.juntas[junta]
		if v then
			if q.t <= t + 1e-6 then
				a = q
			elseif not b then
				b = q
			end
		end
	end
	if not a and not b then
		return nil
	end
	if not a then
		a = b
	end
	if not b or a == b then
		return a.juntas[junta]
	end
	local k = easing(b.easing or nil, (t - a.t) / (b.t - a.t))
	local r = {}
	for i = 1, 6 do
		r[i] = a.juntas[junta][i] + (b.juntas[junta][i] - a.juntas[junta][i]) * k
	end
	return r
end

local function transformDe(v: { number }): CFrame
	return CFrame.new(v[4], v[5], v[6]) * CFrame.fromEulerAnglesYXZ(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
end

-- Lê o JSON de uma classe (mesma regra de montar_armas.luau: "de" + "juntas") e guarda em Dados.
function Bancada.carregar(texto: string)
	local a = HttpService:JSONDecode(texto)
	local classe = {}
	for nome, c in a.clipes do
		local quadros = {}
		for _, q in c.quadros do
			local j = {}
			if q.de then
				for k, v in a.poses[q.de] do
					j[k] = v
				end
			end
			for k, v in q.juntas or {} do
				j[k] = v
			end
			for _, v in j do
				for i = 1, 6 do
					v[i] = v[i] or 0
				end
			end
			table.insert(quadros, { t = q.t, easing = q.easing, marcadores = q.marcadores or {}, juntas = j })
		end
		table.sort(quadros, function(x, y)
			return x.t < y.t
		end)
		classe[nome] = { duracao = c.duracao, loop = c.loop == true, prioridade = c.prioridade, quadros = quadros }
	end
	Dados[a.classe] = classe
end

function Bancada.carregarMao(texto: string)
	MAO = HttpService:JSONDecode(texto)
end

local function maoC0(classe: string): CFrame
	local v = MAO.porClasse[classe] or MAO.C0
	return CFrame.new(v[4], v[5], v[6]) * CFrame.fromEulerAnglesYXZ(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
end

-- Põe o rig na pose do clipe em t (FK) com a raiz em `raiz`.
function Bancada.posar(rig: Model, ax, clipe, t: number, raiz: CFrame)
	local hrp = rig.HumanoidRootPart :: BasePart
	hrp.CFrame = raiz
	local pendentes = juntasDe(rig)
	local mudou = true
	while mudou and #pendentes > 0 do
		mudou = false
		for i = #pendentes, 1, -1 do
			local j = pendentes[i] :: any
			local p0, p1 = j.Part0 :: BasePart, j.Part1 :: BasePart
			if p0 and p1 and ax.feitas[p0] then
				local tr = CFrame.identity
				if clipe then
					local v = valor(clipe, j.Name, t)
					if v then
						tr = transformDe(v)
					end
				end
				p1.CFrame = p0.CFrame * j.C0 * tr * j.C1:Inverse()
				ax.feitas[p1] = true
				ax.transform[j.Name] = tr
				table.remove(pendentes, i)
				mudou = true
			end
		end
	end
	for _, an in ax.anexos do
		an.parte.CFrame = an.dono.CFrame * an.rel
	end
end

local function criarArma(classe: string, rig: Model, apoioVisivel: boolean): Model?
	local def = ARMAS[classe]
	if not def then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "ArmaTeste"
	local cabo = Instance.new("Part")
	cabo.Name = "Cabo"
	cabo.Size = V(0.2, 0.2, 0.2)
	cabo.Transparency = 1
	cabo.Anchored = true
	cabo.CanCollide = false
	cabo.Parent = m
	cabo.CFrame = (rig:FindFirstChild("RightHand") :: BasePart).CFrame * maoC0(classe)
	for _, c in def.caixas do
		local p = Instance.new("Part")
		p.Size = c[1]
		p.Color = Color3.fromRGB(34, 34, 38)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = cabo.CFrame * CFrame.new(c[2])
		p.Parent = m
	end
	if def.apoio and apoioVisivel then
		local s = Instance.new("Part")
		s.Name = "Apoio"
		s.Shape = Enum.PartType.Ball
		s.Size = V(0.16, 0.16, 0.16)
		s.Color = Color3.fromRGB(255, 40, 40)
		s.Material = Enum.Material.Neon
		s.Anchored = true
		s.CanCollide = false
		s.CFrame = cabo.CFrame * CFrame.new(def.apoio)
		s.Parent = m
	end
	return m
end
Bancada.ARMAS = ARMAS

local function luz(centro: Vector3, dist: number, frontal: Vector3)
	local f = pasta()
	local antiga = f:FindFirstChild("Luzes")
	if antiga then
		antiga:Destroy()
	end
	local g = Instance.new("Folder")
	g.Name = "Luzes"
	g.Parent = f
	for _, off in
		{ frontal * dist * 0.6 + V(0, 14, 0), frontal * dist * 0.6 + V(14, 4, 0), frontal * dist * 0.6 + V(-14, 4, 0) }
	do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 1
		p.Size = V(1, 1, 1)
		p.Position = centro + off
		local l = Instance.new("PointLight")
		l.Brightness = 3
		l.Range = 90
		l.Shadows = false
		l.Parent = p
		p.Parent = g
	end
end

local salvos: { [Instance]: boolean }? = nil
-- Desliga/religa os efeitos de pós-processamento do Lighting (apenas durante os testes de bancada).
function Bancada.posProcessamento(ligado: boolean)
	if not salvos then
		salvos = {}
	end
	for _, e in Lighting:GetChildren() do
		if e:IsA("PostEffect") then
			if not ligado and (e :: any).Enabled then
				salvos[e] = true
				(e :: any).Enabled = false
			elseif ligado and salvos[e] then
				(e :: any).Enabled = true
				salvos[e] = nil
			end
		end
	end
end

-- Monta a folha de quadros.
-- opcoes: classe, clipe (nome; nil = pose de descanso), tempos {…}, angulo (graus de guinada; 90 = de lado), arma (bool, padrão true),
--         dist (padrão 75), esp (espaço entre quadros, padrão 4.4), aproximar (fração do zoom: 1 = enquadra o rig inteiro)
function Bancada.folha(o: any)
	Bancada.posProcessamento(false)
	local f = pasta()
	local molde = Bancada.molde()
	local velha = f:FindFirstChild("Folha")
	if velha then
		velha:Destroy()
	end
	local folha = Instance.new("Folder")
	folha.Name = "Folha"
	folha.Parent = f

	local clipe = o.clipe and Dados[o.classe][o.clipe] or nil
	assert(not o.clipe or clipe, "clipe inexistente")
	local tempos = o.tempos or { 0 }
	local n = #tempos
	local esp = o.esp or 4.4
	local angulo = o.angulo or 90
	local usarArma = o.arma ~= false
	local meio = (n + 1) / 2

	local fundoY = nil
	for i, t in tempos do
		local rig = molde:Clone()
		rig.Name = "Quadro" .. i
		rig.Parent = folha
		ancorar(rig)
		local ax = { feitas = {}, transform = {}, anexos = anexos(rig) }
		ax.feitas[rig.HumanoidRootPart] = true
		local x = -(i - meio) * esp
		local raiz = CFrame.new(ORIGEM + V(x, 0, 0)) * CFrame.Angles(0, math.rad(angulo), 0)
		Bancada.posar(rig, ax, clipe, t, raiz)
		if usarArma then
			local arma = criarArma(o.classe, rig, o.apoio ~= false)
			if arma then
				arma.Parent = rig
			end
		end
		-- legenda: tempo
		local rotulo = Instance.new("Part")
		rotulo.Transparency = 1
		rotulo.Anchored = true
		rotulo.CanCollide = false
		rotulo.Size = V(1, 1, 1)
		rotulo.CFrame = CFrame.new(ORIGEM + V(x, 3.6, 0))
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 24)
		bb.AlwaysOnTop = true
		bb.StudsOffset = V(0, 0, 0)
		local tx = Instance.new("TextLabel")
		tx.Size = UDim2.fromScale(1, 1)
		tx.BackgroundTransparency = 1
		tx.TextColor3 = Color3.new(1, 1, 0.4)
		tx.TextStrokeTransparency = 0
		tx.Font = Enum.Font.Code
		tx.TextSize = 18
		tx.Text = string.format("%.2fs", t)
		tx.Parent = bb
		bb.Parent = rotulo
		rotulo.Parent = rig
		if not fundoY then
			fundoY = math.huge
		end
		for _, nome in { "LeftFoot", "RightFoot" } do
			local p = rig:FindFirstChild(nome) :: BasePart
			fundoY = math.min(fundoY, p.Position.Y - p.Size.Y / 2 - 0.1)
		end
	end

	local centro = ORIGEM + V(0, 0.4, 0)
	local dist = o.dist or 75
	-- fundo e chão
	local parede = Instance.new("Part")
	parede.Anchored = true
	parede.CanCollide = false
	parede.Material = Enum.Material.SmoothPlastic
	parede.Color = Color3.fromRGB(150, 156, 164)
	parede.Size = V(300, 80, 1)
	parede.Position = centro + V(0, 10, 12)
	parede.Parent = folha
	local chao = Instance.new("Part")
	chao.Anchored = true
	chao.CanCollide = false
	chao.Material = Enum.Material.SmoothPlastic
	chao.Color = Color3.fromRGB(96, 100, 106)
	chao.Size = V(300, 0.5, 80)
	chao.Position = V(centro.X, (fundoY or 0) - 0.25, centro.Z)
	chao.Parent = folha
	local frontal = V(0, 0, -1)
	luz(centro, dist, frontal)

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local largura = (n - 1) * esp + 3.6
	local aspecto = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
	local altura = math.max(largura / aspecto, 7.5) / (o.aproximar or 1)
	cam.FieldOfView = math.deg(2 * math.atan(altura / 2 / dist))
	cam.CFrame = CFrame.lookAt(centro + V(0, 0.2, 0) + frontal * dist, centro + V(0, 0.2, 0))
	return string.format("quadros=%d aspecto=%.2f fov=%.1f", n, aspecto, cam.FieldOfView)
end

function Bancada.limpar()
	local f = workspace:FindFirstChild("Bancada")
	if f then
		f:Destroy()
	end
	Bancada.posProcessamento(true)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
end

return Bancada
